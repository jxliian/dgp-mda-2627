from typing import Annotated, Literal, Union

from fastapi import APIRouter, Depends
from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator
from sqlalchemy.orm import Session

from ..DB.database import get_db
from ..auth.auth_backend import get_current_user, require_admin
from ..errors import ErrorCode, raise_api_error
from .users_mng_db import users_mng_db

router = APIRouter(prefix="/users", tags=["users"])
Role = Literal["admin", "staff", "student", "parent"]


def _validate_username(value: str | None) -> str | None:
    """Recorta el username y rechaza valores vacíos o con espacios internos."""
    if value is None:
        return None
    value = value.strip()
    if not value or any(character.isspace() for character in value):
        raise ValueError("El username no puede estar vacío ni contener espacios")
    return value


def _validate_full_name(value: str | None) -> str | None:
    """Recorta el nombre completo y rechaza nombres vacíos o con cifras."""
    if value is None:
        return None
    value = value.strip()
    if not value or any(character.isnumeric() for character in value) or not any(
        character.isalpha() for character in value
    ):
        raise ValueError("El nombre completo debe contener letras y no puede incluir números")
    return value


def _validate_password_length(value: str) -> str:
    """Evita que una contraseña exceda el límite de 72 bytes de bcrypt."""
    if len(value.encode("utf-8")) > 72:
        raise ValueError("La contraseña no puede superar los 72 bytes")
    return value


class CreateUserBase(BaseModel):
    """Campos comunes requeridos al crear cualquier cuenta."""

    model_config = ConfigDict(extra="forbid")

    username: str = Field(min_length=1, max_length=50)
    full_name: str = Field(min_length=1, max_length=150)
    password: str = Field(min_length=1)

    @field_validator("username")
    @classmethod
    def validate_username(cls, value: str) -> str:
        return _validate_username(value)

    @field_validator("full_name")
    @classmethod
    def validate_full_name(cls, value: str) -> str:
        return _validate_full_name(value)

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        return _validate_password_length(value)


class CreateStudentRequest(CreateUserBase):
    """Campos de creación de estudiante, incluidos sus ajustes de accesibilidad."""

    role: Literal["student"]
    stud_access_main_col: str = Field(min_length=1, max_length=50)
    stud_access_sec_col: str = Field(min_length=1, max_length=50)
    stud_access_ntasks_visible: int = Field(ge=0)
    stud_access_pictograms: bool
    stud_access_contrast: bool
    stud_access_fontsize: int = Field(gt=0)
    stud_access_filters: bool
    stud_access_ndays_visible: int = Field(ge=0)
    stud_access_prof_mod: bool
    stud_access_timebar: bool
    stud_access_talkback: bool
    stud_access_profile_mod: bool
    stud_access_task_mod: bool


class CreateEmailUserRequest(CreateUserBase):
    """Campos de creación para roles que requieren un correo válido."""

    role: Literal["admin", "staff", "parent"]
    email: EmailStr


CreateUserRequest = Annotated[
    Union[CreateStudentRequest, CreateEmailUserRequest],
    Field(discriminator="role"),
]


