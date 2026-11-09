from datetime import date, time
from typing import Annotated

from fastapi import APIRouter, Depends, Path
from pydantic import BaseModel, ConfigDict, Field, StrictInt, field_validator
from sqlalchemy.orm import Session

from ..DB.database import get_db
from ..activity_content import ActivityFields, decode_image, has_content, save_content, task_content
from ..auth.auth_backend import get_current_user, require_admin
from ..errors import CatalogError, ErrorCode, raise_api_error, success_response
from . import clases_db
from .class_media import save_class_image

router = APIRouter(prefix="/classes", tags=["classes"])
ClassNamePath = Annotated[str, Path(min_length=1, max_length=50, pattern=r"^\S(?:.*\S)?$")]
UsernamePath = Annotated[str, Path(min_length=1, max_length=50, pattern=r"^\S+$")]


def _run_db_operation(operation, *args, **kwargs):
    """Ejecuta una operación de datos y traduce sus errores de dominio a HTTP."""
    try:
        return operation(*args, **kwargs)
    except CatalogError as exc:
        raise_api_error(exc.code)


class ClassRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    class_name: str = Field(strict=True, min_length=1, max_length=50)
    class_image: str | None = Field(default=None, max_length=7_000_000)

    @field_validator('class_image')
    @classmethod
    def validate_class_image(cls, value: str | None) -> str | None:
        decode_image(value)
        return value

    @field_validator("class_name")
    @classmethod
    def validate_class_name(cls, value: str) -> str:
        """Recorta espacios y rechaza nombres de clase vacíos."""
        value = value.strip()
        if not value:
            raise ValueError("El nombre de la clase no puede estar vacío")
        return value


class CreateClassTaskRequest(ActivityFields):
    model_config = ConfigDict(extra="forbid")

    task_title: str = Field(strict=True, min_length=1, max_length=100)
    task_date: date
    task_start_hour: time
    task_duration: StrictInt = Field(gt=0)
    alt_task_id_fk: StrictInt | None = Field(default=None, gt=0)

    @field_validator("task_title")
    @classmethod
    def validate_task_title(cls, value: str) -> str:
        """Recorta espacios y rechaza títulos de tarea vacíos."""
        value = value.strip()
        if not value:
            raise ValueError("El título no puede estar vacío")
        return value

    @field_validator("task_start_hour")
    @classmethod
    def validate_task_start_hour(cls, value: time | None) -> time | None:
        """Exige que la hora de la tarea no incluya zona horaria."""
        if value is not None and value.utcoffset() is not None:
            raise ValueError("La hora debe expresarse sin zona horaria")
        return value


@router.post("", status_code=201, dependencies=[Depends(require_admin)])
def create_class(payload: ClassRequest, db: Session = Depends(get_db)) -> dict:
    """Crea una clase; solo los administradores pueden hacerlo."""
    result = _run_db_operation(clases_db.create_class, db, payload.class_name,
                               commit='class_image' not in payload.model_fields_set)
    return _finish_class_image(db, result, payload)


@router.get("")
def list_classes(
    db: Session = Depends(get_db), user: dict = Depends(get_current_user)
) -> dict:
    """Admin lista todas las clases y staff solo las clases que tiene asignadas."""
    if user["role"] == "admin":
        return success_response(classes=clases_db.list_classes(db))
    if user["role"] != "staff":
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    return success_response(classes=clases_db.list_classes(db, user["username"]))


