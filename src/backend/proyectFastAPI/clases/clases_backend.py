from datetime import date, time
from importlib import import_module
from typing import Annotated

from fastapi import APIRouter, Depends, Path
from pydantic import BaseModel, ConfigDict, Field, StrictInt, field_validator
from sqlalchemy.orm import Session

from ..DB.database import get_db
from ..auth.auth_backend import get_current_user, get_optional_current_user, require_admin
from ..errors import CatalogError, ErrorCode, raise_api_error, success_response
from . import clases_db

router = APIRouter(prefix="/classes", tags=["classes"])
tasks_db = import_module("..tareas alumnos.studs_tasks_db", package=__package__)
ClassNamePath = Annotated[str, Path(min_length=1, max_length=50, pattern=r"^\S(?:.*\S)?$")]
UsernamePath = Annotated[str, Path(min_length=1, max_length=50, pattern=r"^\S+$")]


def _run_db_operation(operation, *args):
    """Ejecuta una operación de datos y traduce sus errores de dominio a HTTP."""
    try:
        return operation(*args)
    except CatalogError as exc:
        raise_api_error(exc.code)


class ClassRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    class_name: str = Field(strict=True, min_length=1, max_length=50)

    @field_validator("class_name")
    @classmethod
    def validate_class_name(cls, value: str) -> str:
        """Recorta espacios y rechaza nombres de clase vacíos."""
        value = value.strip()
        if not value:
            raise ValueError("El nombre de la clase no puede estar vacío")
        return value


class CreateClassTaskRequest(BaseModel):
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


class CreateClassTaskStepRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    step_description: str = Field(strict=True, min_length=1)

    @field_validator("step_description")
    @classmethod
    def validate_step_description(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("La descripción del paso no puede estar vacía")
        return value


class ReorderClassTaskStepsRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    step_ids: list[StrictInt]

    @field_validator("step_ids")
    @classmethod
    def validate_step_ids(cls, value: list[int]) -> list[int]:
        if any(step_id <= 0 for step_id in value) or len(value) != len(set(value)):
            raise ValueError("Los identificadores deben ser positivos y no repetirse")
        return value


@router.post("", status_code=201, dependencies=[Depends(require_admin)])
def create_class(payload: ClassRequest, db: Session = Depends(get_db)) -> dict:
    """Crea una clase; solo los administradores pueden hacerlo."""
    return _run_db_operation(clases_db.create_class, db, payload.class_name)


@router.get("")
def list_classes(
    db: Session = Depends(get_db), user: dict | None = Depends(get_optional_current_user)
) -> dict:
    """Sin sesión lista solo nombres; admin y staff reciben sus clases con alumnos."""
    if user is None:
        return success_response(classes=clases_db.list_class_names(db))
    if user["role"] == "admin":
        return success_response(classes=clases_db.list_classes(db))
    if user["role"] != "staff":
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    return success_response(classes=clases_db.list_classes(db, user["username"]))


@router.get("/{class_name}")
def get_class(
    class_name: ClassNamePath,
    db: Session = Depends(get_db),
    user: dict | None = Depends(get_optional_current_user),
) -> dict:
    """Sin sesión muestra los alumnos; admin consulta cualquier clase y staff las suyas."""
    if user is None:
        return _run_db_operation(clases_db.get_class, db, class_name)
    if user["role"] == "admin":
        return _run_db_operation(clases_db.get_class, db, class_name)
    if user["role"] != "staff":
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    return _run_db_operation(clases_db.get_class, db, class_name, user["username"])


@router.put("/{current_class_name}", dependencies=[Depends(require_admin)])
def update_class(
    current_class_name: ClassNamePath, payload: ClassRequest, db: Session = Depends(get_db)
) -> dict:
    """Edita el nombre de una clase; solo los administradores pueden hacerlo."""
    return _run_db_operation(clases_db.update_class, db, current_class_name, payload.class_name)


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


@router.delete("/{class_name}/staff/{staff_username}", dependencies=[Depends(require_admin)])
def remove_staff_from_class(
    class_name: ClassNamePath, staff_username: UsernamePath, db: Session = Depends(get_db)
) -> dict:
    """Retira un miembro del personal de una clase; solo un administrador puede hacerlo."""
    return _run_db_operation(clases_db.remove_staff, db, class_name, staff_username)


@router.post("/{class_name}/students/{student_username}", status_code=201)
def add_student_to_class(
    class_name: ClassNamePath,
    student_username: UsernamePath,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Permite que admin inscriba en cualquier clase y staff en una propia."""
    if user["role"] == "admin":
        staff_username = None
    elif user["role"] == "staff":
        staff_username = user["username"]
    else:
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    return _run_db_operation(
        clases_db.add_student, db, class_name, staff_username, student_username
    )


@router.delete("/{class_name}/students/{student_username}")
def remove_student_from_class(
    class_name: ClassNamePath,
    student_username: UsernamePath,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Permite que admin retire de cualquier clase y staff de una propia."""
    if user["role"] == "admin":
        staff_username = None
    elif user["role"] == "staff":
        staff_username = user["username"]
    else:
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    return _run_db_operation(
        clases_db.remove_student, db, class_name, staff_username, student_username
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
    return _run_db_operation(
        clases_db.assign_task,
        db,
        class_name,
        user["username"],
        payload.task_title,
        payload.task_date,
        payload.task_start_hour,
        payload.task_duration,
        payload.alt_task_id_fk,
    )


@router.get("/{class_name}/tasks")
def get_class_tasks(
    class_name: ClassNamePath,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Lista las tareas vinculadas a una clase para su personal asignado."""
    if user["role"] != "staff":
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    return _run_db_operation(clases_db.list_class_tasks, db, class_name, user["username"])


@router.post("/{class_name}/tasks/{task_id}/steps", status_code=201)
def create_class_task_step(
    class_name: ClassNamePath,
    task_id: Annotated[int, Path(gt=0)],
    payload: CreateClassTaskStepRequest,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Añade un paso a una tarea de clase para personal asignado a esa clase."""
    if user["role"] != "staff":
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    return _run_db_operation(
        tasks_db.create_task_step,
        db,
        "staff",
        user["username"],
        task_id,
        payload.step_description,
        class_name,
    )


@router.put("/{class_name}/tasks/{task_id}/steps/order")
def reorder_class_task_steps(
    class_name: ClassNamePath,
    task_id: Annotated[int, Path(gt=0)],
    payload: ReorderClassTaskStepsRequest,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Guarda un orden de pasos solo si el personal creó la tarea de clase."""
    if user["role"] != "staff":
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    return _run_db_operation(
        tasks_db.reorder_task_steps,
        db,
        "staff",
        user["username"],
        task_id,
        payload.step_ids,
        class_name,
    )


@router.delete("/{class_name}/tasks/{task_id}/steps/{step_id}")
def delete_class_task_step(
    class_name: ClassNamePath,
    task_id: Annotated[int, Path(gt=0)],
    step_id: Annotated[int, Path(gt=0)],
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Elimina un paso si el personal está asignado a la clase de la tarea."""
    if user["role"] != "staff":
        raise_api_error(ErrorCode.CLASS_ACCESS_DENIED)
    return _run_db_operation(
        tasks_db.delete_task_step,
        db,
        "staff",
        user["username"],
        task_id,
        step_id,
        class_name,
    )


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
    return _run_db_operation(
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
    )


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
