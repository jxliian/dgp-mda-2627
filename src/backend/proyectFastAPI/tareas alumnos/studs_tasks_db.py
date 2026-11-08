from datetime import date, time

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..errors import CatalogError, ErrorCode, success_response
from ..task_indexing import calculate_task_index, lock_student_agendas
from ..task_schedule import validate_task_schedule

SCHOOL_START = time(9, 0)
SCHOOL_END = time(15, 0)


def _has_student_relationship(
    db: Session, creator_role: str, creator_username: str, student_username: str
) -> bool:
    """Comprueba relación parent directa o relación staff por una clase compartida."""
    if creator_role == "parent":
        query = text(
            "SELECT 1 FROM par_stud "
            "WHERE par_usr_fk = :creator_username AND stud_usr_fk = :student_username"
        )
    elif creator_role == "staff":
        query = text(
            "SELECT 1 FROM class_staff teaching "
            "JOIN class_stud enrollment "
            "ON enrollment.class_name_fk = teaching.class_name_fk "
            "WHERE teaching.staff_usr_fk = :creator_username "
            "AND enrollment.stud_usr_fk = :student_username"
        )
    else:
        return False
    return db.execute(
        query,
        {"creator_username": creator_username, "student_username": student_username},
    ).scalar_one_or_none() is not None


def _assigned_student_relationship_sql(creator_role: str) -> str:
    """Devuelve la subconsulta que valida la relación con una tarea asignada."""
    if creator_role == "parent":
        return (
            "EXISTS (SELECT 1 FROM par_stud links "
            "WHERE links.par_usr_fk = :creator_username "
            "AND links.stud_usr_fk = assigned.stud_usr_fk)"
        )
    if creator_role == "staff":
        return (
            "EXISTS (SELECT 1 FROM class_stud enrollment "
            "JOIN class_staff teaching "
            "ON teaching.class_name_fk = enrollment.class_name_fk "
            "WHERE enrollment.stud_usr_fk = assigned.stud_usr_fk "
            "AND teaching.staff_usr_fk = :creator_username)"
        )
    raise CatalogError(ErrorCode.TASK_CREATOR_REQUIRED)


