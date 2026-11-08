from typing import Optional

from passlib.context import CryptContext
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..errors import ErrorCode, error_response, success_response

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Identifiers are internal constants; never accept table or column names from a request.
ROLE_CONFIG = {
    "admin": {"table": "Admn", "username": "admn_usr"},
    "staff": {"table": "Staff", "username": "staff_usr", "email": "staff_email"},
    "student": {"table": "Student", "username": "stud_usr"},
    "parent": {"table": "Parents", "username": "par_usr", "email": "par_email"},
}

STUDENT_ACCESS_FIELDS = (
    "stud_access_main_col",
    "stud_access_sec_col",
    "stud_access_ntasks_visible",
    "stud_access_pictograms",
    "stud_access_contrast",
    "stud_access_fontsize",
    "stud_access_filters",
    "stud_access_ndays_visible",
    "stud_access_prof_mod",
    "stud_access_timebar",
    "stud_access_talkback",
    "stud_access_profile_mod",
    "stud_access_task_mod",
)


def _config(role: str) -> dict:
    """Obtiene la configuración de tabla y columnas permitida para un rol."""
    try:
        return ROLE_CONFIG[role.lower()]
    except (AttributeError, KeyError) as exc:
        raise ValueError(f"Rol no válido: {role!r}") from exc


def _ok(**data) -> dict:
    """Construye una respuesta JSON correcta con el formato común de la API."""
    return success_response(**data)


def _error(code: ErrorCode) -> dict:
    """Construye una respuesta JSON de error usando el catálogo central."""
    return error_response(code)


def _username_exists(db: Session, username: str, excluded_username: Optional[str] = None) -> bool:
    """Comprueba si la clave global ya existe en la tabla común de usuarios."""
    query = "SELECT 1 FROM users WHERE username = :username"
    parameters = {"username": username}
    if excluded_username is not None:
        query += " AND username <> :excluded_username"
        parameters["excluded_username"] = excluded_username
    return db.execute(text(query), parameters).scalar_one_or_none() is not None


def _integrity_error_code(exc: IntegrityError, fallback: ErrorCode, username: bool = False) -> ErrorCode:
    """Traduce colisiones de unicidad conocidas a errores públicos seguros."""
    constraint = getattr(getattr(exc.orig, "diag", None), "constraint_name", "") or ""
    if username or constraint == "users_pkey" or "username" in constraint:
        return ErrorCode.USERNAME_TAKEN
    if "email" in constraint:
        return ErrorCode.EMAIL_TAKEN
    return fallback


