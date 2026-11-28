from typing import Optional
from urllib.parse import quote

from passlib.context import CryptContext
from sqlalchemy import bindparam, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..errors import ErrorCode, error_response, success_response

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Identifiers are internal constants; never accept table or column names from a request.
ROLE_CONFIG = {

    "admin": {"table": "Admn", "username": "admn_usr"},
    "staff": {"table": "Staff", "username": "staff_usr"},
    "student": {"table": "Student", "username": "stud_usr"},
    "parent": {"table": "Parents", "username": "par_usr"},
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
    "stud_access_img_pwd",
)
STUDENT_ACCESS_PERMISSION_FIELDS = frozenset(
    {"stud_access_prof_mod", "stud_access_profile_mod", "stud_access_task_mod", "stud_access_img_pwd"}
)
DEFAULT_AVATAR = b'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" role="img" aria-label="Foto de perfil predeterminada">
<rect width="128" height="128" rx="64" fill="#e5e7eb"/>
<circle cx="64" cy="45" r="23" fill="#9ca3af"/>
<path d="M22 113c4-25 19-38 42-38s38 13 42 38" fill="#9ca3af"/>
</svg>'''

MIN_IMAGE_PASSWORD_IMAGES = 4
MAX_IMAGE_PASSWORD_IMAGES = 8
IMAGE_PASSWORD_ID_WIDTH = 5


class ImagePasswordError(ValueError):
    """La secuencia gráfica no cumple el formato o contiene imágenes inactivas."""


def canonical_image_password(value: str) -> tuple[str, list[int]]:
    """Lee IDs decimales concatenados en bloques fijos de cinco dígitos."""
    if not value.isascii() or not value.isdecimal() or len(value) % IMAGE_PASSWORD_ID_WIDTH:
        raise ImagePasswordError("La contraseña gráfica debe concatenar IDs de cinco dígitos")
    image_count = len(value) // IMAGE_PASSWORD_ID_WIDTH
    if not MIN_IMAGE_PASSWORD_IMAGES <= image_count <= MAX_IMAGE_PASSWORD_IMAGES:
        raise ImagePasswordError("La contraseña gráfica debe contener entre 4 y 8 imágenes")
    ids = [
        int(value[offset:offset + IMAGE_PASSWORD_ID_WIDTH])
        for offset in range(0, len(value), IMAGE_PASSWORD_ID_WIDTH)
    ]
    if any(image_id < 1 or image_id > 32767 for image_id in ids):
        raise ImagePasswordError("Los IDs deben pertenecer al catálogo de imágenes")
    if len(set(ids)) != len(ids):
        raise ImagePasswordError("No se puede repetir una imagen en la contraseña gráfica")
    canonical = "".join(f"{image_id:0{IMAGE_PASSWORD_ID_WIDTH}d}" for image_id in ids)
    return canonical, ids


def normalize_image_password(db: Session, value: str) -> str:
    """Valida que los IDs de la secuencia correspondan a imágenes activas."""
    canonical, ids = canonical_image_password(value)
    found = db.execute(
        text("SELECT COUNT(*) FROM passwords WHERE pwd_active = TRUE AND pwd_id IN :ids")
        .bindparams(bindparam("ids", expanding=True)),
        {"ids": ids},
    ).scalar_one()
    if found != len(ids):
        raise ImagePasswordError("La contraseña gráfica contiene imágenes inexistentes o inactivas")
    return canonical


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
    return fallback


class UsersManagementDB:
    """Operaciones de usuarios; las respuestas son diccionarios JSON serializables."""

    def getUserByUsername(self, db: Session, username: str, role: str) -> dict:
        """Busca un usuario por nombre de usuario y devuelve sus datos públicos."""
        try:
            cfg = _config(role)
            fields = [
                f"r.{cfg['username']} AS username",
                "u.full_name AS full_name",
            ]
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
            if row is None:
                return _error(ErrorCode.USER_NOT_FOUND)
            user = dict(row)
            user["avatar_url"] = f"/users/{role.lower()}/{quote(username, safe='')}/avatar-image"
            return _ok(**user)
        except ValueError as exc:
            return _error(ErrorCode.INVALID_ROLE)
        except Exception:
            return _error(ErrorCode.USER_LOOKUP_FAILED)

    def getUsers(self, db: Session, role: Optional[str] = None) -> dict:
        """Lista todas las cuentas o las de un rol, con username, nombre y rol."""
        try:
            selected_roles = [role.lower()] if role is not None else list(ROLE_CONFIG)
            users = []
            for selected_role in selected_roles:
                cfg = _config(selected_role)
                fields = [
                    f"r.{cfg['username']} AS username",
                    "u.full_name AS full_name",
                    ":role AS role",
                ]
                if selected_role == "student":
                    fields.extend(f"r.{field}" for field in STUDENT_ACCESS_FIELDS)
                rows = db.execute(
                    text(
                        f"SELECT {', '.join(fields)} "
                        f"FROM {cfg['table']} AS r JOIN users AS u "
                        f"ON u.username = r.{cfg['username']} "
                        f"ORDER BY r.{cfg['username']}"
                    ),
                    {"role": selected_role},
                ).mappings().all()
                for row in rows:
                    user = dict(row)
                    user["avatar_url"] = (
                        f"/users/{selected_role}/{quote(user['username'], safe='')}/avatar-image"
                    )
                    users.append(user)
            users.sort(key=lambda user: user["username"])
            return _ok(users=users)
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
            if role.lower() == "student":
                image_mode = db.execute(
                    text("SELECT stud_access_img_pwd FROM Student WHERE stud_usr = :username"),
                    {"username": username},
                ).scalar_one_or_none()
                if image_mode is None:
                    return _error(ErrorCode.USER_NOT_FOUND)
                if image_mode:
                    new_password_plain = normalize_image_password(db, new_password_plain)
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
        except ImagePasswordError:
            db.rollback()
            return _error(ErrorCode.INVALID_REQUEST)
        except ValueError:
            db.rollback()
            return _error(ErrorCode.INVALID_ROLE)
        except Exception:
            db.rollback()
            return _error(ErrorCode.PASSWORD_UPDATE_FAILED)

    def createUser(self, db: Session, username: str, passwd_plain: str, role: str, full_name: str = "", access_settings: Optional[dict] = None) -> dict:
        """Crea el registro común y su especialización de rol en una transacción."""
        try:
            cfg = _config(role)
            if role.lower() == "student" and (
                not access_settings or any(field not in access_settings or access_settings[field] is None
                                           for field in STUDENT_ACCESS_FIELDS)
            ):
                return _error(ErrorCode.INVALID_REQUEST)
            if role.lower() == "student" and access_settings["stud_access_img_pwd"]:
                passwd_plain = normalize_image_password(db, passwd_plain)
            if _username_exists(db, username):
                db.rollback()
                return _error(ErrorCode.USERNAME_TAKEN)

            avatar_id = db.execute(
                text(
                    "INSERT INTO Avatar (avatar_alt, avatar_bin) "
                    "VALUES (:avatar_alt, :avatar_bin) RETURNING avatar_id"
                ),
                {"avatar_alt": "Foto de perfil predeterminada", "avatar_bin": DEFAULT_AVATAR},
            ).scalar_one()
            db.execute(
                text(
                    "INSERT INTO users (username, full_name, password, avatar_id_fk) "
                    "VALUES (:username, :full_name, :password, :avatar_id_fk)"
                ),
                {
                    "username": username,
                    "full_name": full_name,
                    "password": pwd_context.hash(passwd_plain),
                    "avatar_id_fk": avatar_id,
                },
            )
            fields = [cfg["username"]]
            params = {"username": username}
            values = [":username"]
            if role.lower() == "student":
                fields.extend(STUDENT_ACCESS_FIELDS)
                values.extend(f":{field}" for field in STUDENT_ACCESS_FIELDS)
                params.update({field: access_settings[field] for field in STUDENT_ACCESS_FIELDS})
            db.execute(text(f"INSERT INTO {cfg['table']} ({', '.join(fields)}) VALUES ({', '.join(values)})"), params)
            db.commit()
            return _ok()
        except ImagePasswordError:
            db.rollback()
            return _error(ErrorCode.INVALID_REQUEST)
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
            avatar_id = db.execute(
                text(
                    "SELECT u.avatar_id_fk FROM users AS u "
                    f"JOIN {cfg['table']} AS r ON r.{cfg['username']} = u.username "
                    "WHERE u.username = :username FOR UPDATE OF u"
                ),
                {"username": username},
            ).scalar_one_or_none()
            if avatar_id is None:
                return _error(ErrorCode.USER_NOT_FOUND)
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
            db.execute(
                text(
                    "DELETE FROM Avatar AS a WHERE a.avatar_id = :avatar_id "
                    "AND NOT EXISTS (SELECT 1 FROM users u WHERE u.avatar_id_fk = a.avatar_id)"
                ),
                {"avatar_id": avatar_id},
            )
            db.commit()
            return _ok()
        except ValueError:
            db.rollback()
            return _error(ErrorCode.INVALID_ROLE)
        except Exception:
            db.rollback()
            return _error(ErrorCode.USER_DELETE_FAILED)

    def updateUser(self, db: Session, username: str, role: str, full_name: Optional[str] = None,
                   passwd_plain: Optional[str] = None,
                   new_username: Optional[str] = None, new_role: Optional[str] = None,
                   access_settings: Optional[dict] = None, actor_username: Optional[str] = None,
                   actor_role: Optional[str] = None) -> dict:
        """Edita la cuenta y mantiene inmutable el rol asignado al crearla."""
        try:
            source_role = role.lower()
            if new_role is not None and new_role.lower() != source_role:
                return _error(ErrorCode.ROLE_CHANGE_DENIED)
            target_role = source_role
            source_cfg = _config(source_role)
            target_username = new_username or username
            identity_changed = username != target_username

            access_settings = access_settings or {}
            if set(access_settings) - set(STUDENT_ACCESS_FIELDS):
                return _error(ErrorCode.INVALID_REQUEST)
            if actor_role is not None and actor_role.lower() != "admin":
                if actor_role.lower() != source_role or actor_username != username:
                    return _error(ErrorCode.PROFILE_UPDATE_DENIED)
                if new_username is not None or new_role is not None:
                    return _error(ErrorCode.PROFILE_UPDATE_DENIED)
                if full_name is not None:
                    return _error(ErrorCode.PROFILE_UPDATE_DENIED)
                if actor_role.lower() == "student" and passwd_plain is not None:
                    return _error(ErrorCode.PROFILE_UPDATE_DENIED)
                if actor_role.lower() == "student" and (
                    set(access_settings) & STUDENT_ACCESS_PERMISSION_FIELDS
                ):
                    return _error(ErrorCode.PROFILE_UPDATE_DENIED)
            if all(value is None for value in (full_name, passwd_plain, new_username, new_role)) and not access_settings:
                return _error(ErrorCode.NO_UPDATE_FIELDS)
            if any(value is None for value in access_settings.values()):
                return _error(ErrorCode.INVALID_REQUEST)

            selected_fields = ["u.username"]
            if source_role == "student":
                selected_fields.append("r.stud_access_profile_mod AS stud_access_profile_mod")
                selected_fields.append("r.stud_access_img_pwd AS stud_access_img_pwd")
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
            if (
                actor_role is not None
                and actor_role.lower() == "student"
                and not bool(old_row["stud_access_profile_mod"])
            ):
                db.rollback()
                return _error(ErrorCode.PROFILE_UPDATE_DENIED)
            if access_settings and target_role != "student":
                db.rollback()
                return _error(ErrorCode.INVALID_REQUEST)
            current_image_mode = (
                bool(old_row["stud_access_img_pwd"]) if source_role == "student" else False
            )
            target_image_mode = (
                bool(access_settings.get("stud_access_img_pwd", current_image_mode))
                if source_role == "student"
                else False
            )
            if target_image_mode != current_image_mode and passwd_plain is None:
                db.rollback()
                return _error(ErrorCode.INVALID_REQUEST)
            if passwd_plain is not None and target_image_mode:
                passwd_plain = normalize_image_password(db, passwd_plain)
            if target_username != username and _username_exists(db, target_username):
                db.rollback()
                return _error(ErrorCode.USERNAME_TAKEN)

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

            if access_settings:
                assignments = ", ".join(f"{field} = :{field}" for field in access_settings)
                db.execute(
                    text(f"UPDATE Student SET {assignments} WHERE stud_usr = :username"),
                    {**access_settings, "username": target_username},
                )

            db.commit()
            return _ok(username=target_username, role=target_role)
        except ImagePasswordError:
            db.rollback()
            return _error(ErrorCode.INVALID_REQUEST)
        except ValueError:
            db.rollback()
            return _error(ErrorCode.INVALID_ROLE)
        except IntegrityError as exc:
            db.rollback()
            return _error(_integrity_error_code(exc, ErrorCode.USER_UPDATE_FAILED))
        except Exception:
            db.rollback()
            return _error(ErrorCode.USER_UPDATE_FAILED)

    def updateAvatar(self, db: Session, username: str, image: bytes) -> dict:
        """Reemplaza la imagen de perfil vinculada a la cuenta común."""
        try:
            user = db.execute(
                text(
                    "SELECT avatar_id_fk FROM users "
                    "WHERE username = :username FOR UPDATE"
                ),
                {"username": username},
            ).mappings().first()
            if user is None:
                db.rollback()
                return _error(ErrorCode.USER_NOT_FOUND)

            avatar_id = db.execute(
                text(
                    "INSERT INTO Avatar (avatar_alt, avatar_bin) "
                    "VALUES (:avatar_alt, :avatar_bin) RETURNING avatar_id"
                ),
                {"avatar_alt": "Foto de perfil", "avatar_bin": image},
            ).scalar_one()
            db.execute(
                text("UPDATE users SET avatar_id_fk = :avatar_id WHERE username = :username"),
                {"avatar_id": avatar_id, "username": username},
            )
            old_avatar_id = user["avatar_id_fk"]
            if old_avatar_id is not None:
                db.execute(
                    text(
                        "DELETE FROM Avatar a WHERE a.avatar_id = :avatar_id "
                        "AND NOT EXISTS (SELECT 1 FROM users u "
                        "WHERE u.avatar_id_fk = a.avatar_id)"
                    ),
                    {"avatar_id": old_avatar_id},
                )
            db.commit()
            return _ok(avatar_id=avatar_id)
        except Exception:
            db.rollback()
            return _error(ErrorCode.AVATAR_UPDATE_FAILED)

    def getAvatar(self, db: Session, username: str) -> dict:
        """Obtiene la imagen de perfil de una cuenta."""
        try:
            row = db.execute(
                text(
                    "SELECT u.avatar_id_fk AS avatar_id, a.avatar_bin "
                    "FROM users u LEFT JOIN Avatar a ON a.avatar_id = u.avatar_id_fk "
                    "WHERE u.username = :username"
                ),
                {"username": username},
            ).mappings().first()
            if row is None:
                return _error(ErrorCode.USER_NOT_FOUND)
            image = row["avatar_bin"]
            return _ok(
                avatar_id=row["avatar_id"],
                avatar_bin=bytes(image) if image is not None else None,
            )
        except Exception:
            return _error(ErrorCode.USER_LOOKUP_FAILED)

    def staffCanViewStudentAvatar(self, db: Session, staff_username: str, student_username: str) -> bool:
        """Comprueba que el miembro del personal comparte una clase con el alumno."""
        return db.execute(
            text(
                "SELECT 1 FROM class_staff teaching "
                "JOIN class_stud enrollment "
                "ON enrollment.class_name_fk = teaching.class_name_fk "
                "WHERE teaching.staff_usr_fk = :staff_username "
                "AND enrollment.stud_usr_fk = :student_username"
            ),
            {"staff_username": staff_username, "student_username": student_username},
        ).scalar_one_or_none() is not None

    def studentCanViewStudentAvatar(self, db: Session, student_username: str, target_username: str) -> bool:
        """Permite al alumno ver a otros alumnos que comparten alguna de sus clases."""
        return db.execute(
            text(
                "SELECT 1 FROM class_stud AS viewer "
                "JOIN class_stud AS target "
                "ON target.class_name_fk = viewer.class_name_fk "
                "WHERE viewer.stud_usr_fk = :student_username "
                "AND target.stud_usr_fk = :target_username"
            ),
            {"student_username": student_username, "target_username": target_username},
        ).scalar_one_or_none() is not None

    def studentCanViewParentAvatar(self, db: Session, student_username: str, parent_username: str) -> bool:
        """Comprueba si el tutor está asociado al alumno que consulta la foto."""
        return db.execute(
            text(
                "SELECT 1 FROM par_stud "
                "WHERE stud_usr_fk = :student_username AND par_usr_fk = :parent_username"
            ),
            {"student_username": student_username, "parent_username": parent_username},
        ).scalar_one_or_none() is not None

    def studentCanViewStaffAvatar(self, db: Session, student_username: str, staff_username: str) -> bool:
        """Comprueba si el miembro del personal enseña en una clase del alumno."""
        return db.execute(
            text(
                "SELECT 1 FROM class_stud AS enrollment "
                "JOIN class_staff AS teaching "
                "ON teaching.class_name_fk = enrollment.class_name_fk "
                "WHERE enrollment.stud_usr_fk = :student_username "
                "AND teaching.staff_usr_fk = :staff_username"
            ),
            {"student_username": student_username, "staff_username": staff_username},
        ).scalar_one_or_none() is not None

    def parentCanViewStudentAvatar(self, db: Session, parent_username: str, student_username: str) -> bool:
        """Comprueba que el tutor o familiar está asociado al alumno."""
        return db.execute(
            text(
                "SELECT 1 FROM par_stud "
                "WHERE par_usr_fk = :parent_username AND stud_usr_fk = :student_username"
            ),
            {"parent_username": parent_username, "student_username": student_username},
        ).scalar_one_or_none() is not None

    def parentCanViewStaffAvatar(self, db: Session, parent_username: str, staff_username: str) -> bool:
        """Comprueba si el miembro del personal enseña a un alumno asociado al tutor."""
        return db.execute(
            text(
                "SELECT 1 FROM par_stud AS family "
                "JOIN class_stud AS enrollment "
                "ON enrollment.stud_usr_fk = family.stud_usr_fk "
                "JOIN class_staff AS teaching "
                "ON teaching.class_name_fk = enrollment.class_name_fk "
                "WHERE family.par_usr_fk = :parent_username "
                "AND teaching.staff_usr_fk = :staff_username"
            ),
            {"parent_username": parent_username, "staff_username": staff_username},
        ).scalar_one_or_none() is not None

    def studentIsInAnyClass(self, db: Session, student_username: str) -> bool:
        """Comprueba si el alumno forma parte del directorio visual previo al login."""
        return db.execute(
            text("SELECT 1 FROM class_stud WHERE stud_usr_fk = :student_username"),
            {"student_username": student_username},
        ).scalar_one_or_none() is not None

users_mng_db = UsersManagementDB()
