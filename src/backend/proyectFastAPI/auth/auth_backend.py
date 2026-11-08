from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy.orm import Session

from ..DB.database import get_db
from ..errors import ErrorCode, error_response, error_status, raise_api_error, success_response
from .auth_db import auth_db

router = APIRouter(prefix="/auth", tags=["authentication"])
bearer_scheme = HTTPBearer(auto_error=False)
Role = Literal["admin", "staff", "student", "parent"]


class LoginRequest(BaseModel):
    """Datos de acceso requeridos para iniciar una sesión de usuario."""

    model_config = ConfigDict(extra="forbid")

    username: str = Field(strict=True, min_length=1, max_length=50)
    password: str = Field(strict=True, min_length=1)
    role: Role

    @field_validator("username")
    @classmethod
    def validate_username(cls, value: str) -> str:
        value = value.strip()
        if not value or any(character.isspace() for character in value):
            raise ValueError("El username no puede estar vacío ni contener espacios")
        return value

    @field_validator("password")
    @classmethod
    def validate_password_length(cls, value: str) -> str:
        if len(value.encode("utf-8")) > 72:
            raise ValueError("La contraseña no puede superar los 72 bytes")
        return value


def _unauthorized() -> HTTPException:
    """Construye la respuesta HTTP 401 para peticiones sin token válido."""
    return HTTPException(
        status_code=error_status(ErrorCode.INVALID_TOKEN),
        detail=error_response(ErrorCode.INVALID_TOKEN),
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> dict:
    """Valida el token Bearer y devuelve el usuario asociado a la sesión activa."""
    if credentials is None:
        raise _unauthorized()

    user = auth_db.getUserByToken(db, credentials.credentials)
    if user is None:
        raise _unauthorized()
    return user


def require_admin(user: dict = Depends(get_current_user)) -> dict:
    """Permite la operación únicamente si la sesión pertenece a un administrador."""
    if user["role"] != "admin":
        raise_api_error(ErrorCode.ADMIN_REQUIRED)
    return user


@router.post("/login")
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> dict:
    """Inicia sesión, reemplaza el token anterior y devuelve el nuevo token Bearer."""
    result = auth_db.login(db, payload.username, payload.password, payload.role)
    if result["errorCode"] != 0:
        status_code = error_status(result["errorCode"])
        headers = {"WWW-Authenticate": "Bearer"} if status_code == 401 else None
        raise HTTPException(status_code=status_code, detail=result, headers=headers)
    return result


@router.post("/logout")
def logout(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> dict:
    """Revoca el token Bearer de la sesión autenticada."""
    # get_current_user verifies this exact bearer token before it is revoked.
    if credentials is None or not auth_db.logout(db, credentials.credentials):
        raise _unauthorized()
    return success_response(username=user["username"], role=user["role"])