def create_task(
    db: Session,
    creator_role: str,
    creator_username: str,
    student_username: str,
    task_title: str,
    task_date: date,
    task_start_hour: time | None,
    task_duration: int,
    alt_task_id_fk: int | None,
) -> dict:
    """Crea una tarea asociada al usuario autorizado que la solicita."""
    if creator_role not in {"staff", "parent", "student"}:
        raise CatalogError(ErrorCode.TASK_CREATOR_REQUIRED)
    if creator_role == "student" and student_username != creator_username:
        raise CatalogError(ErrorCode.TASK_NOT_FOUND)
    validate_task_schedule(creator_role, task_start_hour, task_duration)

    if creator_role == "student":
        task_permission = db.execute(
            text(
                "SELECT stud_access_task_mod FROM Student "
                "WHERE stud_usr = :student_username FOR UPDATE"
            ),
            {"student_username": student_username},
        ).scalar_one_or_none()
        if task_permission is None:
            raise CatalogError(ErrorCode.TASK_STUDENT_NOT_FOUND)
        if task_permission is not True:
            raise CatalogError(ErrorCode.STUDENT_TASK_MODIFICATION_DENIED)
    else:
        student_exists = db.execute(
            text(
                "SELECT 1 FROM users AS account JOIN Student AS student_profile "
                "ON student_profile.stud_usr = account.username "
                "WHERE account.username = :student_username"
            ),
            {"student_username": student_username},
        ).scalar_one_or_none()
        if student_exists is None:
            raise CatalogError(ErrorCode.TASK_STUDENT_NOT_FOUND)

        if not _has_student_relationship(db, creator_role, creator_username, student_username):
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
        lock_student_agendas(db, [student_username])
        task_index = calculate_task_index(
            db, student_username, task_date, task_start_hour
        )
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
            text("INSERT INTO Generic_Task (task_id_fk) VALUES (:task_id)"),
            {"task_id": task["task_id"]},
        )
        db.execute(
            text(
                "INSERT INTO stud_task (stud_usr_fk, task_id_fk, task_index, task_date) "
                "VALUES (:student_username, :task_id, :task_index, :task_date)"
            ),
            {
                "task_id": task["task_id"],
                "student_username": student_username,
                "task_index": task_index,
                "task_date": task_date,
            },
        )
        db.commit()
        return success_response(
            **dict(task),
            stud_usr_fk=student_username,
            task_index=task_index,
            task_date=task_date,
        )
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
    if creator_role not in {"staff", "parent"}:
        raise CatalogError(ErrorCode.TASK_CREATOR_REQUIRED)

    assigned_student_relationship = _assigned_student_relationship_sql(creator_role)
    task_exists = db.execute(
        text(
            "SELECT 1 FROM Tasks task "
            "WHERE task.task_id = :task_id AND task.task_creator = :creator_username "
            "AND EXISTS ("
            "SELECT 1 FROM stud_task assigned "
            "WHERE assigned.task_id_fk = task.task_id AND "
            + assigned_student_relationship
            + ")"
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
    task_date: date,
) -> dict:
    """Retira una tarea de la agenda si el usuario puede gestionar al alumno y su horario."""
    if creator_role not in {"staff", "parent", "student"}:
        raise CatalogError(ErrorCode.TASK_CREATOR_REQUIRED)
    if creator_role == "student" and student_username != creator_username:
        raise CatalogError(ErrorCode.TASK_NOT_FOUND)

    if creator_role == "student":
        task_permission = db.execute(
            text(
                "SELECT stud_access_task_mod FROM Student "
                "WHERE stud_usr = :student_username FOR UPDATE"
            ),
            {"student_username": student_username},
        ).scalar_one_or_none()
        if task_permission is None:
            raise CatalogError(ErrorCode.TASK_STUDENT_NOT_FOUND)
        if task_permission is not True:
            raise CatalogError(ErrorCode.STUDENT_TASK_MODIFICATION_DENIED)
    else:
        student_exists = db.execute(
            text(
                "SELECT 1 FROM users AS account JOIN Student AS student_profile "
                "ON student_profile.stud_usr = account.username "
                "WHERE account.username = :student_username"
            ),
            {"student_username": student_username},
        ).scalar_one_or_none()
        if student_exists is None:
            raise CatalogError(ErrorCode.TASK_STUDENT_NOT_FOUND)

        if not _has_student_relationship(db, creator_role, creator_username, student_username):
            raise CatalogError(ErrorCode.TASK_STUDENT_NOT_ASSOCIATED)

    task = db.execute(
        text(
            "SELECT task.task_start_hour, task.task_duration, task.task_creator, assigned.task_index "
            "FROM Tasks task "
            "JOIN stud_task assigned ON assigned.task_id_fk = task.task_id "
            "WHERE task.task_id = :task_id AND assigned.stud_usr_fk = :student_username "
            "AND assigned.task_date = :task_date ORDER BY assigned.task_index LIMIT 1 "
            "FOR UPDATE OF assigned"
        ),
        {
            "task_id": task_id,
            "student_username": student_username,
            "task_date": task_date,
        },
    ).mappings().first()
    if task is None:
        raise CatalogError(ErrorCode.TASK_NOT_FOUND)
    task_index = task["task_index"]

    task_start_hour = task["task_start_hour"]
    if creator_role == "student":
        if task["task_creator"] != creator_username:
            raise CatalogError(ErrorCode.TASK_NOT_FOUND)
        validate_task_schedule("student", task_start_hour, task["task_duration"])
    elif task_start_hour is not None:
        during_school_hours = SCHOOL_START <= task_start_hour < SCHOOL_END
        if creator_role == "parent" and during_school_hours:
            raise CatalogError(ErrorCode.PARENT_DELETE_DURING_SCHOOL_HOURS)
        if creator_role == "staff" and not during_school_hours:
            raise CatalogError(ErrorCode.STAFF_DELETE_OUTSIDE_SCHOOL_HOURS)

    result = db.execute(
        text(
            "DELETE FROM stud_task "
            "WHERE task_id_fk = :task_id AND stud_usr_fk = :student_username "
            "AND task_date = :task_date AND task_index = :task_index"
        ),
        {
            "task_id": task_id,
            "student_username": student_username,
            "task_date": task_date,
            "task_index": task_index,
        },
    )
    if not result.rowcount:
        db.rollback()
        raise CatalogError(ErrorCode.TASK_NOT_FOUND)

    if creator_role == "student":
        db.execute(
            text(
                "DELETE FROM Tasks WHERE task_id = :task_id AND task_creator = :creator_username "
                "AND NOT EXISTS (SELECT 1 FROM stud_task WHERE task_id_fk = :task_id)"
            ),
            {"task_id": task_id, "creator_username": creator_username},
        )

    db.commit()
    return success_response(
        task_id=task_id,
        stud_usr_fk=student_username,
        task_date=task_date,
        task_index=task_index,
    )
