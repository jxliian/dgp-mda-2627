from datetime import time
from importlib import import_module

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..DB.database import get_db
from ..auth.auth_backend import get_current_user

tasks_db = import_module(".studs_tasks_db", package=__package__)

router = APIRouter(prefix="/student-tasks", tags=["student tasks"])


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
    """Crea y asigna una tarea a un alumno asociado al staff autenticado."""
    if user["role"] != "staff":
        raise HTTPException(status_code=403, detail="Se requiere una sesión de personal")

    try:
        return tasks_db.create_task(
            db,
            user["username"],
            student_username,
            payload.task_title,
            payload.task_start_hour,
            payload.task_duration,
            payload.alt_task_id_fk,
        )
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc


@router.put("/{task_id}/alternative")
def set_task_alternative(
    task_id: int,
    payload: SetAlternativeTaskRequest,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Asocia o desasocia una tarea alternativa de una tarea creada por el staff."""
    if user["role"] != "staff":
        raise HTTPException(status_code=403, detail="Se requiere una sesión de personal")

    try:
        return tasks_db.set_alternative_task(
            db,
            user["username"],
            task_id,
            payload.alt_task_id_fk,
        )
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
