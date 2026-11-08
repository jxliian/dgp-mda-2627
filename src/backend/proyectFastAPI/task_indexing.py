from datetime import date, time

from sqlalchemy import text
from sqlalchemy.orm import Session


def lock_student_agendas(db: Session, student_usernames: list[str]) -> None:
    """Bloquea las filas de alumnos en orden estable antes de calcular sus índices."""
    for username in sorted(student_usernames):
        db.execute(
            text("SELECT stud_usr FROM Student WHERE stud_usr = :username FOR UPDATE"),
            {"username": username},
        ).scalar_one()


def calculate_task_index(
    db: Session,
    student_username: str,
    task_date: date,
    task_start_hour: time | None,
) -> int:
    """Calcula e inserta una posición según la hora, o al final si no tiene hora."""
    assignments = db.execute(
        text(
            "SELECT assigned.task_index, task.task_start_hour "
            "FROM stud_task assigned JOIN Tasks task ON task.task_id = assigned.task_id_fk "
            "WHERE assigned.stud_usr_fk = :student_username "
            "AND assigned.task_date = :task_date "
            "ORDER BY assigned.task_index, task.task_id"
        ),
        {"student_username": student_username, "task_date": task_date},
    ).mappings().all()

    maximum_index = max((row["task_index"] for row in assignments), default=-1)
    insertion_index = maximum_index + 1
    if task_start_hour is not None:
        for row in assignments:
            existing_hour = row["task_start_hour"]
            if existing_hour is None or existing_hour > task_start_hour:
                insertion_index = row["task_index"]
                break
    db.execute(
        text(
            "UPDATE stud_task SET task_index = task_index + 1 "
            "WHERE stud_usr_fk = :student_username AND task_date = :task_date "
            "AND task_index >= :insertion_index"
        ),
        {
            "student_username": student_username,
            "task_date": task_date,
            "insertion_index": insertion_index,
        },
    )
    return insertion_index
