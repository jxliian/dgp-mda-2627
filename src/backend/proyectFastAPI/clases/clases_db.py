from datetime import date, time
from urllib.parse import quote

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..errors import CatalogError, ErrorCode, success_response
from ..task_indexing import calculate_task_index, lock_student_agendas
from ..task_schedule import validate_task_schedule

def _ensure_class(db: Session, class_name: str) -> dict:
    """Comprueba que exista la clase y devuelve su nombre."""
    row = db.execute(
        text("SELECT class_name FROM Class WHERE class_name = :class_name"),
        {"class_name": class_name},
    ).mappings().first()
    if row is None:
        raise CatalogError(ErrorCode.CLASS_NOT_FOUND)
    return dict(row)


def _ensure_staff_class(db: Session, class_name: str, staff_username: str) -> dict:
    """Comprueba que el personal indicado esté asignado a la clase."""
    class_info = _ensure_class(db, class_name)
    assigned = db.execute(
        text(
            "SELECT 1 FROM class_staff "
            "WHERE class_name_fk = :class_name AND staff_usr_fk = :staff_username"
        ),
        {"class_name": class_name, "staff_username": staff_username},
    ).scalar_one_or_none()
    if assigned is None:
        raise CatalogError(ErrorCode.CLASS_ACCESS_DENIED)
    return class_info


def _lock_class(db: Session, class_name: str) -> None:
    """Serializa cambios de matrícula, tarea y eliminación para la misma clase."""
    exists = db.execute(
        text("SELECT class_name FROM Class WHERE class_name = :class_name FOR UPDATE"),
        {"class_name": class_name},
    ).scalar_one_or_none()
    if exists is None:
        raise CatalogError(ErrorCode.CLASS_NOT_FOUND)


def create_class(db: Session, class_name: str) -> dict:
    """Crea una clase nueva y rechaza nombres que ya estén registrados."""
    try:
        row = db.execute(
            text(
                "INSERT INTO Class (class_name) VALUES (:class_name) "
                "ON CONFLICT (class_name) DO NOTHING RETURNING class_name"
            ),
            {"class_name": class_name},
        ).mappings().first()
        if row is None:
            db.rollback()
            raise CatalogError(ErrorCode.CLASS_NAME_TAKEN)
        db.commit()
        return success_response(**dict(row))
    except Exception:
        db.rollback()
        raise


def update_class(db: Session, current_class_name: str, new_class_name: str) -> dict:
    """Renombra la clase y conserva sus asociaciones mediante la clave foránea."""
    _ensure_class(db, current_class_name)
    try:
        row = db.execute(
            text(
                "UPDATE Class SET class_name = :new_class_name "
                "WHERE class_name = :current_class_name RETURNING class_name"
            ),
            {"current_class_name": current_class_name, "new_class_name": new_class_name},
        ).mappings().first()
        db.commit()
        return success_response(**dict(row))
    except IntegrityError as exc:
        db.rollback()
        raise CatalogError(ErrorCode.CLASS_NAME_TAKEN) from exc
    except Exception:
        db.rollback()
        raise


def delete_class(db: Session, class_name: str) -> dict:
    """Elimina la clase, sus asignaciones grupales y tareas grupales huérfanas."""
    _ensure_class(db, class_name)
    _lock_class(db, class_name)
    task_ids = db.execute(
        text("SELECT task_id_fk FROM class_task WHERE class_name_fk = :class_name"),
        {"class_name": class_name},
    ).scalars().all()
    try:
        row = db.execute(
            text("DELETE FROM Class WHERE class_name = :class_name RETURNING class_name"),
            {"class_name": class_name},
        ).mappings().one()
        for task_id in task_ids:
            db.execute(
                text(
                    "DELETE FROM Tasks task WHERE task.task_id = :task_id "
                    "AND NOT EXISTS (SELECT 1 FROM stud_task assigned "
                    "WHERE assigned.task_id_fk = task.task_id) "
                    "AND NOT EXISTS (SELECT 1 FROM class_task linked "
                    "WHERE linked.task_id_fk = task.task_id)"
                ),
                {"task_id": task_id},
            )
        db.commit()
        return success_response(**dict(row))
    except Exception:
        db.rollback()
        raise