@router.get("/{class_name}")
def get_class(
    class_name: ClassNamePath,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Admin consulta cualquier clase; staff solo consulta las clases asignadas."""
    if user["role"] == "admin":
        return _run_db_operation(clases_db.get_class, db, class_name)
    if user["role"] != "staff":
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    return _run_db_operation(clases_db.get_class, db, class_name, user["username"])


@router.put("/{current_class_name}", dependencies=[Depends(require_admin)])
def update_class(
    current_class_name: ClassNamePath, payload: ClassRequest, db: Session = Depends(get_db)
) -> dict:
    """Edita el nombre y la foto de una clase; requiere administrador."""
    result = _run_db_operation(clases_db.update_class, db, current_class_name, payload.class_name,
                               commit='class_image' not in payload.model_fields_set)
    return _finish_class_image(db, result, payload)


def _finish_class_image(db: Session, result: dict, payload: ClassRequest) -> dict:
    if 'class_image' in payload.model_fields_set:
        try:
            save_class_image(db, result['class_name'], payload.class_image)
            result['class_image'] = payload.class_image
            db.commit()
        except Exception:
            db.rollback()
            raise
    return result


@router.delete("/{class_name}", dependencies=[Depends(require_admin)])
def delete_class(class_name: ClassNamePath, db: Session = Depends(get_db)) -> dict:
    """Elimina una clase y sus asignaciones de alumnos y profesores."""
    return _run_db_operation(clases_db.delete_class, db, class_name)


@router.post("/{class_name}/staff/{staff_username}", dependencies=[Depends(require_admin)])
def add_staff_to_class(
    class_name: ClassNamePath, staff_username: UsernamePath, db: Session = Depends(get_db)
) -> dict:
    """Asigna un miembro del personal a una clase; solo un administrador puede hacerlo."""
    return _run_db_operation(clases_db.add_staff, db, class_name, staff_username)


@router.post("/{class_name}/students/{student_username}", status_code=201)
def add_student_to_class(
    class_name: ClassNamePath,
    student_username: UsernamePath,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Inscribe un alumno en la clase asignada al miembro del personal."""
    if user["role"] != "staff":
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    return _run_db_operation(
        clases_db.add_student, db, class_name, user["username"], student_username
    )


@router.delete("/{class_name}/students/{student_username}")
def remove_student_from_class(
    class_name: ClassNamePath,
    student_username: UsernamePath,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Retira un alumno de la clase asignada al miembro del personal."""
    if user["role"] != "staff":
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    return _run_db_operation(
        clases_db.remove_student, db, class_name, user["username"], student_username
    )


@router.post("/{class_name}/tasks", status_code=201)
def assign_task_to_class(
    class_name: ClassNamePath,
    payload: CreateClassTaskRequest,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Crea una tarea y la asigna a todos los alumnos inscritos en la clase."""
    if user["role"] != "staff":
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    result = _run_db_operation(
        clases_db.assign_task,
        db,
        class_name,
        user["username"],
        payload.task_title,
        payload.task_date,
        payload.task_start_hour,
        payload.task_duration,
        payload.alt_task_id_fk,
        commit=not has_content(payload),
    )
    return _finish_content(db, result, payload)


@router.get("/{class_name}/tasks")
def get_class_tasks(
    class_name: ClassNamePath,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Lista las tareas vinculadas a una clase para su personal asignado."""
    if user["role"] != "staff":
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    result = _run_db_operation(clases_db.list_class_tasks, db, class_name, user["username"])
    for task in result['tasks']:
        task.update(task_content(db, task['task_id']))
    return result


@router.put("/{class_name}/tasks/{task_id}")
def edit_class_task(
    class_name: ClassNamePath,
    task_id: Annotated[int, Path(gt=0)],
    payload: CreateClassTaskRequest,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Edita una tarea grupal y actualiza sus asignaciones a la clase."""
    if user["role"] != "staff":
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    result = _run_db_operation(
        clases_db.update_class_task,
        db,
        class_name,
        user["username"],
        task_id,
        payload.task_title,
        payload.task_date,
        payload.task_start_hour,
        payload.task_duration,
        payload.alt_task_id_fk,
        commit=not has_content(payload),
    )
    return _finish_content(db, result, payload)


def _finish_content(db: Session, result: dict, payload: CreateClassTaskRequest) -> dict:
    if has_content(payload):
        try:
            save_content(db, result['task_id'], payload)
            result.update(task_content(db, result['task_id']))
            db.commit()
        except Exception:
            db.rollback()
            raise
    return result


@router.delete("/{class_name}/tasks/{task_id}")
def delete_class_task(
    class_name: ClassNamePath,
    task_id: Annotated[int, Path(gt=0)],
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Elimina la asignación grupal sin borrar vínculos individuales."""
    if user["role"] != "staff":
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    return _run_db_operation(
        clases_db.delete_class_task, db, class_name, user["username"], task_id
    )
