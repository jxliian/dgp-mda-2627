from typing import Annotated, Literal, Union

from fastapi import APIRouter, Depends, File, Path, Response, UploadFile
from pydantic import BaseModel, ConfigDict, EmailStr, Field, StrictBool, StrictInt, field_validator
from sqlalchemy.orm import Session

from ..DB.database import get_db
from ..auth.auth_backend import get_current_user, require_admin
from ..errors import ErrorCode, raise_api_error
from .users_mng_db import STUDENT_ACCESS_FIELDS, users_mng_db

router = APIRouter(prefix="/users", tags=["users"])
Role = Literal["admin", "staff", "student", "parent"]
UsernamePath = Annotated[str, Path(min_length=1, max_length=50, pattern=r"^\S+$")]
MAX_AVATAR_BYTES = 5 * 1024 * 1024
DEFAULT_AVATAR_SVG = b'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" role="img" aria-label="Avatar predeterminado">
<rect width="128" height="128" rx="64" fill="#e5e7eb"/>
<circle cx="64" cy="45" r="23" fill="#9ca3af"/>
<path d="M22 113c4-25 19-38 42-38s38 13 42 38" fill="#9ca3af"/>
</svg>'''


def _image_media_type(image: bytes) -> str | None:
    """Detecta PNG, JPEG o WebP por su firma y estructura básica."""
    if image.startswith(b"\x89PNG\r\n\x1a\n") and len(image) >= 45:
        width = int.from_bytes(image[16:20], "big")
        height = int.from_bytes(image[20:24], "big")
        if (
            image[12:16] == b"IHDR"
            and width > 0
            and height > 0
            and width * height <= 40_000_000
            and image[-12:] == b"\x00\x00\x00\x00IEND\xaeB`\x82"
        ):
            return "image/png"
    if len(image) >= 8 and image.startswith(b"\xff\xd8\xff") and image.endswith(b"\xff\xd9"):
        return "image/jpeg"
    if (
        len(image) >= 20
        and image[:4] == b"RIFF"
        and image[8:12] == b"WEBP"
        and int.from_bytes(image[4:8], "little") == len(image) - 8
        and image[12:16] in {b"VP8 ", b"VP8L", b"VP8X"}
    ):
        return "image/webp"
    return None


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

    username: str = Field(strict=True, min_length=1, max_length=50)
    full_name: str = Field(strict=True, min_length=1, max_length=150)
    password: str = Field(strict=True, min_length=1)

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
    stud_access_main_col: str = Field(strict=True, min_length=4, max_length=7, pattern=r"^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$")
    stud_access_sec_col: str = Field(strict=True, min_length=4, max_length=7, pattern=r"^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$")
    stud_access_ntasks_visible: StrictInt = Field(ge=0)
    stud_access_pictograms: StrictBool
    stud_access_contrast: StrictBool
    stud_access_fontsize: StrictInt = Field(gt=0)
    stud_access_filters: StrictBool
    stud_access_ndays_visible: StrictInt = Field(ge=0)
    stud_access_prof_mod: StrictBool
    stud_access_timebar: StrictBool
    stud_access_talkback: StrictBool
    stud_access_profile_mod: StrictBool
    stud_access_task_mod: StrictBool


class CreateNonStudentRequest(CreateUserBase):
    """El correo legado es opcional; el formulario actual no lo solicita."""

    role: Literal["admin", "staff", "parent"]
    email: EmailStr | None = Field(default=None, max_length=254)


CreateUserRequest = Annotated[
    Union[CreateStudentRequest, CreateNonStudentRequest],
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
                    "role": "admin",
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

    username: str | None = Field(default=None, strict=True, min_length=1, max_length=50)
    role: Role | None = None
    full_name: str | None = Field(default=None, strict=True, min_length=1, max_length=150)
    password: str | None = Field(default=None, strict=True, min_length=1)
    email: EmailStr | None = Field(default=None, max_length=254)
    stud_access_main_col: str | None = Field(default=None, strict=True, min_length=4, max_length=7, pattern=r"^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$")
    stud_access_sec_col: str | None = Field(default=None, strict=True, min_length=4, max_length=7, pattern=r"^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$")
    stud_access_ntasks_visible: StrictInt | None = Field(default=None, ge=0)
    stud_access_pictograms: StrictBool | None = None
    stud_access_contrast: StrictBool | None = None
    stud_access_fontsize: StrictInt | None = Field(default=None, gt=0)
    stud_access_filters: StrictBool | None = None
    stud_access_ndays_visible: StrictInt | None = Field(default=None, ge=0)
    stud_access_prof_mod: StrictBool | None = None
    stud_access_timebar: StrictBool | None = None
    stud_access_talkback: StrictBool | None = None
    stud_access_profile_mod: StrictBool | None = None
    stud_access_task_mod: StrictBool | None = None

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
        {key: getattr(payload, key) for key in STUDENT_ACCESS_FIELDS}
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
def edit_user(role: Role, username: UsernamePath, payload: UpdateUserRequest,
              db: Session = Depends(get_db), user: dict = Depends(get_current_user)) -> dict:
    """Permite actualizar el perfil propio y reserva username, nombre y rol a administradores."""
    fields = payload.model_dump(exclude_unset=True)
    is_admin = user["role"] == "admin"
    if not is_admin:
        if user['role'] == 'student' and 'password' in fields:
            raise_api_error(ErrorCode.PROFILE_UPDATE_DENIED)
        if user["role"] != role or user["username"] != username:
            raise_api_error(ErrorCode.PROFILE_UPDATE_DENIED)
        if any(field in fields for field in ("username", "full_name", "role")):
            raise_api_error(ErrorCode.PROFILE_UPDATE_DENIED)
        if any(field in fields for field in (
            'stud_access_prof_mod', 'stud_access_profile_mod', 'stud_access_task_mod'
        )):
            raise_api_error(ErrorCode.PROFILE_UPDATE_DENIED)

    access_settings = {
        key: fields[key]
        for key in STUDENT_ACCESS_FIELDS
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


@router.delete("/{role}/{username}")
def delete_user(role: Role, username: UsernamePath, db: Session = Depends(get_db),
                user: dict = Depends(require_admin)) -> dict:
    """Elimina otra cuenta; impide el autoborrado y eliminar al último administrador."""
    if role == 'admin' and username == user['username']:
        raise_api_error(ErrorCode.ADMIN_SELF_DELETE_DENIED)
    result = users_mng_db.deleteUser(db, username, role)
    if result["errorCode"] != 0:
        raise_api_error(result["errorCode"])
    return result


@router.put("/students/me/avatar", status_code=200)
async def update_my_avatar(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Guarda la foto del alumno autenticado tras validar tipo y tamaño."""
    if user["role"] != "student":
        raise_api_error(ErrorCode.PROFILE_UPDATE_DENIED)
    try:
        image = await file.read(MAX_AVATAR_BYTES + 1)
        if len(image) > MAX_AVATAR_BYTES:
            raise_api_error(ErrorCode.AVATAR_TOO_LARGE)
        media_type = _image_media_type(image)
        if media_type is None:
            raise_api_error(ErrorCode.AVATAR_INVALID_IMAGE)
        result = users_mng_db.updateAvatar(db, user["username"], image)
        if result["errorCode"] != 0:
            raise_api_error(result["errorCode"])
        return {
            **result,
            "media_type": media_type,
            "avatar_url": "/users/students/me/avatar",
        }
    finally:
        await file.close()


@router.get("/students/me/avatar")
def get_my_avatar(
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> Response:
    """Devuelve la foto del alumno o un avatar SVG predeterminado."""
    if user["role"] != "student":
        raise_api_error(ErrorCode.PROFILE_UPDATE_DENIED)
    result = users_mng_db.getAvatar(db, user["username"])
    if result["errorCode"] != 0:
        raise_api_error(result["errorCode"])
    image = result.get("avatar_bin")
    media_type = _image_media_type(image) if image else None
    if media_type is None:
        return Response(
            content=DEFAULT_AVATAR_SVG,
            media_type="image/svg+xml",
            headers={"Cache-Control": "no-store"},
        )
    return Response(
        content=image,
        media_type=media_type,
        headers={"Cache-Control": "no-store"},
    )


@router.get("/students/{student_username}/avatar-image")
def get_class_student_avatar(
    student_username: UsernamePath,
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> Response:
    """Sirve el avatar a admin o a personal que comparte clase con el alumno."""
    if user["role"] != "admin" and not (
        user["role"] == "staff"
        and users_mng_db.staffCanViewStudentAvatar(db, user["username"], student_username)
    ):
        raise_api_error(ErrorCode.ASSOCIATION_ACCESS_DENIED)

    result = users_mng_db.getAvatar(db, student_username)
    if result["errorCode"] != 0:
        raise_api_error(result["errorCode"])
    image = result.get("avatar_bin")
    media_type = _image_media_type(image) if image else None
    if media_type is None:
        return Response(
            content=DEFAULT_AVATAR_SVG,
            media_type="image/svg+xml",
            headers={"Cache-Control": "no-store"},
        )
    return Response(
        content=image,
        media_type=media_type,
        headers={"Cache-Control": "no-store"},
    )