def add_staff(db: Session, class_name: str, staff_username: str) -> dict:
    """Asigna a un miembro del personal existente a la clase."""
    _ensure_class(db, class_name)
    exists = db.execute(
        text(
            "SELECT 1 FROM users account JOIN Staff profile "
            "ON profile.staff_usr = account.username WHERE account.username = :username"
        ),
        {"username": staff_username},
    ).scalar_one_or_none()
    if exists is None:
        raise CatalogError(ErrorCode.CLASS_STAFF_NOT_FOUND)
    db.execute(
        text(
            "INSERT INTO class_staff (class_name_fk, staff_usr_fk) "
            "VALUES (:class_name, :staff_username) "
            "ON CONFLICT (class_name_fk, staff_usr_fk) DO NOTHING"
        ),
        {"class_name": class_name, "staff_username": staff_username},
    )
    db.commit()
    return success_response(class_name=class_name, staff_username=staff_username)


def remove_staff(db: Session, class_name: str, staff_username: str) -> dict:
    """Retira de una clase a un miembro del personal asignado."""
    _ensure_class(db, class_name)
    _lock_class(db, class_name)
    try:
        row = db.execute(
            text(
                "DELETE FROM class_staff "
                "WHERE class_name_fk = :class_name AND staff_usr_fk = :staff_username "
                "RETURNING class_name_fk, staff_usr_fk"
            ),
            {"class_name": class_name, "staff_username": staff_username},
        ).mappings().first()
        if row is None:
            raise CatalogError(ErrorCode.CLASS_STAFF_NOT_FOUND)
        db.commit()
        return success_response(class_name=row["class_name_fk"], staff_username=row["staff_usr_fk"])
    except Exception:
        db.rollback()
        raise


def _list_class_students(db: Session, class_name: str) -> list[dict]:
    """Devuelve los alumnos actuales de una clase con una URL de avatar."""
    rows = db.execute(
        text(
            "SELECT s.stud_usr AS username, u.full_name "
            "FROM class_stud cs JOIN Student s ON s.stud_usr = cs.stud_usr_fk "
            "JOIN users u ON u.username = s.stud_usr "
            "WHERE cs.class_name_fk = :class_name ORDER BY s.stud_usr"
        ),
        {"class_name": class_name},
    ).mappings().all()
    return [
        {
            **dict(row),
            "avatar_url": f"/users/students/{quote(row['username'], safe='')}/avatar-image",
        }
        for row in rows
    ]


def list_classes(db: Session, staff_username: str | None = None) -> list[dict]:
    """Lista todas las clases para admin o las asignadas al miembro de staff indicado."""
    if staff_username is None:
        rows = db.execute(text("SELECT class_name FROM Class ORDER BY class_name")).mappings().all()
    else:
        rows = db.execute(
            text(
                "SELECT c.class_name FROM Class c JOIN class_staff teacher "
                "ON teacher.class_name_fk = c.class_name "
                "WHERE teacher.staff_usr_fk = :staff_username ORDER BY c.class_name"
            ),
            {"staff_username": staff_username},
        ).mappings().all()
    classes = []
    for row in rows:
        students = _list_class_students(db, row["class_name"])
        classes.append(
            {
                "class_name": row["class_name"],
                "student_count": len(students),
                "students": students,
            }
        )
    return classes


def list_class_names(db: Session) -> list[dict]:
    """Lista solo los nombres de las clases para selección previa al login."""
    rows = db.execute(
        text("SELECT class_name FROM Class ORDER BY class_name")
    ).mappings().all()
    return [dict(row) for row in rows]


def get_class(db: Session, class_name: str, staff_username: str | None = None) -> dict:
    """Devuelve el detalle de una clase; limita el acceso del staff a sus clases."""
    class_info = (
        _ensure_staff_class(db, class_name, staff_username)
        if staff_username is not None
        else _ensure_class(db, class_name)
    )
    students = _list_class_students(db, class_name)
    return success_response(**class_info, students=students)


