"""Real PostgreSQL checks for the Flutter screen flow and per-assignment progress."""
import base64
from datetime import date

import pytest
from sqlalchemy import text

from conftest import LUNES, as_user

PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a54sAAAAASUVORK5CYII=')


def task_body(**changes):
    return {'task_title': 'Preparar material', 'task_date': LUNES,
        'task_start_hour': '10:00:00', 'task_duration': 20,
        'steps': [
            {'step_title': 'Buscar', 'step_description': 'Busca el cuaderno.', 'step_duration': 5},
            {'step_title': 'Guardar', 'step_description': 'Guarda el cuaderno.', 'step_duration': 5},
        ], **changes}


def create(client, **changes):
    response = client.post('/student-tasks/students/pablo', json=task_body(**changes), headers=as_user('lucia'))
    assert response.status_code == 201, response.text
    return response.json()


def agenda(client, username='pablo', selected=LUNES):
    return client.get('/student-tasks/me', params={'task_date': selected}, headers=as_user(username))


def progress(client, task, payload, username='pablo', selected=LUNES):
    return client.patch(f"/student-tasks/me/{task['task_id']}/progress", params={'task_date': selected},
                        json=payload, headers=as_user(username))


@pytest.mark.parametrize('username,role', [('admin','admin'),('lucia','staff'),('madre','parent'),('pablo','student')])
def test_own_profile_contains_role_and_no_secrets(client, username, role):
    response = client.get('/users/me', headers=as_user(username))
    assert response.status_code == 200
    user = response.json()['user']
    assert user['username'] == username and user['role'] == role
    assert 'password' not in user and 'token' not in user
    if role == 'student':
        assert user['stud_access_task_mod'] is True


def test_directory_is_minimal_and_can_be_disabled(client, monkeypatch):
    response = client.get('/auth/student-directory')
    assert response.status_code == 200
    student = response.json()['classes'][0]['students'][0]
    assert set(student) == {'username','full_name','avatar_url'}
    assert client.get(student['avatar_url']).headers['content-type'].startswith('image/svg')
    monkeypatch.setenv('ENABLE_STUDENT_DIRECTORY','false')
    assert client.get('/auth/student-directory').status_code == 404
    assert client.get(student['avatar_url']).status_code == 404


def test_real_png_upload_and_directory_image(client):
    response = client.put('/users/students/me/avatar', files={'file': ('photo.png',PNG,'image/png')}, headers=as_user('pablo'))
    assert response.status_code == 200
    image = client.get('/auth/student-directory/pablo/avatar')
    assert image.content == PNG
    assert image.headers['content-type'] == 'image/png'
    assert image.headers['cache-control'] == 'no-store'


def test_rich_task_roundtrip_and_schedule(client):
    created = create(client, task_image=base64.b64encode(PNG).decode())
    task = agenda(client).json()['tasks'][0]
    assert task['task_id'] == created['task_id']
    assert task['task_image'] == base64.b64encode(PNG).decode()
    assert [s['step_title'] for s in task['steps']] == ['Buscar','Guardar']
    assert [s['step_index'] for s in task['steps']] == [0,1]
    assert all(not s['step_finished'] for s in task['steps'])


@pytest.mark.parametrize('username', ['pedro','otra_madre','admin','ana'])
def test_individual_agenda_rejects_unrelated_accounts(client, username):
    create(client)
    response = client.get('/student-tasks/students/pablo', params={'task_date':LUNES}, headers=as_user(username))
    assert response.status_code == 403


def test_agenda_own_only_and_requires_a_date(client):
    assert client.get('/student-tasks/me', headers=as_user('pablo')).status_code == 422
    assert client.get('/student-tasks/me', params={'task_date':LUNES}).status_code == 401


def test_required_steps_block_completion_and_progress_persists(client):
    task = create(client)
    assert progress(client, task, {'complete': True}).json()['errorCode'] == 1041
    for step in task['steps']:
        response = progress(client, task, {'step_id':step['step_id'],'step_finished':True})
        assert response.status_code == 200
    assert progress(client, task, {'complete':True}).json()['task_finished'] is True
    assert agenda(client).json()['tasks'][0]['task_finished'] is True
    response = progress(client, task, {'step_id':task['steps'][0]['step_id'],'step_finished':False})
    assert response.json()['task_finished'] is False


def test_cannot_complete_another_tasks_step(client):
    first = create(client)
    other = create(client)
    response = progress(client, first, {'step_id':other['steps'][0]['step_id'],'step_finished':True})
    assert response.status_code == 422


def test_class_task_progress_is_independent_per_student(client, count):
    client.post('/classes/1A/students/ana', headers=as_user('lucia'))
    task = client.post('/classes/1A/tasks', headers=as_user('lucia'), json=task_body()).json()
    for step in task['steps']:
        assert progress(client, task, {'step_id':step['step_id'],'step_finished':True}).status_code == 200
    assert progress(client, task, {'complete':True}).status_code == 200
    other = agenda(client, 'ana').json()['tasks'][0]
    assert other['task_finished'] is False
    assert all(not step['step_finished'] for step in other['steps'])
    assert count('Steps WHERE step_finished=TRUE') == 0
    assert count('Tasks WHERE task_finished=TRUE') == 0


