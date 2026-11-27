from datetime import date, time
from importlib import import_module
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Path, Query
from pydantic import BaseModel, ConfigDict, Field, StrictInt, field_validator
from sqlalchemy.orm import Session

from ..DB.database import get_db
from ..auth.auth_backend import get_current_user
from ..errors import CatalogError, ErrorCode, raise_api_error

tasks_db = import_module(".studs_tasks_db", package=__package__)

router = APIRouter(prefix="/student-tasks", tags=["student tasks"])
UsernamePath = Annotated[str, Path(min_length=1, max_length=50, pattern=r"^\S+$")]


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


class SetAlternativeTaskRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    alt_task_id_fk: StrictInt | None = Field(gt=0)


class CreateTaskStepRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    step_description: str = Field(strict=True, min_length=1)

    @field_validator("step_description")
    @classmethod
    def validate_step_description(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("La descripción del paso no puede estar vacía")
        return value


class ReorderTaskStepsRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    step_ids: list[StrictInt]

    @field_validator("step_ids")
    @classmethod
    def validate_step_ids(cls, value: list[int]) -> list[int]:
        if any(step_id <= 0 for step_id in value) or len(value) != len(set(value)):
            raise ValueError("Los identificadores deben ser positivos y no repetirse")
        return value


class UpdateTaskStepRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    step_description: str | None = Field(default=None, strict=True, min_length=1)
    step_index: StrictInt | None = Field(default=None, ge=0)

    @field_validator("step_description")
    @classmethod
    def validate_step_description(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("La descripción del paso no puede estar vacía")
        return value


@router.post("/{task_id}/steps", status_code=201)
def create_task_step(
    task_id: Annotated[int, Path(gt=0)],
    payload: CreateTaskStepRequest,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Añade un paso a una tarea individual propia o a una tarea propia del alumno."""
    if user["role"] not in {"staff", "parent", "student"}:
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)

    return _run_db_operation(
        tasks_db.create_task_step,
        db,
        user["role"],
        user["username"],
        task_id,
        payload.step_description,
    )


@router.put("/{task_id}/steps/order")
def reorder_individual_task_steps(
    task_id: Annotated[int, Path(gt=0)],
    payload: ReorderTaskStepsRequest,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Cambia el orden de pasos de una tarea individual creada por el personal."""
    if user["role"] != "staff":
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)
    return _run_db_operation(
        tasks_db.reorder_task_steps,
        db,
        "staff",
        user["username"],
        task_id,
        payload.step_ids,
    )


@router.put("/{task_id}/steps/{step_id}")
def update_individual_task_step(
    task_id: Annotated[int, Path(gt=0)],
    step_id: Annotated[int, Path(gt=0)],
    payload: UpdateTaskStepRequest,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Edita un paso de una tarea individual propia y autorizada."""
    if user["role"] not in {"staff", "parent", "student"}:
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)
    return _run_db_operation(
        tasks_db.update_task_step,
        db,
        user["role"],
        user["username"],
        task_id,
        step_id,
        payload.step_description,
        payload.step_index,
    )


@router.delete("/{task_id}/steps/{step_id}")
def delete_task_step(
    task_id: Annotated[int, Path(gt=0)],
    step_id: Annotated[int, Path(gt=0)],
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Elimina un paso de una tarea individual autorizada."""
    if user["role"] not in {"staff", "parent", "student"}:
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)

    return _run_db_operation(
        tasks_db.delete_task_step,
        db,
        user["role"],
        user["username"],
        task_id,
        step_id,
    )


@router.post("/students/{student_username}", status_code=201)
def create_student_task(
    student_username: UsernamePath,
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
        payload.task_start_hour,
        payload.task_duration,
        payload.alt_task_id_fk,
    )


@router.get("/students/{student_username}")
def get_student_tasks(
    student_username: UsernamePath,
    task_date: date,
    class_name: Annotated[str | None, Query(min_length=1, max_length=50)] = None,
    finished: bool | None = None,
    creator_role: Literal["staff", "parent", "student"] | None = None,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Consulta las tareas de un alumno asociado al personal o tutor autenticado.

    Filtros opcionales (SCRUM-692), combinables entre sí:
    - class_name: solo las tareas asignadas a toda esa clase.
    - finished: true para completadas, false para pendientes.
    - creator_role: solo las creadas por personal, familia o el propio alumno.
    """
    if user["role"] not in {"staff", "parent"}:
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)

    return _run_db_operation(
        tasks_db.list_student_tasks,
        db,
        user["role"],
        user["username"],
        student_username,
        task_date,
        class_name,
        finished,
        creator_role,
    )


@router.put("/students/{student_username}/{task_id}")
def update_student_task(
    student_username: UsernamePath,
    task_id: Annotated[int, Path(gt=0)],
    task_date: date,
    payload: CreateTaskRequest,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Modifica una tarea individual en la agenda de un alumno asociado al usuario."""
    if user["role"] not in {"staff", "parent"}:
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)

    return _run_db_operation(
        tasks_db.update_student_task,
        db,
        user["role"],
        user["username"],
        student_username,
        task_id,
        task_date,
        payload.task_title,
        payload.task_date,
        payload.task_start_hour,
        payload.task_duration,
        payload.alt_task_id_fk,
    )


@router.post("/me", status_code=201)
def create_my_task(
    payload: CreateTaskRequest,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Crea una tarea para el alumno autenticado con horario o solo duración."""
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
        payload.task_start_hour,
        payload.task_duration,
        payload.alt_task_id_fk,
    )


@router.get("/me")
def get_my_tasks(
    task_date: date,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Consulta las tareas del alumno autenticado si tiene permiso de modificación."""
    if user["role"] != "student":
        raise_api_error(ErrorCode.TASK_CREATOR_REQUIRED)

    return _run_db_operation(
        tasks_db.list_student_tasks,
        db,
        "student",
        user["username"],
        user["username"],
        task_date,
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
    student_username: UsernamePath,
    task_id: Annotated[int, Path(gt=0)],
    task_date: date,
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
    )


@router.delete("/me/{task_id}")
def delete_my_task(
    task_id: Annotated[int, Path(gt=0)],
    task_date: date,
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
    )
