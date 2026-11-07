from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..DB.database import get_db
from ..auth.auth_backend import require_admin
from ..errors import raise_api_error
from .users_mng_db import users_mng_db

router = APIRouter(prefix="/users", tags=["users"])
Role = Literal["admin", "staff", "student", "parent"]


class CreateUserRequest(BaseModel):
    """Datos que requiere el endpoint para crear una cuenta de usuario."""

    username: str = Field(min_length=1, max_length=50)
    full_name: str = Field(min_length=1, max_length=150)
    password: str = Field(min_length=1)
    role: Role
    email: str | None = None


class UpdateUserRequest(BaseModel):
    """Campos opcionales que puede modificar el administrador en una cuenta."""

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "username": "nuevo_usuario",
                    "role": "staff",
                    "full_name": "Nombre completo",
                    "password": "nueva_contraseña",
                    "email": "nuevo@example.com",
                }
            ]
        }
    }

    username: str | None = Field(default=None, min_length=1, max_length=50)
    role: Role | None = None
    full_name: str | None = Field(default=None, min_length=1, max_length=150)
    password: str | None = Field(default=None, min_length=1)
    email: str | None = Field(default=None, max_length=254)


@router.post("", dependencies=[Depends(require_admin)])
def create_user(payload: CreateUserRequest, db: Session = Depends(get_db)) -> dict:
    """Crea un usuario; requiere una sesión de administrador."""
    result = users_mng_db.createUser(db, payload.username, payload.password, payload.role,
                           payload.full_name, payload.email)
    if result["errorCode"] != 0:
        raise_api_error(result["errorCode"])
    return result


@router.get("", dependencies=[Depends(require_admin)])
def get_users(role: Role, db: Session = Depends(get_db)) -> dict:
    """Consulta usuarios de un rol; requiere una sesión de administrador."""
    result = users_mng_db.getUsers(db, role)
    if result["errorCode"] != 0:
        raise_api_error(result["errorCode"])
    return result


@router.put("/{role}/{username}", dependencies=[Depends(require_admin)])
def edit_user(role: Role, username: str, payload: UpdateUserRequest,
              db: Session = Depends(get_db)) -> dict:
    """Edita la identidad, el rol o los datos de una cuenta; requiere sesión de administrador."""
    result = users_mng_db.updateUser(
        db,
        username,
        role,
        full_name=payload.full_name,
        email=payload.email,
        passwd_plain=payload.password,
        new_username=payload.username,
        new_role=payload.role,
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
