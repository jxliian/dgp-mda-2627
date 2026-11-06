from typing import Callable

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..DB.database import get_db
from ..auth.auth_backend import require_admin
from . import studs_links_db as links_db

router = APIRouter(
    prefix="/student-links",
    tags=["student links"],
    dependencies=[Depends(require_admin)],
)


def _run_db_operation(operation: Callable, *args):
    """Ejecuta una operación de asociaciones y traduce sus errores a respuestas HTTP."""
    try:
        return operation(*args)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/students/{student_username}/parents/{parent_username}")
def link_parent(student_username: str, parent_username: str, db: Session = Depends(get_db)) -> dict:
    """Asocia un tutor a un alumno."""
    return _run_db_operation(links_db.link_user, db, "parent", student_username, parent_username)


@router.delete("/students/{student_username}/parents/{parent_username}")
def unlink_parent(student_username: str, parent_username: str, db: Session = Depends(get_db)) -> dict:
    """Elimina la asociación entre un tutor y un alumno."""
    return _run_db_operation(links_db.unlink_user, db, "parent", student_username, parent_username)


@router.post("/students/{student_username}/staff/{staff_username}")
def link_staff(student_username: str, staff_username: str, db: Session = Depends(get_db)) -> dict:
    """Asocia a un miembro del staff con un alumno."""
    return _run_db_operation(links_db.link_user, db, "staff", student_username, staff_username)


@router.delete("/students/{student_username}/staff/{staff_username}")
def unlink_staff(student_username: str, staff_username: str, db: Session = Depends(get_db)) -> dict:
    """Elimina la asociación entre un miembro del staff y un alumno."""
    return _run_db_operation(links_db.unlink_user, db, "staff", student_username, staff_username)


@router.get("/students/{student_username}")
def get_student_links(student_username: str, db: Session = Depends(get_db)) -> dict:
    """Devuelve los tutores y el staff asociados al alumno."""
    parents = _run_db_operation(links_db.get_associated_users, db, "parent", student_username)
    staff = _run_db_operation(links_db.get_associated_users, db, "staff", student_username)
    return {"student_username": student_username, "parents": parents, "staff": staff}


@router.get("/parents/{parent_username}/students")
def get_parent_students(parent_username: str, db: Session = Depends(get_db)) -> dict:
    """Devuelve los alumnos asociados al tutor indicado."""
    students = _run_db_operation(links_db.get_students, db, "parent", parent_username)
    return {"parent_username": parent_username, "students": students}


@router.get("/staff/{staff_username}/students")
def get_staff_students(staff_username: str, db: Session = Depends(get_db)) -> dict:
    """Devuelve los alumnos asociados al miembro del staff indicado."""
    students = _run_db_operation(links_db.get_students, db, "staff", staff_username)
    return {"staff_username": staff_username, "students": students}
