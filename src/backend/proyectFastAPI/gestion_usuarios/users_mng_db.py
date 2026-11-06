from typing import Optional

from passlib.context import CryptContext
from sqlalchemy import text
from sqlalchemy.orm import Session

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Identifiers are internal constants; never accept table or column names from a request.
ROLE_CONFIG = {
    "admin": {"table": "Admn", "username": "admn_usr", "name": "admn_full_name", "email": "admn_email", "password": "admn_passwd", "token": "token"},
    "staff": {"table": "Staff", "username": "staff_usr", "name": "staff_full_name", "email": "staff_email", "password": "staff_passwd", "token": "token"},
    "student": {"table": "Student", "username": "stud_usr", "name": "stud_full_name", "password": "stud_password", "token": "token"},
    "parent": {"table": "Parents", "username": "par_usr", "name": "par_full_name", "email": "par_email", "password": "par_passwd", "token": "token"},
}


def _config(role: str) -> dict:
    """Obtiene la configuración de tabla y columnas permitida para un rol."""
    try:
        return ROLE_CONFIG[role.lower()]
    except (AttributeError, KeyError) as exc:
        raise ValueError(f"Rol no válido: {role!r}") from exc


def _ok(message: str = "OK", **data) -> dict:
    """Construye una respuesta JSON de operación correcta."""
    return {"errorCode": 0, "errorMsg": message, **data}


def _error(message: str, code: int = 1) -> dict:
    """Construye una respuesta JSON de error con su código y mensaje."""
    return {"errorCode": code, "errorMsg": message}


