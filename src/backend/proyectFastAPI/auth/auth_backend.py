from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from ..DB.database import get_db
from .auth_db import auth_db

router = APIRouter(prefix="/auth", tags=["authentication"])
bearer_scheme = HTTPBearer(auto_error=False)
Role = Literal["admin", "staff", "student", "parent"]


class LoginRequest(BaseModel):
    """Datos de acceso requeridos para iniciar una sesión de usuario."""

    username: str = Field(min_length=1, max_length=50)
    password: str = Field(min_length=1)
    role: Role


def _unauthorized() -> HTTPException:
    """Construye la respuesta HTTP 401 para peticiones sin token válido."""
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token ausente o inválido",
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
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Se requiere una sesión de administrador",
        )
    return user


@router.post("/login")
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> dict:
    """Inicia sesión, reemplaza el token anterior y devuelve el nuevo token Bearer."""
    result = auth_db.login(db, payload.username, payload.password, payload.role)
    if result["errorCode"] != 0:
        status_code = 500 if result["errorCode"] == 500 else 401
        headers = {"WWW-Authenticate": "Bearer"} if status_code == 401 else None
        raise HTTPException(status_code=status_code, detail=result["errorMsg"], headers=headers)
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
    return {
        "errorCode": 0,
        "errorMsg": "Sesión cerrada",
        "username": user["username"],
        "role": user["role"],
    }
