from datetime import time

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..errors import CatalogError, ErrorCode, success_response

CREATOR_ASSOCIATIONS = {
    "staff": {"table": "staff_stud", "creator_fk": "staff_usr_fk"},
    "parent": {"table": "par_stud", "creator_fk": "par_usr_fk"},
}
SCHOOL_START = time(9, 0)
SCHOOL_END = time(15, 0)


def create_task(
    db: Session,
    creator_role: str,
    creator_username: str,
    student_username: str,
    task_title: str,
    task_start_hour: time | None,
    task_duration: int | None,
    alt_task_id_fk: int | None,
) -> dict:
    """Crea una tarea solo si el alumno está asociado al staff o tutor autenticado."""
    association = CREATOR_ASSOCIATIONS.get(creator_role)
    if association is None:
        raise CatalogError(ErrorCode.TASK_CREATOR_REQUIRED)

    if task_start_hour is not None:
        during_school_hours = SCHOOL_START <= task_start_hour < SCHOOL_END
        if creator_role == "staff" and not during_school_hours:
            raise CatalogError(ErrorCode.STAFF_TASK_OUTSIDE_SCHOOL_HOURS)
        if creator_role == "parent" and during_school_hours:
            raise CatalogError(ErrorCode.PARENT_TASK_DURING_SCHOOL_HOURS)

    student_exists = db.execute(
        text("SELECT 1 FROM Student WHERE stud_usr = :student_username"),
        {"student_username": student_username},
    ).scalar_one_or_none()
    if student_exists is None:
        raise CatalogError(ErrorCode.TASK_STUDENT_NOT_FOUND)

    is_associated = db.execute(
        text(
            f"SELECT 1 FROM {association['table']} "
            f"WHERE {association['creator_fk']} = :creator_username "
            "AND stud_usr_fk = :student_username"
        ),
        {"creator_username": creator_username, "student_username": student_username},
    ).scalar_one_or_none()
    if is_associated is None:
        raise CatalogError(ErrorCode.TASK_STUDENT_NOT_ASSOCIATED)

    if alt_task_id_fk is not None:
        alt_task_exists = db.execute(
            text("SELECT 1 FROM Alt_Tasks WHERE alt_task_id = :alt_task_id_fk"),
            {"alt_task_id_fk": alt_task_id_fk},
        ).scalar_one_or_none()
        if alt_task_exists is None:
            raise CatalogError(ErrorCode.ALTERNATIVE_TASK_NOT_FOUND)
        alt_task_assigned = db.execute(
            text("SELECT 1 FROM Tasks WHERE alt_task_id_fk = :alt_task_id_fk"),
            {"alt_task_id_fk": alt_task_id_fk},
        ).scalar_one_or_none()
        if alt_task_assigned is not None:
            raise CatalogError(ErrorCode.ALTERNATIVE_TASK_ALREADY_ASSIGNED)

    try:
        task = db.execute(
            text(
                "INSERT INTO Tasks "
                "(task_title, task_start_hour, task_duration, task_creator, task_finished, alt_task_id_fk) "
                "VALUES (:task_title, :task_start_hour, :task_duration, :creator_username, FALSE, :alt_task_id_fk) "
                "RETURNING task_id, task_title, task_start_hour, task_duration, task_creator, "
                "task_finished, alt_task_id_fk"
            ),
            {
                "task_title": task_title,
                "task_start_hour": task_start_hour,
                "task_duration": task_duration,
                "creator_username": creator_username,
                "alt_task_id_fk": alt_task_id_fk,
            },
        ).mappings().one()
        db.execute(
            text("INSERT INTO studs_tasks (task_id_fk, stud_usr_fk) VALUES (:task_id, :student_username)"),
            {"task_id": task["task_id"], "student_username": student_username},
        )
        db.commit()
        return success_response(**dict(task), stud_usr_fk=student_username)
    except IntegrityError as exc:
        db.rollback()
        constraint = getattr(getattr(exc.orig, "diag", None), "constraint_name", "") or ""
        if "alt_task_id_fk" in constraint:
            raise CatalogError(ErrorCode.ALTERNATIVE_TASK_ALREADY_ASSIGNED) from exc
        raise
    except Exception:
        db.rollback()
        raise