def add_student(db: Session, class_name: str, staff_username: str, student_username: str) -> dict:
    """Inscribe al alumno y le asigna las tareas grupales vigentes de la clase."""
    _ensure_staff_class(db, class_name, staff_username)
    _lock_class(db, class_name)
    try:
        student = db.execute(
            text(
                "SELECT s.stud_usr FROM users u JOIN Student s ON s.stud_usr = u.username "
                "WHERE u.username = :student_username FOR UPDATE OF s"
            ),
            {"student_username": student_username},
        ).scalar_one_or_none()
        if student is None:
            raise CatalogError(ErrorCode.TASK_STUDENT_NOT_FOUND)
        current_class_name = db.execute(
            text("SELECT class_name_fk FROM class_stud WHERE stud_usr_fk = :student_username"),
            {"student_username": student_username},
        ).scalar_one_or_none()
        if current_class_name is not None and current_class_name != class_name:
            raise CatalogError(ErrorCode.STUDENT_ALREADY_IN_CLASS)
        enrolled = db.execute(
            text(
                "INSERT INTO class_stud (class_name_fk, stud_usr_fk) "
                "VALUES (:class_name, :student_username) ON CONFLICT (stud_usr_fk) DO NOTHING "
                "RETURNING stud_usr_fk"
            ),
            {"class_name": class_name, "student_username": student_username},
        ).scalar_one_or_none()
        assigned_tasks = 0
        if enrolled is not None:
            class_tasks = db.execute(
                text(
                    "SELECT linked.task_id_fk, linked.task_date, task.task_start_hour "
                    "FROM class_task linked JOIN Tasks task ON task.task_id = linked.task_id_fk "
                    "WHERE linked.class_name_fk = :class_name "
                    "ORDER BY linked.task_date, task.task_start_hour NULLS LAST, linked.task_id_fk"
                ),
                {"class_name": class_name},
            ).mappings().all()
            for class_task in class_tasks:
                task_index = calculate_task_index(
                    db,
                    student_username,
                    class_task["task_date"],
                    class_task["task_start_hour"],
                )
                db.execute(
                    text(
                        "INSERT INTO stud_task "
                        "(stud_usr_fk, task_id_fk, task_index, task_date, class_name_fk) "
                        "VALUES (:student_username, :task_id, :task_index, :task_date, :class_name)"
                    ),
                    {
                        "student_username": student_username,
                        "task_id": class_task["task_id_fk"],
                        "task_index": task_index,
                        "task_date": class_task["task_date"],
                        "class_name": class_name,
                    },
                )
                assigned_tasks += 1
        db.commit()
        return success_response(
            class_name=class_name,
            student_username=student_username,
            class_tasks_assigned=assigned_tasks,
        )
    except Exception:
        db.rollback()
        raise


def remove_student(db: Session, class_name: str, staff_username: str, student_username: str) -> dict:
    """Retira al alumno y solo las asignaciones procedentes de esta clase."""
    _ensure_staff_class(db, class_name, staff_username)
    _lock_class(db, class_name)
    try:
        db.execute(
            text("SELECT stud_usr FROM Student WHERE stud_usr = :student_username FOR UPDATE"),
            {"student_username": student_username},
        ).scalar_one_or_none()
        result = db.execute(
            text(
                "DELETE FROM stud_task WHERE stud_usr_fk = :student_username "
                "AND class_name_fk = :class_name"
            ),
            {"class_name": class_name, "student_username": student_username},
        )
        removed_task_assignments = result.rowcount
        enrollment = db.execute(
            text(
                "DELETE FROM class_stud WHERE class_name_fk = :class_name "
                "AND stud_usr_fk = :student_username"
            ),
            {"class_name": class_name, "student_username": student_username},
        )
        if not enrollment.rowcount:
            db.rollback()
            raise CatalogError(ErrorCode.ASSOCIATION_NOT_FOUND)
        db.commit()
        return success_response(
            class_name=class_name,
            student_username=student_username,
            class_task_assignments_removed=removed_task_assignments,
        )
    except Exception:
        db.rollback()
        raise


def list_class_tasks(db: Session, class_name: str, staff_username: str) -> dict:
    """Lista las tareas asignadas a la clase y sus alumnos con asignación vigente."""
    _ensure_staff_class(db, class_name, staff_username)
    rows = db.execute(
        text(
            "SELECT task.task_id, task.task_title, task.task_start_hour, task.task_duration, "
            "task.task_creator, task.task_finished, task.alt_task_id_fk, linked.task_date, "
            "COALESCE(array_agg(assigned.stud_usr_fk ORDER BY assigned.stud_usr_fk) "
            "FILTER (WHERE assigned.stud_usr_fk IS NOT NULL), ARRAY[]::varchar[]) AS students "
            "FROM class_task linked JOIN Tasks task ON task.task_id = linked.task_id_fk "
            "LEFT JOIN stud_task assigned ON assigned.task_id_fk = linked.task_id_fk "
            "AND assigned.class_name_fk = linked.class_name_fk "
            "WHERE linked.class_name_fk = :class_name "
            "GROUP BY task.task_id, linked.task_date ORDER BY linked.task_date, task.task_start_hour NULLS LAST, task.task_id"
        ),
        {"class_name": class_name},
    ).mappings().all()
    return success_response(class_name=class_name, tasks=[dict(row) for row in rows])


