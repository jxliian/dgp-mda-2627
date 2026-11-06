from datetime import datetime, timedelta, timezone

import bcrypt
import jwt

from config import settings


def hash_password(plain: str) -> str:
    """Cifra una contraseña con bcrypt. Lanza ValueError si supera los 72 bytes."""
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """Comprueba una contraseña contra su hash. Nunca lanza excepción: si algo falla, es False."""
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except ValueError:
        return False


def create_access_token(email: str, role: str) -> str:
    """Genera el JWT de sesión con el email (sub), el rol y la caducidad."""
    now = datetime.now(timezone.utc)
    payload = {
        "sub": email,
        "role": role,
        "iat": now,
        "exp": now + timedelta(minutes=settings.jwt_expire_minutes),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> dict:
    """Verifica firma y caducidad. Lanza jwt.PyJWTError si el token no es válido."""
    return jwt.decode(
        token,
        settings.jwt_secret_key,
        algorithms=[settings.jwt_algorithm],
        options={"require": ["sub", "role", "exp"]},
    )