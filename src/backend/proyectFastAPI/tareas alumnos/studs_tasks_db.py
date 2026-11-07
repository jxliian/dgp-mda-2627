from datetime import time

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session


def create_task(
    db: Session,
    staff_username: str,
    student_username: str,
    task_title: str,
    task_start_hour: time | None,
    task_duration: int | None,
    alt_task_id_fk: int | None,
) -> dict:
    """Crea una tarea únicamente si el alumno está asociado al miembro del staff."""
    student_exists = db.execute(
        text("SELECT 1 FROM Student WHERE stud_usr = :student_username"),
        {"student_username": student_username},
    ).scalar_one_or_none()
    if student_exists is None:
        raise LookupError("Alumno no encontrado")

    is_associated = db.execute(
        text(
            "SELECT 1 FROM staff_stud "
            "WHERE staff_usr_fk = :staff_username AND stud_usr_fk = :student_username"
        ),
        {"staff_username": staff_username, "student_username": student_username},
    ).scalar_one_or_none()
    if is_associated is None:
        raise PermissionError("El alumno no está asociado a tu cuenta")

    if alt_task_id_fk is not None:
        alt_task_exists = db.execute(
            text("SELECT 1 FROM Alt_Tasks WHERE alt_task_id = :alt_task_id_fk"),
            {"alt_task_id_fk": alt_task_id_fk},
        ).scalar_one_or_none()
        if alt_task_exists is None:
            raise LookupError("La tarea alternativa no existe")
        alt_task_assigned = db.execute(
            text("SELECT 1 FROM Tasks WHERE alt_task_id_fk = :alt_task_id_fk"),
            {"alt_task_id_fk": alt_task_id_fk},
        ).scalar_one_or_none()
        if alt_task_assigned is not None:
            raise ValueError("La tarea alternativa ya está asociada a otra tarea")

    try:
        task = db.execute(
            text(
                "INSERT INTO Tasks "
                "(task_title, task_start_hour, task_duration, task_creator, task_finished, alt_task_id_fk) "
                "VALUES (:task_title, :task_start_hour, :task_duration, :staff_username, FALSE, :alt_task_id_fk) "
                "RETURNING task_id, task_title, task_start_hour, task_duration, task_creator, "
                "task_finished, alt_task_id_fk"
            ),
            {
                "task_title": task_title,
                "task_start_hour": task_start_hour,
                "task_duration": task_duration,
                "staff_username": staff_username,
                "alt_task_id_fk": alt_task_id_fk,
            },
        ).mappings().one()
        db.execute(
            text("INSERT INTO studs_tasks (task_id_fk, stud_usr_fk) VALUES (:task_id, :student_username)"),
            {"task_id": task["task_id"], "student_username": student_username},
        )
        db.commit()
        return {
            "errorCode": 0,
            "errorMsg": "Tarea creada y asignada",
            **dict(task),
            "stud_usr_fk": student_username,
        }
    except Exception:
        db.rollback()
        raise


def set_alternative_task(
    db: Session,
    staff_username: str,
    task_id: int,
    alt_task_id_fk: int | None,
) -> dict:
    """Actualiza la tarea alternativa de una tarea principal creada por el staff."""
    task_exists = db.execute(
        text("SELECT 1 FROM Tasks WHERE task_id = :task_id AND task_creator = :staff_username"),
        {"task_id": task_id, "staff_username": staff_username},
    ).scalar_one_or_none()
    if task_exists is None:
        raise LookupError("Tarea no encontrada")

    if alt_task_id_fk is not None:
        alt_task_exists = db.execute(
            text("SELECT 1 FROM Alt_Tasks WHERE alt_task_id = :alt_task_id_fk"),
            {"alt_task_id_fk": alt_task_id_fk},
        ).scalar_one_or_none()
        if alt_task_exists is None:
            raise LookupError("La tarea alternativa no existe")

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
                raise ValueError("La tarea alternativa ya está asociada a otra tarea")

        result = db.execute(
            text(
                "UPDATE Tasks SET alt_task_id_fk = :alt_task_id_fk "
                "WHERE task_id = :task_id AND task_creator = :staff_username "
                "RETURNING task_id, task_title, task_start_hour, task_duration, task_creator, "
                "task_finished, alt_task_id_fk"
            ),
            {
                "alt_task_id_fk": alt_task_id_fk,
                "task_id": task_id,
                "staff_username": staff_username,
            },
        ).mappings().one()
        db.commit()
        return {"errorCode": 0, "errorMsg": "Tarea alternativa actualizada", **dict(result)}
    except IntegrityError as exc:
        db.rollback()
        constraint = getattr(getattr(exc.orig, "diag", None), "constraint_name", "") or ""
        if "alt_task_id_fk" in constraint:
            raise ValueError("La tarea alternativa ya está asociada a otra tarea") from exc
        raise