def test_progress_is_independent_per_date(client, engine):
    task = create(client)
    with engine.begin() as conn:
        conn.execute(text('INSERT INTO stud_task(stud_usr_fk,task_id_fk,task_index,task_date) VALUES '
                          "('pablo',:id,0,'2026-11-17')"), {'id':task['task_id']})
    progress(client, task, {'step_id':task['steps'][0]['step_id'],'step_finished':True})
    assert not agenda(client, selected='2026-11-17').json()['tasks'][0]['steps'][0]['step_finished']


def test_unassigning_cleans_progress_only_for_that_student(client, count):
    task = create(client)
    progress(client, task, {'step_id':task['steps'][0]['step_id'],'step_finished':True})
    assert count('Task_Progress') == 1
    response = client.delete(f"/student-tasks/students/pablo/{task['task_id']}",
                             params={'task_date':LUNES}, headers=as_user('lucia'))
    assert response.status_code == 200
    assert count('Task_Progress') == 0 and count('Step_Progress') == 0


def test_editing_individual_task_moves_date_and_replaces_steps(client):
    task = create(client)
    response = client.put(f"/student-tasks/students/pablo/{task['task_id']}", params={'task_date':LUNES},
                          json=task_body(task_date='2026-11-17', task_title='Título nuevo'), headers=as_user('lucia'))
    assert response.status_code == 200, response.text
    assert agenda(client).json()['tasks'] == []
    assert agenda(client, selected='2026-11-17').json()['tasks'][0]['task_title'] == 'Título nuevo'


def test_family_cannot_move_a_school_task_out_of_school(client):
    task = create(client)
    response = client.put(f"/student-tasks/students/pablo/{task['task_id']}", params={'task_date':LUNES},
                          json=task_body(task_start_hour='17:00'), headers=as_user('madre'))
    assert response.status_code == 400
    assert agenda(client).json()['tasks'][0]['task_start_hour'] == '10:00:00'


def test_invalid_image_does_not_save_task_header(client, count):
    response = client.post('/student-tasks/students/pablo', headers=as_user('lucia'), json=task_body(task_image='not-an-image'))
    assert response.status_code == 422
    assert count('Tasks') == 0


def test_step_failure_rolls_back_header_and_assignment(client, count, monkeypatch):
    from importlib import import_module
    module = import_module('proyectFastAPI.tareas alumnos.studs_tasks_backend')
    def fail(*args):
        raise RuntimeError('simulated storage failure')
    monkeypatch.setattr(module, 'save_content', fail)
    with pytest.raises(RuntimeError):
        client.post('/student-tasks/students/pablo', headers=as_user('lucia'), json=task_body())
    assert count('Tasks') == 0 and count('stud_task') == 0


def test_only_students_can_record_progress(client):
    task = create(client)
    assert progress(client, task, {'complete':True}, username='lucia').status_code == 403


def test_configured_web_origin_passes_preflight(client):
    response = client.options('/auth/login', headers={'Origin':'http://localhost:5173',
        'Access-Control-Request-Method':'POST','Access-Control-Request-Headers':'content-type,authorization'})
    assert response.status_code == 200
    assert response.headers['access-control-allow-origin'] == 'http://localhost:5173'


def test_admin_screen_can_manage_enrollment_without_impersonating_staff(client, count):
    response = client.post('/admin/classes/1A/students/ana', headers=as_user('admin'))
    assert response.status_code == 201
    assert count("class_stud WHERE stud_usr_fk='ana'") == 1
    assert client.delete('/admin/classes/1A/students/ana', headers=as_user('admin')).status_code == 200
    assert client.post('/admin/classes/1A/students/ana', headers=as_user('lucia')).status_code == 403


def test_student_cannot_grant_themselves_new_permissions(client):
    response = client.put('/users/student/pablo', headers=as_user('pablo'), json={'stud_access_task_mod':True})
    assert response.status_code == 403
    assert client.put('/users/student/pablo', headers=as_user('pablo'), json={'stud_access_fontsize':24}).status_code == 200


def test_admin_creates_student_with_all_accessibility_fields(client):
    access = client.get('/users/me',headers=as_user('pablo')).json()['user']
    fields = {key:value for key,value in access.items() if key.startswith('stud_access_')}
    response = client.post('/users',headers=as_user('admin'),json={
        'username':'nuevo','full_name':'Alumno Nuevo','role':'student','password':'1234',**fields})
    assert response.status_code == 200
    assert any(u['username']=='nuevo' for u in client.get('/users',headers=as_user('admin')).json()['users'])


def test_parent_can_only_view_photos_of_linked_students(client):
    assert client.get('/student-links/parents/me/students/pablo/avatar', headers=as_user('madre')).status_code == 200
    assert client.get('/student-links/parents/me/students/ana/avatar', headers=as_user('madre')).status_code == 403
