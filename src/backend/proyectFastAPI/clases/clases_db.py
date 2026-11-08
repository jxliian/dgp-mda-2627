from datetime import date, time

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..errors import CatalogError, ErrorCode, success_response

SCHOOL_START = time(9, 0)
SCHOOL_END = time(15, 0)


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
    """Elimina la clase y sus asociaciones de profesores y alumnos."""
    row = db.execute(
        text("DELETE FROM Class WHERE class_name = :class_name RETURNING class_name"),
        {"class_name": class_name},
    ).mappings().first()
    if row is None:
        db.rollback()
        raise CatalogError(ErrorCode.CLASS_NOT_FOUND)
    db.commit()
    return success_response(**dict(row))


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


def list_staff_classes(db: Session, staff_username: str) -> list[dict]:
    """Lista las clases del personal y cuenta sus alumnos inscritos."""
    rows = db.execute(
        text(
            "SELECT c.class_name, COUNT(cs.stud_usr_fk)::int AS student_count "
            "FROM Class c JOIN class_staff teacher "
            "ON teacher.class_name_fk = c.class_name "
            "LEFT JOIN class_stud cs ON cs.class_name_fk = c.class_name "
            "WHERE teacher.staff_usr_fk = :staff_username "
            "GROUP BY c.class_name ORDER BY c.class_name"
        ),
        {"staff_username": staff_username},
    ).mappings().all()
    return [dict(row) for row in rows]


def get_class(db: Session, class_name: str, staff_username: str) -> dict:
    """Devuelve el detalle de una clase, sus alumnos y su personal asignado."""
    class_info = _ensure_staff_class(db, class_name, staff_username)
    students = db.execute(
        text(
            "SELECT s.stud_usr AS username, u.full_name "
            "FROM class_stud cs JOIN Student s ON s.stud_usr = cs.stud_usr_fk "
            "JOIN users u ON u.username = s.stud_usr "
            "WHERE cs.class_name_fk = :class_name ORDER BY s.stud_usr"
        ),
        {"class_name": class_name},
    ).mappings().all()
    teachers = db.execute(
        text(
            "SELECT s.staff_usr AS username, u.full_name "
            "FROM class_staff cs JOIN Staff s ON s.staff_usr = cs.staff_usr_fk "
            "JOIN users u ON u.username = s.staff_usr "
            "WHERE cs.class_name_fk = :class_name ORDER BY s.staff_usr"
        ),
        {"class_name": class_name},
    ).mappings().all()
    return success_response(
        **class_info,
        students=[dict(row) for row in students],
        staff=[dict(row) for row in teachers],
    )


def add_student(db: Session, class_name: str, staff_username: str, student_username: str) -> dict:
    """Inscribe al alumno si aún no pertenece a otra clase."""
    _ensure_staff_class(db, class_name, staff_username)
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
        db.rollback()
        raise CatalogError(ErrorCode.STUDENT_ALREADY_IN_CLASS)
    db.execute(
        text(
            "INSERT INTO class_stud (class_name_fk, stud_usr_fk) "
            "VALUES (:class_name, :student_username) "
            "ON CONFLICT (stud_usr_fk) DO NOTHING"
        ),
        {"class_name": class_name, "student_username": student_username},
    )
    db.commit()
    return success_response(class_name=class_name, student_username=student_username)


def remove_student(db: Session, class_name: str, staff_username: str, student_username: str) -> dict:
    """Retira al alumno de la clase gestionada por el personal autenticado."""
    _ensure_staff_class(db, class_name, staff_username)
    result = db.execute(
        text(
            "DELETE FROM class_stud WHERE class_name_fk = :class_name "
            "AND stud_usr_fk = :student_username"
        ),
        {"class_name": class_name, "student_username": student_username},
    )
    if not result.rowcount:
        db.rollback()
        raise CatalogError(ErrorCode.ASSOCIATION_NOT_FOUND)
    db.commit()
    return success_response(class_name=class_name, student_username=student_username)


def assign_task(
    db: Session,
    class_name: str,
    staff_username: str,
    task_title: str,
    task_date: date,
    task_index: int,
    task_start_hour: time | None,
    task_duration: int,
    alt_task_id_fk: int | None,
) -> dict:
    """Crea una tarea y la asigna a todos los alumnos inscritos en la clase."""
    _ensure_staff_class(db, class_name, staff_username)
    if task_duration is None or task_duration <= 0:
        raise CatalogError(ErrorCode.INVALID_REQUEST)
    if task_start_hour is not None and not SCHOOL_START <= task_start_hour < SCHOOL_END:
        raise CatalogError(ErrorCode.STAFF_TASK_OUTSIDE_SCHOOL_HOURS)

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
                "INSERT INTO stud_task (stud_usr_fk, task_id_fk, task_index, task_date) "
                "VALUES (:student_username, :task_id, :task_index, :task_date)"
            ),
            [
                {
                    "student_username": username,
                    "task_id": task["task_id"],
                    "task_index": task_index,
                    "task_date": task_date,
                }
                for username in students
            ],
        )
        db.commit()
        return success_response(
            **dict(task),
            class_name=class_name,
            students=students,
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
