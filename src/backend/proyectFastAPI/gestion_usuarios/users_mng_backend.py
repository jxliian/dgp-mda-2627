from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from auth.dependencies import require_roles
from auth.schemas import CurrentUser, Role
from DB.database import get_db
from gestion_usuarios.users_mng_db import users_mng_db

router = APIRouter(prefix="/users", tags=["Usuarios"])


class UserDetail(BaseModel):
    email: str
    username: str
    role: Role


@router.get("/{role}/{email}", response_model=UserDetail)
def get_user(
    role: Role,
    email: str,
    admin: CurrentUser = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> UserDetail:
    """HU-03: el administrador abre una cuenta para consultar sus datos principales."""
    email = email.strip().lower()
    result = users_mng_db.getUserByEmail(db, email, role)
    if result.errorCode == 1:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No existe ninguna cuenta con ese correo y rol")
    if result.errorCode != 0:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Error interno del servidor")
    return UserDetail(email=result.email, username=result.username, role=role)


@router.delete("/{role}/{email}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(
    role: Role,
    email: str,
    admin: CurrentUser = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> Response:
    """HU-02: el administrador elimina una cuenta.

    Sus asociaciones con alumnos o personas se borran en cascada (lo hace la BD), y su
    sesión deja de valer en ese momento porque get_current_user comprueba que la cuenta existe.
    """
    email = email.strip().lower()
    if role == "admin" and email == admin.email:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "No puedes eliminar tu propia cuenta")

    if not users_mng_db.deleteUserByEmail(db, email, role):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "No existe ninguna cuenta con ese correo y rol")
    return Response(status_code=status.HTTP_204_NO_CONTENT)