class UsersManagementDB:
    """Operaciones de usuarios; las respuestas son diccionarios JSON serializables."""

    def getUserByUsername(self, db: Session, username: str, role: str) -> dict:
        """Busca un usuario por nombre de usuario y devuelve sus datos públicos."""
        try:
            cfg = _config(role)
            fields = [f"r.{cfg['username']} AS username", "u.full_name AS full_name"]
            if "email" in cfg:
                fields.append(f"r.{cfg['email']} AS email")
            if role.lower() == "student":
                fields.extend(f"r.{field}" for field in STUDENT_ACCESS_FIELDS)
            row = db.execute(
                text(
                    f"SELECT {', '.join(fields)} "
                    f"FROM {cfg['table']} AS r JOIN users AS u "
                    f"ON u.username = r.{cfg['username']} "
                    f"WHERE r.{cfg['username']} = :username"
                ),
                {"username": username},
            ).mappings().first()
            return _ok(**dict(row)) if row else _error(ErrorCode.USER_NOT_FOUND)
        except ValueError as exc:
            return _error(ErrorCode.INVALID_ROLE)
        except Exception:
            return _error(ErrorCode.USER_LOOKUP_FAILED)

    def getUserByEmail(self, db: Session, email: str, role: str) -> dict:
        """Busca por correo a los usuarios de roles que tienen ese campo."""
        try:
            cfg = _config(role)
            if "email" not in cfg:
                return _error(ErrorCode.EMAIL_UNAVAILABLE)
            row = db.execute(
                text(
                    f"SELECT r.{cfg['username']} AS username, u.full_name AS full_name, "
                    f"r.{cfg['email']} AS email "
                    f"FROM {cfg['table']} AS r JOIN users AS u "
                    f"ON u.username = r.{cfg['username']} "
                    f"WHERE r.{cfg['email']} = :email"
                ),
                {"email": email},
            ).mappings().first()
            return _ok(**dict(row)) if row else _error(ErrorCode.EMAIL_USER_NOT_FOUND)
        except ValueError as exc:
            return _error(ErrorCode.INVALID_ROLE)
        except Exception:
            return _error(ErrorCode.USER_LOOKUP_FAILED)

    def getUsers(self, db: Session, role: str) -> dict:
        """Lista las cuentas de un rol sin incluir hashes de contraseña ni tokens."""
        try:
            cfg = _config(role)
            fields = [f"r.{cfg['username']}", "u.full_name"]
            if "email" in cfg:
                fields.append(f"r.{cfg['email']}")
            if role.lower() == "student":
                fields.extend(f"r.{field}" for field in STUDENT_ACCESS_FIELDS)
            rows = db.execute(
                text(
                    f"SELECT {', '.join(fields)} "
                    f"FROM {cfg['table']} AS r JOIN users AS u "
                    f"ON u.username = r.{cfg['username']} "
                    f"ORDER BY r.{cfg['username']}"
                )
            ).mappings().all()
            return _ok(users=[dict(row) for row in rows])
        except ValueError as exc:
            return _error(ErrorCode.INVALID_ROLE)
        except Exception:
            return _error(ErrorCode.USER_LIST_FAILED)

    def getPassword(self, db: Session, username: str, role: str) -> Optional[str]:
        """Devuelve el hash de contraseña de la cuenta o None si no existe."""
        try:
            cfg = _config(role)
            return db.execute(
                text(
                    f"SELECT u.password FROM users AS u JOIN {cfg['table']} AS r "
                    f"ON r.{cfg['username']} = u.username WHERE u.username = :username"
                ),
                {"username": username},
            ).scalar_one_or_none()
        except (ValueError, Exception):
            return None

    def updatePassword(self, db: Session, username: str, new_password_plain: str, role: str) -> dict:
        """Guarda un nuevo hash de contraseña e invalida el token activo."""
        try:
            cfg = _config(role)
            result = db.execute(
                text(
                    "UPDATE users AS u SET password = :password, token = NULL "
                    f"WHERE u.username = :username AND EXISTS (SELECT 1 FROM {cfg['table']} AS r "
                    f"WHERE r.{cfg['username']} = u.username)"
                ),
                {"password": pwd_context.hash(new_password_plain), "username": username},
            )
            if not result.rowcount:
                db.rollback()
                return _error(ErrorCode.USER_NOT_FOUND)
            db.commit()
            return _ok()
        except ValueError:
            db.rollback()
            return _error(ErrorCode.INVALID_ROLE)
        except Exception:
            db.rollback()
            return _error(ErrorCode.PASSWORD_UPDATE_FAILED)

    def createUser(self, db: Session, username: str, passwd_plain: str, role: str, full_name: str = "", email: Optional[str] = None, access_settings: Optional[dict] = None) -> dict:
        """Crea el registro común y su especialización de rol en una transacción."""
        try:
            cfg = _config(role)
            if role.lower() == "student" and (
                not access_settings or any(field not in access_settings or access_settings[field] is None
                                           for field in STUDENT_ACCESS_FIELDS)
            ):
                return _error(ErrorCode.INVALID_REQUEST)
            if "email" in cfg:
                if not email:
                    return _error(ErrorCode.EMAIL_REQUIRED)
            if _username_exists(db, username):
                db.rollback()
                return _error(ErrorCode.USERNAME_TAKEN)

            db.execute(
                text(
                    "INSERT INTO users (username, full_name, password) "
                    "VALUES (:username, :full_name, :password)"
                ),
                {
                    "username": username,
                    "full_name": full_name,
                    "password": pwd_context.hash(passwd_plain),
                },
            )
            fields = [cfg["username"]]
            params = {"username": username}
            values = [":username"]
            if "email" in cfg:
                fields.insert(2, cfg["email"])
                values.insert(2, ":email")
                params["email"] = email
            if role.lower() == "student":
                fields.extend(STUDENT_ACCESS_FIELDS)
                values.extend(f":{field}" for field in STUDENT_ACCESS_FIELDS)
                params.update({field: access_settings[field] for field in STUDENT_ACCESS_FIELDS})
            db.execute(text(f"INSERT INTO {cfg['table']} ({', '.join(fields)}) VALUES ({', '.join(values)})"), params)
            db.commit()
            return _ok()
        except ValueError as exc:
            db.rollback()
            return _error(ErrorCode.INVALID_ROLE)
        except IntegrityError as exc:
            db.rollback()
            return _error(_integrity_error_code(exc, ErrorCode.USER_CREATE_FAILED))
        except Exception:
            db.rollback()
            return _error(ErrorCode.USER_CREATE_FAILED)

    def deleteUser(self, db: Session, username: str, role: str) -> dict:
        """Elimina una cuenta y evita borrar al último administrador."""
        try:
            cfg = _config(role)
            if role.lower() == "admin":
                db.execute(text("LOCK TABLE Admn IN EXCLUSIVE MODE"))
                count = db.execute(text("SELECT COUNT(*) FROM Admn")).scalar_one()
                exists = db.execute(text("SELECT 1 FROM Admn WHERE admn_usr = :username"), {"username": username}).scalar_one_or_none()
                if exists and count <= 1:
                    db.rollback()
                    return _error(ErrorCode.LAST_ADMIN)
            result = db.execute(
                text(
                    "DELETE FROM users AS u WHERE u.username = :username "
                    f"AND EXISTS (SELECT 1 FROM {cfg['table']} AS r "
                    f"WHERE r.{cfg['username']} = u.username)"
                ),
                {"username": username},
            )
            if not result.rowcount:
                db.rollback()
                return _error(ErrorCode.USER_NOT_FOUND)
            db.commit()
            return _ok()
        except ValueError:
            db.rollback()
            return _error(ErrorCode.INVALID_ROLE)
        except Exception:
            db.rollback()
            return _error(ErrorCode.USER_DELETE_FAILED)

    def updateUser(self, db: Session, username: str, role: str, full_name: Optional[str] = None,
                   email: Optional[str] = None, passwd_plain: Optional[str] = None,
                   new_username: Optional[str] = None, new_role: Optional[str] = None,
                   access_settings: Optional[dict] = None, actor_username: Optional[str] = None,
                   actor_role: Optional[str] = None) -> dict:
        """Edita una cuenta común y su tipo de usuario, revocando sesión si cambia su identidad."""
        try:
            source_role = role.lower()
            target_role = (new_role or role).lower()
            source_cfg = _config(source_role)
            target_cfg = _config(target_role)
            target_username = new_username or username
            identity_changed = source_role != target_role or username != target_username
            access_settings = access_settings or {}
            unknown_access_fields = set(access_settings) - set(STUDENT_ACCESS_FIELDS)
            if unknown_access_fields:
                return _error(ErrorCode.INVALID_REQUEST)

            if actor_role is not None and actor_role.lower() != "admin":
                if actor_role.lower() != source_role or actor_username != username:
                    return _error(ErrorCode.PROFILE_UPDATE_DENIED)
                if new_username is not None or new_role is not None:
                    return _error(ErrorCode.PROFILE_UPDATE_DENIED)

            if all(value is None for value in (full_name, email, passwd_plain, new_username, new_role)) and not access_settings:
                return _error(ErrorCode.NO_UPDATE_FIELDS)
            if any(value is None for value in access_settings.values()):
                return _error(ErrorCode.INVALID_REQUEST)

            if source_role == "admin" and target_role != "admin":
                db.execute(text("LOCK TABLE Admn IN EXCLUSIVE MODE"))

            selected_fields = ["u.username"]
            if "email" in source_cfg:
                selected_fields.append(f"r.{source_cfg['email']} AS email")
            if source_role == "student":
                selected_fields.append("r.stud_access_profile_mod AS stud_access_profile_mod")
            old_row = db.execute(
                text(
                    f"SELECT {', '.join(selected_fields)} "
                    f"FROM users AS u JOIN {source_cfg['table']} AS r "
                    f"ON r.{source_cfg['username']} = u.username "
                    "WHERE u.username = :username FOR UPDATE OF u, r"
                ),
                {"username": username},
            ).mappings().first()
            if old_row is None:
                db.rollback()
                return _error(ErrorCode.USER_NOT_FOUND)

            if actor_role is not None and actor_role.lower() == "student":
                if old_row["stud_access_profile_mod"] is not True:
                    db.rollback()
                    return _error(ErrorCode.PROFILE_UPDATE_DENIED)

            if access_settings and target_role != "student":
                db.rollback()
                return _error(ErrorCode.INVALID_REQUEST)
            if target_role == "student" and source_role != "student":
                if any(field not in access_settings or access_settings[field] is None
                       for field in STUDENT_ACCESS_FIELDS):
                    db.rollback()
                    return _error(ErrorCode.INVALID_REQUEST)

            if source_role == "admin" and target_role != "admin":
                admin_count = db.execute(text("SELECT COUNT(*) FROM Admn")).scalar_one()
                if admin_count <= 1:
                    db.rollback()
                    return _error(ErrorCode.LAST_ADMIN)

            if target_username != username and _username_exists(db, target_username):
                db.rollback()
                return _error(ErrorCode.USERNAME_TAKEN)

            if "email" in target_cfg:
                if email is not None:
                    target_email = email
                elif "email" in source_cfg:
                    target_email = old_row["email"]
                else:
                    db.rollback()
                    return _error(ErrorCode.EMAIL_REQUIRED)
                if not target_email:
                    db.rollback()
                    return _error(ErrorCode.EMAIL_REQUIRED)

                excluded_email_username = username if source_role == target_role else target_username
                email_exists = db.execute(
                    text(
                        f"SELECT 1 FROM {target_cfg['table']} "
                        f"WHERE {target_cfg['email']} = :email "
                        f"AND {target_cfg['username']} <> :excluded_username"
                    ),
                    {"email": target_email, "excluded_username": excluded_email_username},
                ).scalar_one_or_none()
                if email_exists is not None:
                    db.rollback()
                    return _error(ErrorCode.EMAIL_TAKEN)
            else:
                if email is not None:
                    db.rollback()
                    return _error(ErrorCode.EMAIL_UNAVAILABLE)
                target_email = None

            user_updates = []
            parameters = {"username": username}
            if target_username != username:
                user_updates.append("username = :new_username")
                parameters["new_username"] = target_username
            if full_name is not None:
                user_updates.append("full_name = :full_name")
                parameters["full_name"] = full_name
            if passwd_plain is not None:
                user_updates.append("password = :password")
                parameters["password"] = pwd_context.hash(passwd_plain)
            if identity_changed or passwd_plain is not None:
                user_updates.append("token = NULL")
            if user_updates:
                db.execute(
                    text(f"UPDATE users SET {', '.join(user_updates)} WHERE username = :username"),
                    parameters,
                )
                if target_username != username:
                    db.execute(
                        text("UPDATE Tasks SET task_creator = :new_username WHERE task_creator = :username"),
                        {"new_username": target_username, "username": username},
                    )
                    db.execute(
                        text("UPDATE Alt_Tasks SET alt_task_creator = :new_username WHERE alt_task_creator = :username"),
                        {"new_username": target_username, "username": username},
                    )

            if target_role != source_role:
                target_fields = [target_cfg["username"]]
                target_values = [":username"]
                target_parameters = {"username": target_username}
                if "email" in target_cfg:
                    target_fields.append(target_cfg["email"])
                    target_values.append(":email")
                    target_parameters["email"] = target_email
                if target_role == "student":
                    target_fields.extend(STUDENT_ACCESS_FIELDS)
                    target_values.extend(f":{field}" for field in STUDENT_ACCESS_FIELDS)
                    target_parameters.update(
                        {field: access_settings[field] for field in STUDENT_ACCESS_FIELDS}
                    )
                db.execute(
                    text(
                        f"INSERT INTO {target_cfg['table']} ({', '.join(target_fields)}) "
                        f"VALUES ({', '.join(target_values)})"
                    ),
                    target_parameters,
                )
                db.execute(
                    text(
                        f"DELETE FROM {source_cfg['table']} "
                        f"WHERE {source_cfg['username']} = :username"
                    ),
                    {"username": target_username},
                )
            else:
                profile_updates = []
                profile_parameters = {"username": target_username}
                if email is not None:
                    profile_updates.append(f"{source_cfg['email']} = :email")
                    profile_parameters["email"] = email
                if profile_updates:
                    db.execute(
                        text(
                            f"UPDATE {source_cfg['table']} SET {', '.join(profile_updates)} "
                            f"WHERE {source_cfg['username']} = :username"
                        ),
                        profile_parameters,
                    )
                if access_settings:
                    assignments = ", ".join(f"{field} = :{field}" for field in access_settings)
                    db.execute(
                        text(f"UPDATE Student SET {assignments} WHERE stud_usr = :username"),
                        {**access_settings, "username": target_username},
                    )

            db.commit()
            return _ok(username=target_username, role=target_role)
        except ValueError:
            db.rollback()
            return _error(ErrorCode.INVALID_ROLE)
        except IntegrityError as exc:
            db.rollback()
            return _error(_integrity_error_code(exc, ErrorCode.USER_UPDATE_FAILED))
        except Exception:
            db.rollback()
            return _error(ErrorCode.USER_UPDATE_FAILED)

    def updateAvatar(self, db: Session, username: str, avatar_id: int) -> dict:
        """Actualiza el avatar asociado al estudiante indicado."""
        try:
            result = db.execute(text("UPDATE Student SET avatar_id_fk = :avatar_id WHERE stud_usr = :username"), {"avatar_id": avatar_id, "username": username})
            if not result.rowcount:
                db.rollback()
                return _error(ErrorCode.USER_NOT_FOUND)
            db.commit()
            return _ok()
        except Exception:
            db.rollback()
            return _error(ErrorCode.AVATAR_UPDATE_FAILED)


users_mng_db = UsersManagementDB()
