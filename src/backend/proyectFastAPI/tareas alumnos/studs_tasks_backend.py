from datetime import time
from importlib import import_module

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..DB.database import get_db
from ..auth.auth_backend import get_current_user
from ..errors import CatalogError, ErrorCode, raise_api_error

tasks_db = import_module(".studs_tasks_db", package=__package__)

router = APIRouter(prefix="/student-tasks", tags=["student tasks"])


def _run_db_operation(operation, *args):
    """Convierte errores catalogados de la capa de datos en respuestas API."""
    try:
        return operation(*args)
    except CatalogError as exc:
        raise_api_error(exc.code)


class CreateTaskRequest(BaseModel):
    task_title: str = Field(min_length=1, max_length=100)
    task_start_hour: time | None = None
    task_duration: int | None = None
    alt_task_id_fk: int | None = None


class SetAlternativeTaskRequest(BaseModel):
    alt_task_id_fk: int | None


@router.post("/students/{student_username}", status_code=201)
def create_student_task(
    student_username: str,
    payload: CreateTaskRequest,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Crea y asigna una tarea a un alumno asociado al usuario autenticado."""
    if user["role"] not in {"staff", "parent"}:
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)

    return _run_db_operation(
        tasks_db.create_task,
        db,
        user["role"],
        user["username"],
        student_username,
        payload.task_title,
        payload.task_start_hour,
        payload.task_duration,
        payload.alt_task_id_fk,
    )


@router.put("/{task_id}/alternative")
def set_task_alternative(
    task_id: int,
    payload: SetAlternativeTaskRequest,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Asocia o desasocia una tarea alternativa de una tarea del usuario autenticado."""
    if user["role"] not in {"staff", "parent"}:
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)

    return _run_db_operation(
        tasks_db.set_alternative_task,
        db,
        user["role"],
        user["username"],
        task_id,
        payload.alt_task_id_fk,
    )


@router.delete("/students/{student_username}/{task_id}")
def delete_student_task(
    student_username: str,
    task_id: int,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Quita una tarea de la agenda del alumno asociado al usuario."""
    if user["role"] not in {"staff", "parent"}:
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)

    return _run_db_operation(
        tasks_db.delete_student_task,
        db,
        user["role"],
        user["username"],
        student_username,
        task_id,
    )