def update_class_task(
    db: Session,
    class_name: str,
    staff_username: str,
    task_id: int,
    task_title: str,
    task_date: date,
    task_start_hour: time,
    task_duration: int,
    alt_task_id_fk: int | None,
) -> dict:
    """Actualiza una tarea grupal y vuelve a asignarla a la matrícula actual."""
    _ensure_staff_class(db, class_name, staff_username)
    _lock_class(db, class_name)
    linked = db.execute(
        text(
            "SELECT task_id_fk FROM class_task "
            "WHERE class_name_fk = :class_name AND task_id_fk = :task_id"
        ),
        {"class_name": class_name, "task_id": task_id},
    ).scalar_one_or_none()
    if linked is None:
        raise CatalogError(ErrorCode.TASK_NOT_FOUND)
    validate_task_schedule("staff", task_start_hour, task_duration)

    if alt_task_id_fk is not None:
        alternative_exists = db.execute(
            text("SELECT 1 FROM Alt_Tasks WHERE alt_task_id = :alt_task_id"),
            {"alt_task_id": alt_task_id_fk},
        ).scalar_one_or_none()
        if alternative_exists is None:
            raise CatalogError(ErrorCode.ALTERNATIVE_TASK_NOT_FOUND)
        alternative_used = db.execute(
            text(
                "SELECT 1 FROM Tasks WHERE alt_task_id_fk = :alt_task_id "
                "AND task_id <> :task_id"
            ),
            {"alt_task_id": alt_task_id_fk, "task_id": task_id},
        ).scalar_one_or_none()
        if alternative_used is not None:
            raise CatalogError(ErrorCode.ALTERNATIVE_TASK_ALREADY_ASSIGNED)

    students = db.execute(
        text("SELECT stud_usr_fk FROM class_stud WHERE class_name_fk = :class_name ORDER BY stud_usr_fk"),
        {"class_name": class_name},
    ).scalars().all()
    try:
        lock_student_agendas(db, students)
        db.execute(
            text(
                "DELETE FROM stud_task WHERE task_id_fk = :task_id "
                "AND class_name_fk = :class_name"
            ),
            {"task_id": task_id, "class_name": class_name},
        )
        task = db.execute(
            text(
                "UPDATE Tasks SET task_title = :task_title, task_start_hour = :task_start_hour, "
                "task_duration = :task_duration, alt_task_id_fk = :alt_task_id_fk "
                "WHERE task_id = :task_id RETURNING task_id, task_title, task_start_hour, "
                "task_duration, task_creator, task_finished, alt_task_id_fk"
            ),
            {
                "task_id": task_id,
                "task_title": task_title,
                "task_start_hour": task_start_hour,
                "task_duration": task_duration,
                "alt_task_id_fk": alt_task_id_fk,
            },
        ).mappings().one()
        db.execute(
            text("UPDATE class_task SET task_date = :task_date WHERE task_id_fk = :task_id"),
            {"task_date": task_date, "task_id": task_id},
        )
        task_indexes = {}
        for username in students:
            index = calculate_task_index(db, username, task_date, task_start_hour)
            db.execute(
                text(
                    "INSERT INTO stud_task "
                    "(stud_usr_fk, task_id_fk, task_index, task_date, class_name_fk) "
                    "VALUES (:student_username, :task_id, :task_index, :task_date, :class_name)"
                ),
                {
                    "student_username": username,
                    "task_id": task_id,
                    "task_index": index,
                    "task_date": task_date,
                    "class_name": class_name,
                },
            )
            task_indexes[username] = index
        db.commit()
        return success_response(
            **dict(task),
            class_name=class_name,
            task_date=task_date,
            task_indexes=task_indexes,
        )
    except Exception:
        db.rollback()
        raise


