from typing import Literal

from sqlalchemy import text
from sqlalchemy.orm import Session

from ..errors import CatalogError, ErrorCode, success_response

# Entidades y tablas de asociación del modelo: Parent <-> Student y Staff <-> Student.
LINK_CONFIG = {
    "parent": {
        "table": "par_stud",
        "user_fk": "par_usr_fk",
        "profile_table": "Parents",
        "user_username": "par_usr",
        "user_email": "par_email",
        "user_role": "parent",
    },
    "staff": {
        "table": "staff_stud",
        "user_fk": "staff_usr_fk",
        "profile_table": "Staff",
        "user_username": "staff_usr",
        "user_email": "staff_email",
        "user_role": "staff",
    },
}


def _config(user_role: str) -> dict:
    """Obtiene la configuración de tablas y columnas para el rol asociado."""
    try:
        return LINK_CONFIG[user_role]
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


def link_user(db: Session, role: Literal["parent", "staff"], student_username: str, username: str) -> dict:
    """Crea la asociación entre un alumno y un tutor o miembro del staff."""
    cfg = _config(role)
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
    relation = "tutor" if role == "parent" else "profesor"
    return success_response(
        association_created=bool(result.rowcount),
        student_username=student_username,
        **{f"{role}_username": username},
        relation=relation,
    )


def unlink_user(db: Session, role: Literal["parent", "staff"], student_username: str, username: str) -> dict:
    """Elimina la asociación entre un alumno y un tutor o miembro del staff."""
    cfg = _config(role)
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
    """Lista los tutores o miembros del staff asociados a un alumno."""
    cfg = _config(role)
    _ensure_user_exists(db, "student", student_username)
    rows = db.execute(
        text(
            f"SELECT profile.{cfg['user_username']} AS username, "
            "account.full_name, "
            f"profile.{cfg['user_email']} AS email "
            f"FROM {cfg['table']} links "
            f"JOIN {cfg['profile_table']} AS profile "
            f"ON profile.{cfg['user_username']} = links.{cfg['user_fk']} "
            f"JOIN users AS account ON account.username = profile.{cfg['user_username']} "
            "WHERE links.stud_usr_fk = :student_username "
            f"ORDER BY profile.{cfg['user_username']}"
        ),
        {"student_username": student_username},
    ).mappings().all()
    return [dict(row) for row in rows]


def get_students(db: Session, role: Literal["parent", "staff"], username: str) -> list[dict]:
    """Lista los alumnos asociados al tutor o miembro del staff indicado."""
    cfg = _config(role)
    _ensure_user_exists(db, role, username)
    rows = db.execute(
        text(
            "SELECT student_profile.stud_usr AS username, "
            "student_account.full_name "
            f"FROM {cfg['table']} links "
            "JOIN Student AS student_profile "
            "ON student_profile.stud_usr = links.stud_usr_fk "
            "JOIN users AS student_account "
            "ON student_account.username = student_profile.stud_usr "
            f"JOIN {cfg['profile_table']} AS related_profile "
            f"ON related_profile.{cfg['user_username']} = links.{cfg['user_fk']} "
            f"JOIN users AS related_account "
            f"ON related_account.username = related_profile.{cfg['user_username']} "
            f"WHERE links.{cfg['user_fk']} = :username "
            "ORDER BY student_profile.stud_usr"
        ),
        {"username": username},
    ).mappings().all()
    return [dict(row) for row in rows]
