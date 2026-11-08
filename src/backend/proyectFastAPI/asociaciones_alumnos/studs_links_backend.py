from typing import Callable

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..DB.database import get_db
from ..auth.auth_backend import get_current_user, require_admin
from ..errors import CatalogError, ErrorCode, raise_api_error, success_response
from . import studs_links_db as links_db

router = APIRouter(
    prefix="/student-links",
    tags=["student links"],
)


def _require_self_or_admin(user: dict, role: str, username: str) -> None:
    """Permite al usuario consultar sus asociaciones, o al admin consultar cualquiera."""
    if user["role"] != "admin" and (user["role"] != role or user["username"] != username):
        raise_api_error(ErrorCode.ASSOCIATION_ACCESS_DENIED)


def _run_db_operation(operation: Callable, *args):
    """Ejecuta una operación de asociaciones y traduce sus errores a respuestas HTTP."""
    try:
        return operation(*args)
    except CatalogError as exc:
        raise_api_error(exc.code)


@router.post("/students/{student_username}/parents/{parent_username}", dependencies=[Depends(require_admin)])
def link_parent(student_username: str, parent_username: str, db: Session = Depends(get_db)) -> dict:
    """Asocia un tutor a un alumno."""
    return _run_db_operation(links_db.link_user, db, "parent", student_username, parent_username)


@router.delete("/students/{student_username}/parents/{parent_username}", dependencies=[Depends(require_admin)])
def unlink_parent(student_username: str, parent_username: str, db: Session = Depends(get_db)) -> dict:
    """Elimina la asociación entre un tutor y un alumno."""
    return _run_db_operation(links_db.unlink_user, db, "parent", student_username, parent_username)


@router.get("/students/{student_username}", dependencies=[Depends(require_admin)])
def get_student_links(student_username: str, db: Session = Depends(get_db)) -> dict:
    """Devuelve los tutores del alumno y el personal que imparte su clase."""
    parents = _run_db_operation(links_db.get_associated_users, db, "parent", student_username)
    staff = _run_db_operation(links_db.get_associated_users, db, "staff", student_username)
    return success_response(student_username=student_username, parents=parents, staff=staff)


@router.get("/parents/{parent_username}/students")
def get_parent_students(
    parent_username: str,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Devuelve los alumnos asociados al tutor indicado."""
    _require_self_or_admin(user, "parent", parent_username)
    students = _run_db_operation(links_db.get_students, db, "parent", parent_username)
    return success_response(parent_username=parent_username, students=students)


@router.get("/staff/{staff_username}/students")
def get_staff_students(
    staff_username: str,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Devuelve los alumnos asociados al miembro del staff indicado."""
    _require_self_or_admin(user, "staff", staff_username)
    students = _run_db_operation(links_db.get_students, db, "staff", staff_username)
    return success_response(staff_username=staff_username, students=students)