def delete_class_task(db: Session, class_name: str, staff_username: str, task_id: int) -> dict:
    """Desasigna una tarea de la clase y conserva sus asignaciones individuales."""
    _ensure_staff_class(db, class_name, staff_username)
    _lock_class(db, class_name)
    try:
        exists = db.execute(
            text(
                "SELECT 1 FROM class_task WHERE class_name_fk = :class_name "
                "AND task_id_fk = :task_id"
            ),
            {"class_name": class_name, "task_id": task_id},
        ).scalar_one_or_none()
        if exists is None:
            db.rollback()
            raise CatalogError(ErrorCode.TASK_NOT_FOUND)
        assignments = db.execute(
            text(
                "DELETE FROM stud_task WHERE class_name_fk = :class_name "
                "AND task_id_fk = :task_id"
            ),
            {"class_name": class_name, "task_id": task_id},
        ).rowcount
        db.execute(
            text(
                "DELETE FROM class_task WHERE class_name_fk = :class_name "
                "AND task_id_fk = :task_id"
            ),
            {"class_name": class_name, "task_id": task_id},
        )
        db.execute(
            text(
                "DELETE FROM Tasks task WHERE task.task_id = :task_id "
                "AND NOT EXISTS (SELECT 1 FROM stud_task assigned "
                "WHERE assigned.task_id_fk = task.task_id) "
                "AND NOT EXISTS (SELECT 1 FROM class_task linked "
                "WHERE linked.task_id_fk = task.task_id)"
            ),
            {"task_id": task_id},
        )
        db.commit()
        return success_response(
            class_name=class_name,
            task_id=task_id,
            student_assignments_removed=assignments,
        )
    except Exception:
        db.rollback()
        raise


def assign_task(
    db: Session,
    class_name: str,
    staff_username: str,
    task_title: str,
    task_date: date,
    task_start_hour: time | None,
    task_duration: int,
    alt_task_id_fk: int | None,
) -> dict:
    """Crea una tarea y la asigna a todos los alumnos inscritos en la clase."""
    _ensure_staff_class(db, class_name, staff_username)
    _lock_class(db, class_name)
    validate_task_schedule("staff", task_start_hour, task_duration)

    students = db.execute(
        text("SELECT stud_usr_fk FROM class_stud WHERE class_name_fk = :class_name ORDER BY stud_usr_fk"),
        {"class_name": class_name},
    ).scalars().all()
    if not students:
        raise CatalogError(ErrorCode.CLASS_HAS_NO_STUDENTS)
    if alt_task_id_fk is not None:
        exists = db.execute(
            text("SELECT 1 FROM Alt_Tasks WHERE alt_task_id = :alt_task_id"),
            {"alt_task_id": alt_task_id_fk},
        ).scalar_one_or_none()
        if exists is None:
            raise CatalogError(ErrorCode.ALTERNATIVE_TASK_NOT_FOUND)
        used = db.execute(
            text("SELECT 1 FROM Tasks WHERE alt_task_id_fk = :alt_task_id"),
            {"alt_task_id": alt_task_id_fk},
        ).scalar_one_or_none()
        if used is not None:
            raise CatalogError(ErrorCode.ALTERNATIVE_TASK_ALREADY_ASSIGNED)

    try:
        lock_student_agendas(db, students)
        task_indexes = {
            username: calculate_task_index(db, username, task_date, task_start_hour)
            for username in students
        }
        task = db.execute(
            text(
                "INSERT INTO Tasks "
                "(task_title, task_start_hour, task_duration, task_creator, task_finished, alt_task_id_fk) "
                "VALUES (:title, :start_hour, :duration, :creator, FALSE, :alt_task_id) "
                "RETURNING task_id, task_title, task_start_hour, task_duration, task_creator, "
                "task_finished, alt_task_id_fk"
            ),
            {
                "title": task_title,
                "start_hour": task_start_hour,
                "duration": task_duration,
                "creator": staff_username,
                "alt_task_id": alt_task_id_fk,
            },
        ).mappings().one()
        db.execute(text("INSERT INTO Generic_Task (task_id_fk) VALUES (:task_id)"), {"task_id": task["task_id"]})
        db.execute(
            text(
                "INSERT INTO class_task (class_name_fk, task_id_fk, task_date) "
                "VALUES (:class_name, :task_id, :task_date)"
            ),
            {"class_name": class_name, "task_id": task["task_id"], "task_date": task_date},
        )
        db.execute(
            text(
                "INSERT INTO stud_task "
                "(stud_usr_fk, task_id_fk, task_index, task_date, class_name_fk) "
                "VALUES (:student_username, :task_id, :task_index, :task_date, :class_name)"
            ),
            [
                {
                    "student_username": username,
                    "task_id": task["task_id"],
                    "task_index": task_indexes[username],
                    "task_date": task_date,
                    "class_name": class_name,
                }
                for username in students
            ],
        )
        db.commit()
        return success_response(
            **dict(task),
            class_name=class_name,
            students=students,
            task_indexes=task_indexes,
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