def set_alternative_task(
    db: Session,
    creator_role: str,
    creator_username: str,
    task_id: int,
    alt_task_id_fk: int | None,
) -> dict:
    """Actualiza la alternativa de una tarea principal creada por el staff o tutor."""
    association = CREATOR_ASSOCIATIONS.get(creator_role)
    if association is None:
        raise CatalogError(ErrorCode.TASK_CREATOR_REQUIRED)

    task_exists = db.execute(
        text(
            "SELECT 1 FROM Tasks task "
            "WHERE task.task_id = :task_id AND task.task_creator = :creator_username "
            "AND EXISTS ("
            "SELECT 1 FROM studs_tasks assigned "
            f"JOIN {association['table']} links "
            f"ON links.{association['creator_fk']} = :creator_username "
            "AND links.stud_usr_fk = assigned.stud_usr_fk "
            "WHERE assigned.task_id_fk = task.task_id"
            ")"
        ),
        {"task_id": task_id, "creator_username": creator_username},
    ).scalar_one_or_none()
    if task_exists is None:
        raise CatalogError(ErrorCode.TASK_NOT_FOUND)

    if alt_task_id_fk is not None:
        alt_task_exists = db.execute(
            text("SELECT 1 FROM Alt_Tasks WHERE alt_task_id = :alt_task_id_fk"),
            {"alt_task_id_fk": alt_task_id_fk},
        ).scalar_one_or_none()
        if alt_task_exists is None:
            raise CatalogError(ErrorCode.ALTERNATIVE_TASK_NOT_FOUND)

    try:
        if alt_task_id_fk is not None:
            alt_task_assigned = db.execute(
                text(
                    "SELECT 1 FROM Tasks "
                    "WHERE alt_task_id_fk = :alt_task_id_fk AND task_id <> :task_id"
                ),
                {"alt_task_id_fk": alt_task_id_fk, "task_id": task_id},
            ).scalar_one_or_none()
            if alt_task_assigned is not None:
                raise CatalogError(ErrorCode.ALTERNATIVE_TASK_ALREADY_ASSIGNED)

        result = db.execute(
            text(
                "UPDATE Tasks SET alt_task_id_fk = :alt_task_id_fk "
                "WHERE task_id = :task_id AND task_creator = :creator_username "
                "RETURNING task_id, task_title, task_start_hour, task_duration, task_creator, "
                "task_finished, alt_task_id_fk"
            ),
            {
                "alt_task_id_fk": alt_task_id_fk,
                "task_id": task_id,
                "creator_username": creator_username,
            },
        ).mappings().one()
        db.commit()
        return success_response(**dict(result))
    except IntegrityError as exc:
        db.rollback()
        constraint = getattr(getattr(exc.orig, "diag", None), "constraint_name", "") or ""
        if "alt_task_id_fk" in constraint:
            raise CatalogError(ErrorCode.ALTERNATIVE_TASK_ALREADY_ASSIGNED) from exc
        raise


def delete_student_task(
    db: Session,
    creator_role: str,
    creator_username: str,
    student_username: str,
    task_id: int,
) -> dict:
    """Retira una tarea de la agenda si el usuario puede gestionar al alumno y su horario."""
    association = CREATOR_ASSOCIATIONS.get(creator_role)
    if association is None:
        raise CatalogError(ErrorCode.TASK_CREATOR_REQUIRED)

    student_exists = db.execute(
        text("SELECT 1 FROM Student WHERE stud_usr = :student_username"),
        {"student_username": student_username},
    ).scalar_one_or_none()
    if student_exists is None:
        raise CatalogError(ErrorCode.TASK_STUDENT_NOT_FOUND)

    student_is_associated = db.execute(
        text(
            f"SELECT 1 FROM {association['table']} "
            f"WHERE {association['creator_fk']} = :creator_username "
            "AND stud_usr_fk = :student_username"
        ),
        {"creator_username": creator_username, "student_username": student_username},
    ).scalar_one_or_none()
    if student_is_associated is None:
        raise CatalogError(ErrorCode.TASK_STUDENT_NOT_ASSOCIATED)

    task = db.execute(
        text(
            "SELECT task.task_start_hour "
            "FROM Tasks task "
            "JOIN studs_tasks assigned ON assigned.task_id_fk = task.task_id "
            "WHERE task.task_id = :task_id AND assigned.stud_usr_fk = :student_username"
        ),
        {"task_id": task_id, "student_username": student_username},
    ).mappings().first()
    if task is None:
        raise CatalogError(ErrorCode.TASK_NOT_FOUND)

    task_start_hour = task["task_start_hour"]
    if task_start_hour is not None:
        during_school_hours = SCHOOL_START <= task_start_hour < SCHOOL_END
        if creator_role == "parent" and during_school_hours:
            raise CatalogError(ErrorCode.PARENT_DELETE_DURING_SCHOOL_HOURS)
        if creator_role == "staff" and not during_school_hours:
            raise CatalogError(ErrorCode.STAFF_DELETE_OUTSIDE_SCHOOL_HOURS)

    result = db.execute(
        text(
            "DELETE FROM studs_tasks "
            "WHERE task_id_fk = :task_id AND stud_usr_fk = :student_username"
        ),
        {"task_id": task_id, "student_username": student_username},
    )
    if not result.rowcount:
        db.rollback()
        raise CatalogError(ErrorCode.TASK_NOT_FOUND)

    db.commit()
    return success_response(task_id=task_id, stud_usr_fk=student_username)
