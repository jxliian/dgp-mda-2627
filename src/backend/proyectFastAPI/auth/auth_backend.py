from typing import Literal

from fastapi import APIRouter, Depends, File, HTTPException, Path, Query, UploadFile
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


MAX_PASSWORD_IMAGE_BYTES = 5 * 1024 * 1024


def _valid_password_image(image: bytes) -> bool:
    """Acepta únicamente PNG, JPEG o WebP con una cabecera reconocible."""
    if image.startswith(b"\x89PNG\r\n\x1a\n") and len(image) >= 45:
        width = int.from_bytes(image[16:20], "big")
        height = int.from_bytes(image[20:24], "big")
        return (
            image[12:16] == b"IHDR"
            and width > 0
            and height > 0
            and width * height <= 40_000_000
            and image[-8:-4] == b"IEND"
            and image[-4:] == b"\xaeB`\x82"
        )
    if image.startswith(b"\xff\xd8\xff") and image.endswith(b"\xff\xd9"):
        return True
    return (
        len(image) >= 20
        and image[:4] == b"RIFF"
        and image[8:12] == b"WEBP"
        and int.from_bytes(image[4:8], "little") == len(image) - 8
        and image[12:16] in {b"VP8 ", b"VP8L", b"VP8X"}
    )


async def _read_password_image(file: UploadFile) -> bytes:
    image = await file.read(MAX_PASSWORD_IMAGE_BYTES + 1)
    if len(image) > MAX_PASSWORD_IMAGE_BYTES:
        raise_api_error(ErrorCode.AVATAR_TOO_LARGE)
    if not _valid_password_image(image):
        raise_api_error(ErrorCode.AVATAR_INVALID_IMAGE)
    return image

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


def get_optional_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> dict | None:
    """Devuelve la sesión válida si existe y permite solicitudes anónimas."""
    if credentials is None:
        return None
    user = auth_db.getUserByToken(db, credentials.credentials)
    if user is None:
        raise _unauthorized()
    return user


def require_admin(user: dict = Depends(get_current_user)) -> dict:
    """Permite la operación únicamente si la sesión pertenece a un administrador."""
    if user["role"] != "admin":
        raise_api_error(ErrorCode.ADMIN_REQUIRED)
    return user


def _password_image_response(result: dict) -> dict:
    if result["errorCode"] != 0:
        raise_api_error(result["errorCode"])
    return result


@router.post("/login")
def login(payload: LoginRequest, db: Session = Depends(get_db)) -> dict:
    """Inicia sesión, reemplaza el token anterior y devuelve el nuevo token Bearer."""
    result = auth_db.login(db, payload.username, payload.password, payload.role)
    if result["errorCode"] != 0:
        status_code = error_status(result["errorCode"])
        headers = {"WWW-Authenticate": "Bearer"} if status_code == 401 else None
        raise HTTPException(status_code=status_code, detail=result, headers=headers)
    return result


@router.get("/password-images")
def get_password_images(db: Session = Depends(get_db)) -> dict:
    """Entrega el catálogo de imágenes para el formulario de acceso."""
    return auth_db.get_password_images(db)


@router.get("/login-mode")
def get_login_mode(
    username: str = Query(min_length=1, max_length=50),
    role: Role = Query(),
    db: Session = Depends(get_db),
) -> dict:
    """Indica si esa cuenta usa contraseña gráfica; no requiere iniciar sesión."""
    if any(character.isspace() for character in username):
        raise_api_error(ErrorCode.INVALID_REQUEST)
    return auth_db.get_login_mode(db, username, role)


@router.post("/password-images", status_code=201, dependencies=[Depends(require_admin)])
async def create_password_image(
    file: UploadFile = File(...), db: Session = Depends(get_db)
) -> dict:
    """Añade una imagen al catálogo; requiere administrador."""
    return _password_image_response(
        auth_db.create_password_image(db, await _read_password_image(file))
    )


@router.put("/password-images/{pwd_id}", dependencies=[Depends(require_admin)])
async def update_password_image(
    pwd_id: int = Path(gt=0), file: UploadFile = File(...), db: Session = Depends(get_db)
) -> dict:
    """Reemplaza el binario de una imagen activa; requiere administrador."""
    return _password_image_response(
        auth_db.update_password_image(db, pwd_id, await _read_password_image(file))
    )


@router.delete("/password-images/{pwd_id}", dependencies=[Depends(require_admin)])
def delete_password_image(
    pwd_id: int = Path(gt=0), db: Session = Depends(get_db)
) -> dict:
    """Desactiva una imagen sin borrar su ID histórico; requiere administrador."""
    return _password_image_response(auth_db.deactivate_password_image(db, pwd_id))


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
