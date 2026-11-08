from datetime import date, time
from importlib import import_module
from typing import Annotated

from fastapi import APIRouter, Depends, Path, Query
from pydantic import BaseModel, ConfigDict, Field, StrictInt, field_validator
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
    model_config = ConfigDict(extra="forbid")

    task_title: str = Field(strict=True, min_length=1, max_length=100)
    task_date: date
    task_index: StrictInt = Field(ge=0)
    task_start_hour: time | None = None
    task_duration: StrictInt = Field(gt=0)
    alt_task_id_fk: StrictInt | None = Field(default=None, gt=0)

    @field_validator("task_title")
    @classmethod
    def validate_task_title(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("El título no puede estar vacío")
        return value

    @field_validator("task_start_hour")
    @classmethod
    def validate_task_start_hour(cls, value: time | None) -> time | None:
        if value is not None and value.utcoffset() is not None:
            raise ValueError("La hora debe expresarse sin zona horaria")
        return value


class CreateOwnTaskRequest(CreateTaskRequest):
    """Datos de una tarea propia, con hora necesaria para validar su horario."""

    task_start_hour: time


class SetAlternativeTaskRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    alt_task_id_fk: StrictInt | None = Field(gt=0)


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
        payload.task_date,
        payload.task_index,
        payload.task_start_hour,
        payload.task_duration,
        payload.alt_task_id_fk,
    )


@router.post("/me", status_code=201)
def create_my_task(
    payload: CreateOwnTaskRequest,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Crea una tarea para el alumno autenticado fuera del horario escolar."""
    if user["role"] != "student":
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)

    return _run_db_operation(
        tasks_db.create_task,
        db,
        "student",
        user["username"],
        user["username"],
        payload.task_title,
        payload.task_date,
        payload.task_index,
        payload.task_start_hour,
        payload.task_duration,
        payload.alt_task_id_fk,
    )


@router.put("/{task_id}/alternative")
def set_task_alternative(
    task_id: Annotated[int, Path(gt=0)],
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
    task_id: Annotated[int, Path(gt=0)],
    task_date: date,
    task_index: Annotated[int, Query(ge=0)],
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
        task_date,
        task_index,
    )


@router.delete("/me/{task_id}")
def delete_my_task(
    task_id: Annotated[int, Path(gt=0)],
    task_date: date,
    task_index: Annotated[int, Query(ge=0)],
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Elimina una tarea propia del alumno si está fuera del horario escolar."""
    if user["role"] != "student":
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)

    return _run_db_operation(
        tasks_db.delete_student_task,
        db,
        "student",
        user["username"],
        user["username"],
        task_id,
        task_date,
        task_index,
    )
