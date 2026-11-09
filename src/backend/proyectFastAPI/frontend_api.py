"""Additional endpoints required by the Flutter screen flow.

Existing operations and their role boundaries remain in their original routers.
"""
import os
from datetime import date
from importlib import import_module
from typing import Annotated
from urllib.parse import quote

from fastapi import APIRouter, Depends, Path, Response
from pydantic import BaseModel, ConfigDict, StrictBool, StrictInt
from sqlalchemy import text
from sqlalchemy.orm import Session

from .DB.database import get_db
from .activity_content import has_content, save_content, task_content
from .auth.auth_backend import get_current_user, require_admin
from .clases.clases_db import _ensure_class, add_student, remove_student
from .errors import CatalogError, ErrorCode, raise_api_error, success_response
from .gestion_usuarios.users_mng_backend import DEFAULT_AVATAR_SVG, _image_media_type
from .gestion_usuarios.users_mng_db import users_mng_db
from .task_indexing import calculate_task_index, lock_student_agendas
from .task_schedule import validate_task_schedule

tasks_db = import_module('.tareas alumnos.studs_tasks_db', package=__package__)
CreateTaskRequest = import_module('.tareas alumnos.studs_tasks_backend', package=__package__).CreateTaskRequest
router = APIRouter(tags=['frontend flow'])
Username = Annotated[str, Path(min_length=1, max_length=50, pattern=r'^\S+$')]
TaskId = Annotated[int, Path(gt=0)]


def check_access(db: Session, user: dict, student: str) -> None:
    if user['role'] == 'student':
        if user['username'] != student:
            raise_api_error(ErrorCode.TASK_STUDENT_NOT_ASSOCIATED)
    elif user['role'] not in {'staff', 'parent'} or not tasks_db._has_student_relationship(
            db, user['role'], user['username'], student):
        raise_api_error(ErrorCode.TASK_STUDENT_NOT_ASSOCIATED)


def _assignment(db: Session, student: str, task_id: int, task_date: date) -> dict:
    row = db.execute(text(
        'SELECT t.*,a.task_index,a.task_date,a.class_name_fk FROM stud_task a '
        'JOIN Tasks t ON t.task_id=a.task_id_fk WHERE a.stud_usr_fk=:student '
        'AND a.task_id_fk=:id AND a.task_date=:date ORDER BY a.task_index LIMIT 1'),
        {'student': student, 'id': task_id, 'date': task_date}).mappings().first()
    if row is None:
        raise_api_error(ErrorCode.TASK_NOT_FOUND)
    return dict(row)


@router.get('/users/me')
def my_profile(db: Session = Depends(get_db), user: dict = Depends(get_current_user)) -> dict:
    result = users_mng_db.getUserByUsername(db, user['username'], user['role'])
    if result['errorCode']:
        raise_api_error(result['errorCode'])
    profile = {key: value for key, value in result.items() if key not in {'errorCode', 'details'}}
    profile['role'] = user['role']
    return success_response(user=profile)


def _directory_enabled() -> None:
    # Enable on supervised centre devices; can be disabled without removing login.
    if os.environ.get('ENABLE_STUDENT_DIRECTORY', 'true').lower() not in {'true', '1', 'yes'}:
        raise_api_error(ErrorCode.ROUTE_NOT_FOUND)


@router.get('/auth/student-directory')
def student_directory(db: Session = Depends(get_db)) -> dict:
    _directory_enabled()
    rows = db.execute(text('SELECT c.class_name,u.username,u.full_name FROM Class c '
        'LEFT JOIN class_stud e ON e.class_name_fk=c.class_name '
        'LEFT JOIN users u ON u.username=e.stud_usr_fk ORDER BY c.class_name,u.username')).mappings().all()
    classes = {}
    for row in rows:
        classroom = classes.setdefault(row['class_name'], {'class_name': row['class_name'], 'students': []})
        if row['username']:
            classroom['students'].append({'username': row['username'],
                'full_name': row['full_name'].split(' ')[0],
                'avatar_url': f"/auth/student-directory/{quote(row['username'], safe='')}/avatar"})
    return success_response(classes=list(classes.values()))


@router.get('/auth/student-directory/{student_username}/avatar')
def directory_avatar(student_username: Username, db: Session = Depends(get_db)) -> Response:
    _directory_enabled()
    if db.execute(text('SELECT 1 FROM class_stud WHERE stud_usr_fk=:student'),
                  {'student': student_username}).scalar_one_or_none() is None:
        raise_api_error(ErrorCode.USER_NOT_FOUND)
    result = users_mng_db.getAvatar(db, student_username)
    if result['errorCode']:
        raise_api_error(result['errorCode'])
    image = result.get('avatar_bin')
    media_type = _image_media_type(image) if image else None
    return Response(content=image if media_type else DEFAULT_AVATAR_SVG,
                    media_type=media_type or 'image/svg+xml', headers={'Cache-Control': 'no-store'})