class UsersManagementDB:
    """Operaciones de usuarios; las respuestas son diccionarios JSON serializables."""

    def getUserByUsername(self, db: Session, username: str, role: str) -> dict:
        """Busca un usuario por nombre de usuario y devuelve sus datos públicos."""
        try:
            cfg = _config(role)
            fields = [cfg["username"], cfg["name"]]
            if "email" in cfg:
                fields.append(cfg["email"])
            row = db.execute(
                text(f"SELECT {', '.join(fields)} FROM {cfg['table']} WHERE {cfg['username']} = :username"),
                {"username": username},
            ).mappings().first()
            return _ok(**dict(row)) if row else _error("Usuario no encontrado")
        except ValueError as exc:
            return _error(str(exc))
        except Exception as exc:
            return _error(f"Error de base de datos: {exc}", 500)

    def getUserByEmail(self, db: Session, email: str, role: str) -> dict:
        """Busca por correo a los usuarios de roles que tienen ese campo."""
        try:
            cfg = _config(role)
            if "email" not in cfg:
                return _error("Los estudiantes no tienen correo electrónico")
            row = db.execute(
                text(f"SELECT {cfg['username']}, {cfg['name']}, {cfg['email']} FROM {cfg['table']} WHERE {cfg['email']} = :email"),
                {"email": email},
            ).mappings().first()
            return _ok(**dict(row)) if row else _error("Usuario no encontrado por email")
        except ValueError as exc:
            return _error(str(exc))
        except Exception as exc:
            return _error(f"Error de base de datos: {exc}", 500)

    def getUsers(self, db: Session, role: str) -> dict:
        """Lista las cuentas de un rol sin incluir hashes de contraseña ni tokens."""
        try:
            cfg = _config(role)
            fields = [cfg["username"], cfg["name"]]
            if "email" in cfg:
                fields.append(cfg["email"])
            rows = db.execute(text(f"SELECT {', '.join(fields)} FROM {cfg['table']} ORDER BY {cfg['username']}" )).mappings().all()
            return _ok(users=[dict(row) for row in rows])
        except ValueError as exc:
            return _error(str(exc))
        except Exception as exc:
            return _error(f"Error de base de datos: {exc}", 500)

    def getPassword(self, db: Session, username: str, role: str) -> Optional[str]:
        """Devuelve el hash de contraseña de la cuenta o None si no existe."""
        try:
            cfg = _config(role)
            return db.execute(
                text(f"SELECT {cfg['password']} FROM {cfg['table']} WHERE {cfg['username']} = :username"),
                {"username": username},
            ).scalar_one_or_none()
        except (ValueError, Exception):
            return None

    def updatePassword(self, db: Session, username: str, new_password_plain: str, role: str) -> dict:
        """Guarda un nuevo hash de contraseña e invalida el token activo."""
        try:
            cfg = _config(role)
            result = db.execute(
                text(f"UPDATE {cfg['table']} SET {cfg['password']} = :password, {cfg['token']} = NULL WHERE {cfg['username']} = :username"),
                {"password": pwd_context.hash(new_password_plain), "username": username},
            )
            if not result.rowcount:
                db.rollback()
                return _error("No se encontró el usuario para actualizar")
            db.commit()
            return _ok("Contraseña actualizada correctamente")
        except Exception as exc:
            db.rollback()
            return _error(f"Error al actualizar la contraseña: {exc}", 500)

    def createUser(self, db: Session, username: str, passwd_plain: str, role: str, full_name: str = "", email: Optional[str] = None) -> dict:
        """Crea una cuenta y guarda la contraseña en forma de hash."""
        try:
            cfg = _config(role)
            fields = [cfg["username"], cfg["name"], cfg["password"]]
            params = {"username": username, "full_name": full_name, "password": pwd_context.hash(passwd_plain)}
            values = [":username", ":full_name", ":password"]
            if "email" in cfg:
                if not email:
                    return _error("El correo electrónico es obligatorio")
                fields.insert(2, cfg["email"])
                values.insert(2, ":email")
                params["email"] = email
            db.execute(text(f"INSERT INTO {cfg['table']} ({', '.join(fields)}) VALUES ({', '.join(values)})"), params)
            db.commit()
            return _ok("Usuario creado con éxito")
        except ValueError as exc:
            return _error(str(exc))
        except Exception as exc:
            db.rollback()
            return _error(f"Error al crear el usuario: {exc}", 500)

    def deleteUser(self, db: Session, username: str, role: str) -> dict:
        """Elimina una cuenta y evita borrar al último administrador."""
        try:
            cfg = _config(role)
            # Serialize admin deletions so two concurrent requests cannot both remove
            # the final two administrators.
            if role.lower() == "admin":
                db.execute(text("LOCK TABLE Admn IN EXCLUSIVE MODE"))
                count = db.execute(text("SELECT COUNT(*) FROM Admn")).scalar_one()
                exists = db.execute(text("SELECT 1 FROM Admn WHERE admn_usr = :username"), {"username": username}).scalar_one_or_none()
                if exists and count <= 1:
                    db.rollback()
                    return _error("No se puede eliminar el último administrador")
            result = db.execute(text(f"DELETE FROM {cfg['table']} WHERE {cfg['username']} = :username"), {"username": username})
            if not result.rowcount:
                db.rollback()
                return _error("El usuario a eliminar no existe")
            db.commit()
            return _ok("Usuario eliminado correctamente")
        except Exception as exc:
            db.rollback()
            return _error(f"Error al eliminar el usuario: {exc}", 500)

    def updateUser(self, db: Session, username: str, role: str, full_name: Optional[str] = None,
                   email: Optional[str] = None, passwd_plain: Optional[str] = None) -> dict:
        """Actualiza los datos indicados y revoca la sesión al cambiar contraseña."""
        try:
            cfg = _config(role)
            updates = []
            params = {"username": username}
            if full_name is not None:
                updates.append(f"{cfg['name']} = :full_name")
                params["full_name"] = full_name
            if email is not None:
                if "email" not in cfg:
                    return _error("Los estudiantes no tienen correo electrónico")
                updates.append(f"{cfg['email']} = :email")
                params["email"] = email
            if passwd_plain is not None:
                updates.append(f"{cfg['password']} = :password")
                updates.append(f"{cfg['token']} = NULL")
                params["password"] = pwd_context.hash(passwd_plain)
            if not updates:
                return _error("Debe indicarse al menos un campo para editar")
            result = db.execute(text(f"UPDATE {cfg['table']} SET {', '.join(updates)} WHERE {cfg['username']} = :username"), params)
            if not result.rowcount:
                db.rollback()
                return _error("El usuario no existe")
            db.commit()
            return _ok("Usuario actualizado correctamente")
        except ValueError as exc:
            return _error(str(exc))
        except Exception as exc:
            db.rollback()
            return _error(f"Error al editar el usuario: {exc}", 500)

    def updateAvatar(self, db: Session, username: str, avatar_id: int) -> dict:
        """Actualiza el avatar asociado al estudiante indicado."""
        try:
            result = db.execute(text("UPDATE Student SET avatar_id_fk = :avatar_id WHERE stud_usr = :username"), {"avatar_id": avatar_id, "username": username})
            if not result.rowcount:
                db.rollback()
                return _error("Estudiante no encontrado")
            db.commit()
            return _ok("Avatar actualizado correctamente")
        except Exception as exc:
            db.rollback()
            return _error(f"Error al actualizar el avatar: {exc}", 500)


users_mng_db = UsersManagementDB()
