import hashlib
import secrets
import base64

from sqlalchemy import text
from sqlalchemy.orm import Session

from ..errors import ErrorCode, error_response, success_response
from ..gestion_usuarios.users_mng_db import (
    ROLE_CONFIG,
    ImagePasswordError,
    canonical_image_password,
    pwd_context,
)


def _config(role: str) -> dict:
    """Obtiene las tablas y columnas de autenticación correspondientes al rol."""
    try:
        return ROLE_CONFIG[role.lower()]
    except (AttributeError, KeyError) as exc:
        raise ValueError(f"Rol no válido: {role!r}") from exc


def _token_hash(token: str) -> str:
    """Calcula el hash SHA-256 usado para almacenar el token de sesión."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


class AuthDB:
    """Almacena una única sesión activa por usuario mediante el hash de su token."""

    def login(self, db: Session, username: str, password: str, role: str) -> dict:
        """Verifica la contraseña y crea una sesión que reemplaza la anterior."""
        try:
            cfg = _config(role)
            image_mode = role.lower() == "student"
            selected_fields = "account.password, profile.stud_access_img_pwd" if image_mode else "account.password, FALSE AS stud_access_img_pwd"
            row = db.execute(
                text(
                    f"SELECT {selected_fields} FROM users AS account "
                    f"JOIN {cfg['table']} AS profile "
                    f"ON profile.{cfg['username']} = account.username "
                    "WHERE account.username = :username"
                ),
                {"username": username},
            ).mappings().first()

            if not row:
                return error_response(ErrorCode.INVALID_CREDENTIALS)
            candidate = password
            if row["stud_access_img_pwd"]:
                try:
                    candidate, _ = canonical_image_password(password)
                except ImagePasswordError:
                    return error_response(ErrorCode.INVALID_CREDENTIALS)
            if not pwd_context.verify(candidate, row["password"]):
                return error_response(ErrorCode.INVALID_CREDENTIALS)

            token = secrets.token_urlsafe(32)
            db.execute(
                text(
                    "UPDATE users SET token = :token WHERE username = :username"
                ),
                {"token": _token_hash(token), "username": username},
            )
            db.commit()

            user = {
                "username": username,
                "role": role.lower(),
            }
            return success_response(
                access_token=token,
                token_type="bearer",
                user=user,
            )
        except ValueError:
            db.rollback()
            return error_response(ErrorCode.INVALID_ROLE)
        except Exception:
            db.rollback()
            return error_response(ErrorCode.LOGIN_FAILED)

    def getUserByToken(self, db: Session, token: str) -> dict | None:
        """Busca al usuario cuya sesión activa coincide con el token presentado."""
        token_hash = _token_hash(token)
        for role, cfg in ROLE_CONFIG.items():
            row = db.execute(
                text(
                    "SELECT account.username, account.full_name "
                    f"FROM users AS account JOIN {cfg['table']} AS profile "
                    f"ON profile.{cfg['username']} = account.username "
                    "WHERE account.token = :token"
                ),
                {"token": token_hash},
            ).mappings().first()
            if row:
                return {**dict(row), "role": role}
        return None

    def logout(self, db: Session, token: str) -> bool:
        """Revoca la sesión activa asociada al token y devuelve si encontró una."""
        token_hash = _token_hash(token)
        try:
            result = db.execute(
                text("UPDATE users SET token = NULL WHERE token = :token"),
                {"token": token_hash},
            )
            if result.rowcount:
                db.commit()
                return True
            db.rollback()
            return False
        except Exception:
            db.rollback()
            raise

    def get_password_images(self, db: Session) -> dict:
        """Devuelve el catálogo de imágenes, codificando los binarios en Base64."""
        rows = db.execute(
            text("SELECT pwd_id, pwd_bin, pwd_active FROM passwords ORDER BY pwd_id")
        ).mappings().all()
        return success_response(
            images=[
                {
                    "pwd_id": row["pwd_id"],
                    "pwd_bin": base64.b64encode(row["pwd_bin"]).decode("ascii"),
                    "pwd_active": row["pwd_active"],
                }
                for row in rows
            ]
        )

    def get_login_mode(self, db: Session, username: str, role: str) -> dict:
        """Devuelve si el alumno usa acceso gráfico; otros casos dan false."""
        enabled = False
        if role.lower() == "student":
            enabled = bool(
                db.execute(
                    text("SELECT stud_access_img_pwd FROM Student WHERE stud_usr = :username"),
                    {"username": username},
                ).scalar_one_or_none()
            )
        return success_response(stud_access_img_pwd=enabled)

    def create_password_image(self, db: Session, image: bytes) -> dict:
        try:
            pwd_id = db.execute(
                text("INSERT INTO passwords (pwd_bin) VALUES (:image) RETURNING pwd_id"),
                {"image": image},
            ).scalar_one()
            db.commit()
            return success_response(pwd_id=pwd_id)
        except Exception:
            db.rollback()
            return error_response(ErrorCode.INTERNAL_ERROR)

    def update_password_image(self, db: Session, pwd_id: int, image: bytes) -> dict:
        try:
            result = db.execute(
                text("UPDATE passwords SET pwd_bin = :image WHERE pwd_id = :pwd_id AND pwd_active = TRUE"),
                {"image": image, "pwd_id": pwd_id},
            )
            if not result.rowcount:
                db.rollback()
                return error_response(ErrorCode.USER_NOT_FOUND)
            db.commit()
            return success_response(pwd_id=pwd_id)
        except Exception:
            db.rollback()
            return error_response(ErrorCode.INTERNAL_ERROR)

    def deactivate_password_image(self, db: Session, pwd_id: int) -> dict:
        try:
            result = db.execute(
                text("UPDATE passwords SET pwd_active = FALSE WHERE pwd_id = :pwd_id AND pwd_active = TRUE"),
                {"pwd_id": pwd_id},
            )
            if not result.rowcount:
                db.rollback()
                return error_response(ErrorCode.USER_NOT_FOUND)
            db.commit()
            return success_response(pwd_id=pwd_id)
        except Exception:
            db.rollback()
            return error_response(ErrorCode.INTERNAL_ERROR)


auth_db = AuthDB()