def read_agenda(db: Session, user: dict, student: str, selected_date: date) -> dict:
    check_access(db, user, student)
    rows = db.execute(text('SELECT t.*,a.task_date,a.task_index,a.class_name_fk '
        'FROM stud_task a JOIN Tasks t ON t.task_id=a.task_id_fk '
        'WHERE a.stud_usr_fk=:student AND a.task_date=:date '
        'ORDER BY a.task_index,t.task_id'), {'student': student, 'date': selected_date}).mappings().all()
    tasks = [{**dict(row), **task_content(db, row['task_id'], student, selected_date)} for row in rows]
    return success_response(student_username=student, tasks=tasks)


@router.get('/student-tasks/me')
def my_agenda(task_date: date, db: Session = Depends(get_db), user: dict = Depends(get_current_user)) -> dict:
    if user['role'] != 'student':
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)
    return read_agenda(db, user, user['username'], task_date)


@router.get('/student-links/parents/me/students/{student_username}/avatar')
def linked_student_avatar(student_username: Username, db: Session = Depends(get_db),
                          user: dict = Depends(get_current_user)) -> Response:
    if user['role'] != 'parent':
        raise_api_error(ErrorCode.TASK_STUDENT_NOT_ASSOCIATED)
    check_access(db, user, student_username)
    result = users_mng_db.getAvatar(db, student_username)
    if result['errorCode']:
        raise_api_error(result['errorCode'])
    image = result.get('avatar_bin')
    media_type = _image_media_type(image) if image else None
    return Response(content=image if media_type else DEFAULT_AVATAR_SVG,
                    media_type=media_type or 'image/svg+xml', headers={'Cache-Control':'no-store'})


@router.get('/student-tasks/students/{student_username}')
def student_agenda(student_username: Username, task_date: date,
                   db: Session = Depends(get_db), user: dict = Depends(get_current_user)) -> dict:
    return read_agenda(db, user, student_username, task_date)


def update_individual(db: Session, user: dict, student: str, task_id: int,
                      original_date: date, payload: CreateTaskRequest) -> dict:
    check_access(db, user, student)
    lock_student_agendas(db, [student])
    old = _assignment(db, student, task_id, original_date)
    if old['class_name_fk'] is not None:
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    if user['role'] == 'student':
        allowed = db.execute(text('SELECT stud_access_task_mod FROM Student WHERE stud_usr=:student'),
                             {'student': student}).scalar_one()
        if not allowed:
            raise_api_error(ErrorCode.STUDENT_TASK_MODIFICATION_DENIED)
        if old['task_creator'] != student:
            raise_api_error(ErrorCode.TASK_NOT_FOUND)
    try:
        validate_task_schedule(user['role'], old['task_start_hour'], old['task_duration'])
        validate_task_schedule(user['role'], payload.task_start_hour, payload.task_duration)
        # A group task must be changed through its class route. Direct tasks have
        # a single owner in the current API, so their identity can remain stable.
        others = db.execute(text('SELECT COUNT(*) FROM stud_task WHERE task_id_fk=:id '
            'AND (stud_usr_fk<>:student OR task_date<>:date)'),
            {'id': task_id, 'student': student, 'date': original_date}).scalar_one()
        if others or db.execute(text('SELECT 1 FROM class_task WHERE task_id_fk=:id'), {'id': task_id}).scalar_one_or_none():
            raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
        if payload.alt_task_id_fk is not None:
            if not db.execute(text('SELECT 1 FROM Alt_Tasks WHERE alt_task_id=:id'), {'id': payload.alt_task_id_fk}).scalar_one_or_none():
                raise_api_error(ErrorCode.ALTERNATIVE_TASK_NOT_FOUND)
            if db.execute(text('SELECT 1 FROM Tasks WHERE alt_task_id_fk=:alt AND task_id<>:id'),
                          {'id': task_id, 'alt': payload.alt_task_id_fk}).scalar_one_or_none():
                raise_api_error(ErrorCode.ALTERNATIVE_TASK_ALREADY_ASSIGNED)
        db.execute(text('DELETE FROM stud_task WHERE stud_usr_fk=:student AND task_id_fk=:id AND task_date=:date'),
                   {'student': student, 'id': task_id, 'date': original_date})
        index = calculate_task_index(db, student, payload.task_date, payload.task_start_hour)
        db.execute(text('UPDATE Tasks SET task_title=:title,task_start_hour=:hour,task_duration=:duration,alt_task_id_fk=:alt WHERE task_id=:id'),
                   {'id': task_id, 'title': payload.task_title, 'hour': payload.task_start_hour,
                    'duration': payload.task_duration, 'alt': payload.alt_task_id_fk})
        db.execute(text('INSERT INTO stud_task(stud_usr_fk,task_id_fk,task_index,task_date) VALUES (:student,:id,:index,:date)'),
                   {'student': student, 'id': task_id, 'index': index, 'date': payload.task_date})
        if has_content(payload):
            save_content(db, task_id, payload)
        db.commit()
        return success_response(**{**_assignment(db, student, task_id, payload.task_date),
                                   **task_content(db, task_id, student, payload.task_date)})
    except CatalogError as exc:
        db.rollback()
        raise_api_error(exc.code)
    except Exception:
        db.rollback()
        raise


