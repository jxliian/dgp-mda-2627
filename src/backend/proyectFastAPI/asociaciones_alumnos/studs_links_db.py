from typing import Literal

from sqlalchemy import text
from sqlalchemy.orm import Session

from ..errors import CatalogError, ErrorCode, success_response

# Los tutores se asocian directamente; el personal se deriva de la clase compartida.
PARENT_CONFIG = {
    "table": "par_stud",
    "user_fk": "par_usr_fk",
    "profile_table": "Parents",
    "user_username": "par_usr",
    "user_email": "par_email",
}
ROLE_CONFIG = {
    "parent": PARENT_CONFIG,
    "staff": {
        "profile_table": "Staff",
        "user_username": "staff_usr",
        "user_email": "staff_email",
    },
}


def _config(user_role: str) -> dict:
    """Obtiene tablas de perfil para los roles que pueden asociarse a estudiantes."""
    try:
        return ROLE_CONFIG[user_role]
    except KeyError as exc:
        raise CatalogError(ErrorCode.INVALID_ASSOCIATION_TYPE) from exc


def _ensure_user_exists(db: Session, role: Literal["student", "parent", "staff"], username: str) -> None:
    """Comprueba que existe la cuenta común y su fila en la tabla hija del rol."""
    if role == "student":
        profile_table, profile_username = "Student", "stud_usr"
    else:
        cfg = _config(role)
        profile_table, profile_username = cfg["profile_table"], cfg["user_username"]

    exists = db.execute(
        text(
            f"SELECT 1 FROM users AS account JOIN {profile_table} AS profile "
            f"ON profile.{profile_username} = account.username "
            "WHERE account.username = :username"
        ),
        {"username": username},
    ).scalar_one_or_none()
    if exists is None:
        raise CatalogError(ErrorCode.ASSOCIATED_ENTITY_NOT_FOUND)


def link_user(db: Session, role: Literal["parent"], student_username: str, username: str) -> dict:
    """Crea la asociación directa entre un alumno y su tutor."""
    if role != "parent":
        raise CatalogError(ErrorCode.INVALID_ASSOCIATION_TYPE)
    cfg = PARENT_CONFIG
    _ensure_user_exists(db, "student", student_username)
    _ensure_user_exists(db, role, username)

    result = db.execute(
        text(
            f"INSERT INTO {cfg['table']} ({cfg['user_fk']}, stud_usr_fk) "
            "VALUES (:username, :student_username) "
            f"ON CONFLICT ({cfg['user_fk']}, stud_usr_fk) DO NOTHING"
        ),
        {"username": username, "student_username": student_username},
    )
    db.commit()
    return success_response(
        association_created=bool(result.rowcount),
        student_username=student_username,
        **{f"{role}_username": username},
        relation="tutor",
    )


def unlink_user(db: Session, role: Literal["parent"], student_username: str, username: str) -> dict:
    """Elimina la asociación directa entre un alumno y su tutor."""
    if role != "parent":
        raise CatalogError(ErrorCode.INVALID_ASSOCIATION_TYPE)
    cfg = PARENT_CONFIG
    result = db.execute(
        text(
            f"DELETE FROM {cfg['table']} WHERE {cfg['user_fk']} = :username "
            "AND stud_usr_fk = :student_username"
        ),
        {"username": username, "student_username": student_username},
    )
    if not result.rowcount:
        db.rollback()
        raise CatalogError(ErrorCode.ASSOCIATION_NOT_FOUND)
    db.commit()
    return success_response(
        student_username=student_username,
        **{f"{role}_username": username},
    )


def get_associated_users(db: Session, role: Literal["parent", "staff"], student_username: str) -> list[dict]:
    """Lista tutores directos o personal que imparte la clase del alumno."""
    _config(role)
    _ensure_user_exists(db, "student", student_username)
    if role == "parent":
        query = text(
            "SELECT profile.par_usr AS username, account.full_name, profile.par_email AS email "
            "FROM par_stud links "
            "JOIN Parents profile ON profile.par_usr = links.par_usr_fk "
            "JOIN users account ON account.username = profile.par_usr "
            "WHERE links.stud_usr_fk = :student_username "
            "ORDER BY profile.par_usr"
        )
    else:
        query = text(
            "SELECT DISTINCT profile.staff_usr AS username, "
            "account.full_name, profile.staff_email AS email "
            "FROM class_stud enrollment "
            "JOIN class_staff teaching ON teaching.class_name_fk = enrollment.class_name_fk "
            "JOIN Staff profile ON profile.staff_usr = teaching.staff_usr_fk "
            "JOIN users account ON account.username = profile.staff_usr "
            "WHERE enrollment.stud_usr_fk = :student_username "
            "ORDER BY profile.staff_usr"
        )
    rows = db.execute(query, {"student_username": student_username}).mappings().all()
    return [dict(row) for row in rows]


def get_students(db: Session, role: Literal["parent", "staff"], username: str) -> list[dict]:
    """Lista alumnos del tutor o alumnos de las clases impartidas por el staff."""
    _ensure_user_exists(db, role, username)
    if role == "parent":
        query = text(
            "SELECT student_profile.stud_usr AS username, "
            "student_account.full_name "
            "FROM par_stud links "
            "JOIN Student AS student_profile "
            "ON student_profile.stud_usr = links.stud_usr_fk "
            "JOIN users AS student_account "
            "ON student_account.username = student_profile.stud_usr "
            "JOIN Parents AS parent_profile ON parent_profile.par_usr = links.par_usr_fk "
            "WHERE links.par_usr_fk = :username "
            "ORDER BY student_profile.stud_usr"
        )
    else:
        query = text(
            "SELECT DISTINCT student_profile.stud_usr AS username, "
            "student_account.full_name "
            "FROM class_staff teaching "
            "JOIN class_stud enrollment ON enrollment.class_name_fk = teaching.class_name_fk "
            "JOIN Student AS student_profile ON student_profile.stud_usr = enrollment.stud_usr_fk "
            "JOIN users AS student_account ON student_account.username = student_profile.stud_usr "
            "WHERE teaching.staff_usr_fk = :username "
            "ORDER BY student_profile.stud_usr"
        )
    rows = db.execute(query, {"username": username}).mappings().all()
    return [dict(row) for row in rows]
