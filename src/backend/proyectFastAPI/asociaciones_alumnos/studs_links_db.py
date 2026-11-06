from typing import Literal

from sqlalchemy import text
from sqlalchemy.orm import Session

# Entidades y tablas de asociación del modelo: Parent <-> Student y Staff <-> Student.
LINK_CONFIG = {
    "parent": {
        "table": "par_stud",
        "user_fk": "par_usr_fk",
        "user_table": "Parents",
        "user_username": "par_usr",
        "user_full_name": "par_full_name",
        "user_email": "par_email",
        "user_role": "parent",
    },
    "staff": {
        "table": "staff_stud",
        "user_fk": "staff_usr_fk",
        "user_table": "Staff",
        "user_username": "staff_usr",
        "user_full_name": "staff_full_name",
        "user_email": "staff_email",
        "user_role": "staff",
    },
}


def _config(user_role: str) -> dict:
    """Obtiene la configuración de tablas y columnas para el rol asociado."""
    try:
        return LINK_CONFIG[user_role]
    except KeyError as exc:
        raise ValueError("Tipo de usuario asociado desconocido") from exc


def _ensure_user_exists(db: Session, role: Literal["student", "parent", "staff"], username: str) -> None:
    """Comprueba que existe una cuenta con el rol y nombre de usuario indicados."""
    if role == "student":
        table, username_column = "Student", "stud_usr"
    else:
        cfg = _config(role)
        table, username_column = cfg["user_table"], cfg["user_username"]

    exists = db.execute(
        text(f"SELECT 1 FROM {table} WHERE {username_column} = :username"),
        {"username": username},
    ).scalar_one_or_none()
    if exists is None:
        label = {"student": "Alumno", "parent": "Tutor", "staff": "Profesor"}[role]
        raise LookupError(f"{label} no encontrado")


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
    return {
        "errorCode": 0,
        "errorMsg": "Asociación creada" if result.rowcount else "La asociación ya existía",
        "student_username": student_username,
        f"{role}_username": username,
        "relation": relation,
    }


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
        raise LookupError("La asociación no existe")
    db.commit()
    return {
        "errorCode": 0,
        "errorMsg": "Asociación eliminada",
        "student_username": student_username,
        f"{role}_username": username,
    }


def get_associated_users(db: Session, role: Literal["parent", "staff"], student_username: str) -> list[dict]:
    """Lista los tutores o miembros del staff asociados a un alumno."""
    cfg = _config(role)
    _ensure_user_exists(db, "student", student_username)
    rows = db.execute(
        text(
            f"SELECT users.{cfg['user_username']} AS username, "
            f"users.{cfg['user_full_name']} AS full_name, "
            f"users.{cfg['user_email']} AS email "
            f"FROM {cfg['table']} links "
            f"JOIN {cfg['user_table']} users ON users.{cfg['user_username']} = links.{cfg['user_fk']} "
            "WHERE links.stud_usr_fk = :student_username "
            f"ORDER BY users.{cfg['user_username']}"
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
            "SELECT students.stud_usr AS username, students.stud_full_name AS full_name "
            f"FROM {cfg['table']} links "
            "JOIN Student students ON students.stud_usr = links.stud_usr_fk "
            f"WHERE links.{cfg['user_fk']} = :username "
            "ORDER BY students.stud_usr"
        ),
        {"username": username},
    ).mappings().all()
    return [dict(row) for row in rows]
