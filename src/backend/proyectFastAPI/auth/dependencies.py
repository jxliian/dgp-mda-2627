import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from auth.schemas import CurrentUser, Role
from auth.security import decode_access_token
from DB.database import get_db
from gestion_usuarios.users_mng_db import users_mng_db

_bearer = HTTPBearer(auto_error=False)

_UNAUTHORIZED = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Sesión no válida o caducada",
    headers={"WWW-Authenticate": "Bearer"},
)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> CurrentUser:
    """Lee el token de la cabecera Authorization y devuelve el usuario que hace la petición."""
    if credentials is None:
        raise _UNAUTHORIZED
    try:
        payload = decode_access_token(credentials.credentials)
    except jwt.PyJWTError:
        raise _UNAUTHORIZED

    # Se comprueba en la BD que la cuenta sigue existiendo: si el administrador
    # la ha eliminado (HU-02), su token deja de servir en ese mismo momento.
    user = users_mng_db.getUserByEmail(db, payload["sub"], payload["role"])
    if user.errorCode == 1:
        raise _UNAUTHORIZED
    if user.errorCode != 0:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Error interno del servidor")
    # Cuando exista la columna *_active, comprobarla aquí también.

    return CurrentUser(email=user.email, username=user.username, role=payload["role"])


def require_roles(*roles: Role):
    """Dependencia que solo deja pasar a los roles indicados, p. ej. require_roles("admin")."""

    def checker(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if user.role not in roles:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "No tienes permiso para esta acción")
        return user

    return checker