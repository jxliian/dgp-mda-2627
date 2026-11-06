from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from auth.dependencies import get_current_user
from auth.schemas import CurrentUser, LoginRequest, TokenResponse
from auth.security import create_access_token, verify_password
from DB.database import get_db
from gestion_usuarios.users_mng_db import users_mng_db

router = APIRouter(prefix="/auth", tags=["Autenticación"])


@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """HU-05: verifica las credenciales y genera la sesión (JWT)."""
    stored_hash = users_mng_db.getPasswordByEmail(db, data.email, data.role)

    # Mismo mensaje si el usuario no existe o si la contraseña está mal.
    if stored_hash is None or not verify_password(data.password, stored_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Email o contraseña incorrectos")

    token = create_access_token(data.email, data.role)
    return TokenResponse(access_token=token, role=data.role)


@router.get("/me", response_model=CurrentUser)
def me(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
    """Devuelve quién es el usuario del token. Útil para que la app restaure la sesión al abrirse."""
    return user