class UpdateUserRequest(BaseModel):
    """Campos de perfil o administración que se pueden modificar."""

    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "examples": [
                {
                    "username": "nuevo_usuario",
                    "role": "student",
                    "full_name": "Nombre completo",
                    "stud_access_main_col": "#ffffff",
                    "stud_access_sec_col": "#000000",
                    "stud_access_ntasks_visible": 5,
                    "stud_access_pictograms": True,
                    "stud_access_contrast": False,
                    "stud_access_fontsize": 18,
                    "stud_access_filters": True,
                    "stud_access_ndays_visible": 7,
                    "stud_access_prof_mod": False,
                    "stud_access_timebar": True,
                    "stud_access_talkback": False,
                    "stud_access_profile_mod": True,
                    "stud_access_task_mod": True,
                }
            ]
        },
    )

    username: str | None = Field(default=None, min_length=1, max_length=50)
    role: Role | None = None
    full_name: str | None = Field(default=None, min_length=1, max_length=150)
    password: str | None = Field(default=None, min_length=1)
    email: EmailStr | None = None
    stud_access_main_col: str | None = Field(default=None, min_length=1, max_length=50)
    stud_access_sec_col: str | None = Field(default=None, min_length=1, max_length=50)
    stud_access_ntasks_visible: int | None = Field(default=None, ge=0)
    stud_access_pictograms: bool | None = None
    stud_access_contrast: bool | None = None
    stud_access_fontsize: int | None = Field(default=None, gt=0)
    stud_access_filters: bool | None = None
    stud_access_ndays_visible: int | None = Field(default=None, ge=0)
    stud_access_prof_mod: bool | None = None
    stud_access_timebar: bool | None = None
    stud_access_talkback: bool | None = None
    stud_access_profile_mod: bool | None = None
    stud_access_task_mod: bool | None = None

    @field_validator("username")
    @classmethod
    def validate_username(cls, value: str | None) -> str | None:
        return _validate_username(value)

    @field_validator("full_name")
    @classmethod
    def validate_full_name(cls, value: str | None) -> str | None:
        return _validate_full_name(value)

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str | None) -> str | None:
        return _validate_password_length(value) if value is not None else None


@router.post("", dependencies=[Depends(require_admin)])
def create_user(payload: CreateUserRequest, db: Session = Depends(get_db)) -> dict:
    """Crea un usuario; requiere una sesión de administrador."""
    access_settings = (
        {key: getattr(payload, key) for key in users_mng_db.STUDENT_ACCESS_FIELDS}
        if payload.role == "student"
        else None
    )
    result = users_mng_db.createUser(
        db, payload.username, payload.password, payload.role, payload.full_name,
        getattr(payload, "email", None), access_settings=access_settings,
    )
    if result["errorCode"] != 0:
        raise_api_error(result["errorCode"])
    return result


@router.get("", dependencies=[Depends(require_admin)])
def get_users(role: Role | None = None, db: Session = Depends(get_db)) -> dict:
    """Consulta todas las cuentas o filtra por rol; requiere una sesión de administrador."""
    result = users_mng_db.getUsers(db, role)
    if result["errorCode"] != 0:
        raise_api_error(result["errorCode"])
    return result


@router.put("/{role}/{username}")
def edit_user(role: Role, username: str, payload: UpdateUserRequest,
              db: Session = Depends(get_db), user: dict = Depends(get_current_user)) -> dict:
    """Permite actualizar el perfil propio y reserva username, nombre y rol a administradores."""
    fields = payload.model_dump(exclude_unset=True)
    is_admin = user["role"] == "admin"
    if not is_admin:
        if user["role"] != role or user["username"] != username:
            raise_api_error(ErrorCode.PROFILE_UPDATE_DENIED)
        if any(field in fields for field in ("username", "full_name", "role")):
            raise_api_error(ErrorCode.PROFILE_UPDATE_DENIED)

    access_settings = {
        key: fields[key]
        for key in users_mng_db.STUDENT_ACCESS_FIELDS
        if key in fields
    }
    result = users_mng_db.updateUser(
        db,
        username,
        role,
        full_name=payload.full_name,
        email=payload.email,
        passwd_plain=payload.password,
        new_username=payload.username,
        new_role=payload.role,
        access_settings=access_settings,
        actor_username=user["username"],
        actor_role=user["role"],
    )
    if result["errorCode"] != 0:
        raise_api_error(result["errorCode"])
    return result


@router.delete("/{role}/{username}", dependencies=[Depends(require_admin)])
def delete_user(role: Role, username: str, db: Session = Depends(get_db)) -> dict:
    """Elimina un usuario; requiere administrador y no permite eliminar al último."""
    result = users_mng_db.deleteUser(db, username, role)
    if result["errorCode"] != 0:
        raise_api_error(result["errorCode"])
    return result