@router.put('/student-tasks/me/{task_id}')
def edit_my_task(task_id: TaskId, task_date: date, payload: CreateTaskRequest,
                 db: Session = Depends(get_db), user: dict = Depends(get_current_user)) -> dict:
    if user['role'] != 'student':
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)
    return update_individual(db, user, user['username'], task_id, task_date, payload)


@router.put('/student-tasks/students/{student_username}/{task_id}')
def edit_student_task(student_username: Username, task_id: TaskId, task_date: date, payload: CreateTaskRequest,
                      db: Session = Depends(get_db), user: dict = Depends(get_current_user)) -> dict:
    if user['role'] not in {'staff', 'parent'}:
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)
    return update_individual(db, user, student_username, task_id, task_date, payload)


class ProgressRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    step_id: StrictInt | None = None
    step_finished: StrictBool | None = None
    complete: StrictBool = False


@router.patch('/student-tasks/me/{task_id}/progress')
def save_progress(task_id: TaskId, task_date: date, payload: ProgressRequest,
                   db: Session = Depends(get_db), user: dict = Depends(get_current_user)) -> dict:
    if user['role'] != 'student':
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)
    student = user['username']
    lock_student_agendas(db, [student])
    db.execute(text('SELECT task_id FROM Tasks WHERE task_id=:id FOR UPDATE'), {'id': task_id})
    task = _assignment(db, student, task_id, task_date)
    params = {'student': student, 'id': task_id, 'date': task_date}
    try:
        db.execute(text('INSERT INTO Task_Progress(stud_usr_fk,task_id_fk,task_date) VALUES (:student,:id,:date) '
                        'ON CONFLICT DO NOTHING'), params)
        if payload.step_id is not None:
            if payload.step_finished is None or not db.execute(text('SELECT 1 FROM Steps WHERE step_id=:step AND generic_task_id_fk=:id'),
                {'step': payload.step_id, 'id': task_id}).scalar_one_or_none():
                raise_api_error(ErrorCode.INVALID_REQUEST)
            db.execute(text('INSERT INTO Step_Progress(stud_usr_fk,task_id_fk,task_date,step_id_fk,step_finished) '
                'VALUES (:student,:id,:date,:step,:finished) ON CONFLICT(stud_usr_fk,task_id_fk,task_date,step_id_fk) '
                'DO UPDATE SET step_finished=EXCLUDED.step_finished'),
                {**params, 'step': payload.step_id, 'finished': payload.step_finished})
            db.execute(text('UPDATE Task_Progress SET task_finished=FALSE WHERE stud_usr_fk=:student AND task_id_fk=:id AND task_date=:date'), params)
        elif not payload.complete:
            raise_api_error(ErrorCode.INVALID_REQUEST)
        content = task_content(db, task_id, student, task_date)
        if payload.complete:
            if any(s['step_required'] and not s['step_finished'] for s in content['steps']):
                raise_api_error(ErrorCode.TASK_STEPS_PENDING)
            db.execute(text('UPDATE Task_Progress SET task_finished=TRUE WHERE stud_usr_fk=:student AND task_id_fk=:id AND task_date=:date'), params)
            content['task_finished'] = True
        db.commit()
        return success_response(**{**task, **content})
    except Exception:
        db.rollback()
        raise


@router.delete('/classes/{class_name}/staff/{staff_username}', dependencies=[Depends(require_admin)])
def remove_class_staff(class_name: str, staff_username: Username, db: Session = Depends(get_db)) -> dict:
    try:
        _ensure_class(db, class_name)
    except CatalogError as exc:
        raise_api_error(exc.code)
    result = db.execute(text('DELETE FROM class_staff WHERE class_name_fk=:class AND staff_usr_fk=:staff'),
                        {'class': class_name, 'staff': staff_username})
    if not result.rowcount:
        db.rollback()
        raise_api_error(ErrorCode.ASSOCIATION_NOT_FOUND)
    db.commit()
    return success_response(class_name=class_name, staff_username=staff_username)


@router.post('/admin/classes/{class_name}/students/{student_username}', dependencies=[Depends(require_admin)], status_code=201)
def admin_enroll_student(class_name: str, student_username: Username, db: Session = Depends(get_db)) -> dict:
    try:
        return add_student(db, class_name, None, student_username)
    except CatalogError as exc:
        raise_api_error(exc.code)


@router.delete('/admin/classes/{class_name}/students/{student_username}', dependencies=[Depends(require_admin)])
def admin_remove_student(class_name: str, student_username: Username, db: Session = Depends(get_db)) -> dict:
    try:
        return remove_student(db, class_name, None, student_username)
    except CatalogError as exc:
        raise_api_error(exc.code)
