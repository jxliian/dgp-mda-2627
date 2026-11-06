import hashlib
import secrets

from sqlalchemy import text
from sqlalchemy.orm import Session

from ..gestion_usuarios.users_mng_db import ROLE_CONFIG, pwd_context


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
            row = db.execute(
                text(
                    f"SELECT {cfg['password']} FROM {cfg['table']} "
                    f"WHERE {cfg['username']} = :username"
                ),
                {"username": username},
            ).mappings().first()

            if not row or not pwd_context.verify(password, row[cfg["password"]]):
                return {"errorCode": 1, "errorMsg": "Usuario o contraseña incorrectos"}

            token = secrets.token_urlsafe(32)
            db.execute(
                text(
                    f"UPDATE {cfg['table']} SET {cfg['token']} = :token "
                    f"WHERE {cfg['username']} = :username"
                ),
                {"token": _token_hash(token), "username": username},
            )
            db.commit()

            user = {
                "username": username,
                "role": role.lower(),
            }
            return {
                "errorCode": 0,
                "errorMsg": "Inicio de sesión correcto",
                "access_token": token,
                "token_type": "bearer",
                "user": user,
            }
        except ValueError as exc:
            db.rollback()
            return {"errorCode": 1, "errorMsg": str(exc)}
        except Exception:
            db.rollback()
            return {"errorCode": 500, "errorMsg": "No se pudo iniciar sesión"}

    def getUserByToken(self, db: Session, token: str) -> dict | None:
        """Busca al usuario cuya sesión activa coincide con el token presentado."""
        token_hash = _token_hash(token)
        for role, cfg in ROLE_CONFIG.items():
            row = db.execute(
                text(
                    f"SELECT {cfg['username']} AS username, {cfg['name']} AS full_name "
                    f"FROM {cfg['table']} WHERE {cfg['token']} = :token"
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
            for cfg in ROLE_CONFIG.values():
                result = db.execute(
                    text(
                        f"UPDATE {cfg['table']} SET {cfg['token']} = NULL "
                        f"WHERE {cfg['token']} = :token"
                    ),
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


auth_db = AuthDB()
