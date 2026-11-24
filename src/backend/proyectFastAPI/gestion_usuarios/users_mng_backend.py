from typing import Annotated, Literal, Union

from fastapi import APIRouter, Depends, File, Path, Response, UploadFile
from pydantic import BaseModel, ConfigDict, Field, StrictBool, StrictInt, field_validator
from sqlalchemy.orm import Session

from ..DB.database import get_db
from ..auth.auth_backend import get_current_user, get_optional_current_user, require_admin
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
            and image[-8:-4] == b"IEND"
            and image[-4:] == b"\xaeB`\x82"
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


class CreateNonStudentUserRequest(CreateUserBase):
    """Campos de creación para administrador, personal o tutor."""

    role: Literal["admin", "staff", "parent"]


CreateUserRequest = Annotated[
    Union[CreateStudentRequest, CreateNonStudentUserRequest],
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
        access_settings=access_settings,
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


@router.get("/me")
def get_my_user(db: Session = Depends(get_db), user: dict = Depends(get_current_user)) -> dict:
    """Devuelve la ficha propia del usuario autenticado, incluidos los ajustes del alumno."""
    role = user["role"]
    result = users_mng_db.getUserByUsername(db, user["username"], role)
    if result["errorCode"] != 0:
        raise_api_error(result["errorCode"])
    return {**result, "role": role}


@router.put("/me/avatar", status_code=200)
async def update_my_avatar(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Permite cambiar la foto propia según los permisos del perfil."""
    if user["role"] == "student":
        profile = users_mng_db.getUserByUsername(db, user["username"], user["role"])
        if profile.get("stud_access_profile_mod") is not True:
            raise_api_error(ErrorCode.PROFILE_UPDATE_DENIED)
    return await _store_avatar(user["username"], user["role"], file, db)


@router.get("/me/avatar")
def get_my_avatar(
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> Response:
    """Devuelve la foto propia de cualquier tipo de cuenta."""
    return _image_response(db, user["username"])


@router.get("/{role}/{username}", dependencies=[Depends(require_admin)])
def get_user(role: Role, username: UsernamePath, db: Session = Depends(get_db)) -> dict:
    """Consulta los datos de una cuenta concreta; requiere una sesión de administrador."""
    result = users_mng_db.getUserByUsername(db, username, role)
    if result["errorCode"] != 0:
        raise_api_error(result["errorCode"])
    return {**result, "role": role}


@router.put("/{role}/{username}")
def edit_user(role: Role, username: UsernamePath, payload: UpdateUserRequest,
              db: Session = Depends(get_db), user: dict = Depends(get_current_user)) -> dict:
    """Permite actualizar el perfil propio y reserva username, nombre y rol a administradores."""
    fields = payload.model_dump(exclude_unset=True)
    is_admin = user["role"] == "admin"
    if not is_admin:
        if user["role"] != role or user["username"] != username:
            raise_api_error(ErrorCode.PROFILE_UPDATE_DENIED)
        if any(field in fields for field in ("username", "full_name", "role")):
            raise_api_error(ErrorCode.PROFILE_UPDATE_DENIED)
        if user["role"] == "student" and "password" in fields:
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
def delete_user(role: Role, username: UsernamePath, db: Session = Depends(get_db)) -> dict:
    """Elimina un usuario; requiere administrador y no permite eliminar al último."""
    result = users_mng_db.deleteUser(db, username, role)
    if result["errorCode"] != 0:
        raise_api_error(result["errorCode"])
    return result


async def _store_avatar(username: str, role: str, file: UploadFile, db: Session) -> dict:
    """Valida y guarda una foto para la cuenta del rol indicado."""
    try:
        image = await file.read(MAX_AVATAR_BYTES + 1)
        if len(image) > MAX_AVATAR_BYTES:
            raise_api_error(ErrorCode.AVATAR_TOO_LARGE)
        media_type = _image_media_type(image)
        if media_type is None:
            raise_api_error(ErrorCode.AVATAR_INVALID_IMAGE)
        account = users_mng_db.getUserByUsername(db, username, role)
        if account["errorCode"] != 0:
            raise_api_error(account["errorCode"])
        result = users_mng_db.updateAvatar(db, username, image)
        if result["errorCode"] != 0:
            raise_api_error(result["errorCode"])
        return {
            **result,
            "media_type": media_type,
            "avatar_url": f"/users/{role}/{username}/avatar-image",
        }
    finally:
        await file.close()


@router.put("/students/me/avatar", status_code=200)
async def update_my_student_avatar_legacy(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> dict:
    """Mantiene la ruta anterior de actualización propia para alumnos."""
    if user["role"] != "student":
        raise_api_error(ErrorCode.PROFILE_UPDATE_DENIED)
    profile = users_mng_db.getUserByUsername(db, user["username"], user["role"])
    if profile.get("stud_access_profile_mod") is not True:
        raise_api_error(ErrorCode.PROFILE_UPDATE_DENIED)
    return await _store_avatar(user["username"], user["role"], file, db)


@router.put("/students/{student_username}/avatar", status_code=200, dependencies=[Depends(require_admin)])
async def update_student_avatar_legacy(
    student_username: UsernamePath,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
) -> dict:
    """Mantiene la ruta anterior de actualización para cuentas de alumno."""
    return await _store_avatar(student_username, "student", file, db)


@router.put("/{role}/{username}/avatar", status_code=200, dependencies=[Depends(require_admin)])
async def update_user_avatar(
    role: Role,
    username: UsernamePath,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
) -> dict:
    """Permite al administrador cambiar la foto de cualquier cuenta."""
    return await _store_avatar(username, role, file, db)


def _image_response(db: Session, username: str) -> Response:
    result = users_mng_db.getAvatar(db, username)
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


def _can_view_user_avatar(
    db: Session, user: dict | None, role: str, username: str
) -> bool:
    """Aplica los permisos comunes y conserva el acceso contextual a fotos de alumnos."""
    if user is None:
        return role == "student" and users_mng_db.studentIsInAnyClass(db, username)
    if user["role"] == "admin" or (user["role"] == role and user["username"] == username):
        return True
    if role != "student":
        return False
    if user["role"] == "staff":
        return users_mng_db.staffCanViewStudentAvatar(db, user["username"], username)
    if user["role"] == "parent":
        return users_mng_db.parentCanViewStudentAvatar(db, user["username"], username)
    return False


@router.get("/students/me/avatar")
def get_my_student_avatar_legacy(
    db: Session = Depends(get_db),
    user: dict = Depends(get_current_user),
) -> Response:
    """Mantiene la ruta anterior de lectura para cuentas de alumno."""
    if user["role"] != "student":
        raise_api_error(ErrorCode.PROFILE_UPDATE_DENIED)
    return _image_response(db, user["username"])


@router.get("/students/{student_username}/avatar-image")
def get_class_student_avatar(
    student_username: UsernamePath,
    db: Session = Depends(get_db),
    user: dict | None = Depends(get_optional_current_user),
) -> Response:
    """Mantiene la ruta de foto de alumno usada por el directorio escolar."""
    if not _can_view_user_avatar(db, user, "student", student_username):
        raise_api_error(ErrorCode.ASSOCIATION_ACCESS_DENIED)
    account = users_mng_db.getUserByUsername(db, student_username, "student")
    if account["errorCode"] != 0:
        raise_api_error(account["errorCode"])
    return _image_response(db, student_username)


@router.get("/{role}/{username}/avatar-image")
def get_user_avatar(
    role: Role,
    username: UsernamePath,
    db: Session = Depends(get_db),
    user: dict | None = Depends(get_optional_current_user),
) -> Response:
    """Sirve la foto de cualquier cuenta a quien tenga autorización."""
    if not _can_view_user_avatar(db, user, role, username):
        raise_api_error(ErrorCode.ASSOCIATION_ACCESS_DENIED)
    account = users_mng_db.getUserByUsername(db, username, role)
    if account["errorCode"] != 0:
        raise_api_error(account["errorCode"])
    return _image_response(db, username)
