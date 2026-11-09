"""Contracts for classroom photos and the refined student/account screens."""
import base64

import pytest
from sqlalchemy import text

from conftest import LUNES, PASSWORD, add_admin, as_user
from test_frontend_flow import PNG, create, progress, task_body


@pytest.mark.parametrize('role', ['admin', 'staff', 'parent'])
def test_accounts_can_be_created_and_edited_without_collecting_email(client, role):
    username = f'cuenta_{role}'
    response = client.post('/users', headers=as_user('admin'), json={
        'username': username, 'full_name': 'Nombre Apellido Primero', 'password': '1234', 'role': role})
    assert response.status_code == 200
    rows = client.get('/users', headers=as_user('admin')).json()['users']
    assert next(u for u in rows if u['username'] == username)['email'] is None
    assert client.put(f'/users/{role}/{username}', headers=as_user('admin'),
                      json={'full_name': 'Nombre Apellido Segundo'}).status_code == 200
    assert client.post('/auth/login', json={'username': username, 'role': role, 'password':'1234'}).status_code == 200


def test_student_cannot_change_password_and_admin_can_reset_it(client):
    assert client.put('/users/student/pablo', headers=as_user('pablo'), json={'password':'Nueva1234'}).status_code == 403
    assert client.post('/auth/login', json={'username':'pablo','role':'student','password':PASSWORD}).status_code == 200
    assert client.put('/users/student/pablo', headers=as_user('admin'), json={'password':'Nueva1234'}).status_code == 200
    assert client.post('/auth/login', json={'username':'pablo','role':'student','password':'Nueva1234'}).status_code == 200


def test_admin_cannot_delete_self_even_with_another_admin(client, engine, count):
    with engine.begin() as conn:
        add_admin(conn, 'admin_dos')
    response = client.delete('/users/admin/admin', headers=as_user('admin'))
    assert response.status_code == 403 and response.json()['errorCode'] == 1042
    assert count('Admn') == 2
    assert client.delete('/users/admin/admin_dos', headers=as_user('admin')).status_code == 200


def test_classroom_photo_survives_rename_and_is_visible_before_login(client):
    encoded = base64.b64encode(PNG).decode()
    assert client.put('/classes/1A', headers=as_user('admin'),
                      json={'class_name':'Aula Azul','class_image':encoded}).status_code == 200
    assert client.get('/classes/Aula%20Azul', headers=as_user('admin')).json()['class_image'] == encoded
    directory = client.get('/auth/student-directory').json()['classes']
    assert next(c for c in directory if c['class_name']=='Aula Azul')['class_image'] == encoded
    assert client.put('/classes/Aula%20Azul', headers=as_user('admin'),
                      json={'class_name':'Aula Verde'}).status_code == 200
    assert client.get('/classes/Aula%20Verde', headers=as_user('admin')).json()['class_image'] == encoded


def test_classroom_photo_can_be_cleared_and_invalid_photo_does_not_create_class(client, count):
    assert client.post('/classes', headers=as_user('admin'),
                       json={'class_name':'Clase invalida','class_image':'invalid'}).status_code == 422
    assert count("Class WHERE class_name='Clase invalida'") == 0
    encoded = base64.b64encode(PNG).decode()
    assert client.post('/classes', headers=as_user('admin'), json={'class_name':'Fotos','class_image':encoded}).status_code == 201
    assert client.put('/classes/Fotos', headers=as_user('admin'), json={'class_name':'Fotos','class_image':None}).status_code == 200
    assert client.get('/classes/Fotos', headers=as_user('admin')).json()['class_image'] is None
    assert client.put('/classes/Fotos', headers=as_user('lucia'), json={'class_name':'Fotos','class_image':encoded}).status_code == 403


def test_admin_can_upload_student_photo_when_self_editing_is_disabled(client, engine):
    with engine.begin() as conn:
        conn.execute(text("UPDATE Student SET stud_access_profile_mod=FALSE WHERE stud_usr='pablo'"))
    files = {'file':('foto.png',PNG,'image/png')}
    assert client.put('/admin/students/pablo/avatar', headers=as_user('admin'), files=files).status_code == 200
    assert client.get('/users/students/pablo/avatar-image', headers=as_user('admin')).content == PNG
    assert client.put('/users/students/me/avatar', headers=as_user('pablo'), files=files).status_code == 403
    assert client.put('/admin/students/ana/avatar', headers=as_user('lucia'), files=files).status_code == 403


def test_each_step_keeps_its_own_photo_and_last_confirmation_finishes_the_task(client):
    encoded = base64.b64encode(PNG).decode()
    steps = task_body()['steps']
    steps[0]['step_image'] = encoded
    task = create(client, steps=steps)
    assert task['steps'][0]['step_image'] == encoded
    assert task['steps'][1]['step_image'] is None
    assert progress(client, task, {'step_id':task['steps'][0]['step_id'],'step_finished':True}).status_code == 200
    response = progress(client, task, {'step_id':task['steps'][1]['step_id'],'step_finished':True,'complete':True})
    assert response.status_code == 200 and response.json()['task_finished'] is True
