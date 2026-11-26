from datetime import date, time

from sqlalchemy import bindparam, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..errors import CatalogError, ErrorCode, success_response
from ..task_indexing import calculate_task_index, lock_student_agendas
from ..task_schedule import validate_task_schedule

SCHOOL_START = time(9, 0)
SCHOOL_END = time(15, 0)

# Rol de quien creó la tarea, deducido de la tabla de especialización en la que está.
# Si la cuenta ya no existe, el rol queda vacío (NULL).
CREATOR_ROLE_SQL = (
    "CASE "
    "WHEN EXISTS (SELECT 1 FROM Staff WHERE staff_usr = task.task_creator) THEN 'staff' "
    "WHEN EXISTS (SELECT 1 FROM Parents WHERE par_usr = task.task_creator) THEN 'parent' "
    "WHEN EXISTS (SELECT 1 FROM Student WHERE stud_usr = task.task_creator) THEN 'student' "
    "WHEN EXISTS (SELECT 1 FROM Admn WHERE admn_usr = task.task_creator) THEN 'admin' "
    "END"
)


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


def list_student_tasks(
    db: Session,
    requester_role: str,
    requester_username: str,
    student_username: str,
    task_date: date,
    class_name: str | None = None,
    finished: bool | None = None,
    creator_role: str | None = None,
) -> dict:
    """Lista por fecha las tareas del alumno, con filtros opcionales por clase,
    estado y rol del creador."""
    if requester_role == "student":
        if requester_username != student_username:
            raise CatalogError(ErrorCode.TASK_CREATOR_REQUIRED)
        student_exists = db.execute(
            text("SELECT 1 FROM Student WHERE stud_usr = :username"),
            {"username": student_username},
        ).scalar_one_or_none()
        if student_exists is None:
            raise CatalogError(ErrorCode.TASK_STUDENT_NOT_FOUND)
    elif requester_role in {"staff", "parent"}:
        student_exists = db.execute(
            text(
                "SELECT 1 FROM users account JOIN Student profile "
                "ON profile.stud_usr = account.username "
                "WHERE account.username = :student_username"
            ),
            {"student_username": student_username},
        ).scalar_one_or_none()
        if student_exists is None:
            raise CatalogError(ErrorCode.TASK_STUDENT_NOT_FOUND)
        if not _has_student_relationship(
            db, requester_role, requester_username, student_username
        ):
            raise CatalogError(ErrorCode.TASK_STUDENT_NOT_ASSOCIATED)
    else:
        raise CatalogError(ErrorCode.TASK_CREATOR_REQUIRED)

    # Filtros opcionales (SCRUM-692). Solo se añaden a la consulta los que se piden.
    conditions = []
    parameters = {"student_username": student_username, "task_date": task_date}
    if class_name is not None:
        conditions.append("listed.class_name_fk = :class_name")
        parameters["class_name"] = class_name
    if finished is not None:
        conditions.append("COALESCE(listed.task_finished, FALSE) = :finished")
        parameters["finished"] = finished
    if creator_role is not None:
        conditions.append("listed.creator_role = :creator_role")
        parameters["creator_role"] = creator_role
    filters = "".join(f" AND {condition}" for condition in conditions)

    rows = db.execute(
        text(
            "SELECT * FROM ("
            "SELECT task.task_id, task.task_title, task.task_start_hour, "
            "task.task_duration, task.task_creator, task.task_finished, "
            "task.alt_task_id_fk, assigned.task_date, assigned.task_index, "
            "assigned.class_name_fk, "
            f"{CREATOR_ROLE_SQL} AS creator_role "
            "FROM stud_task assigned JOIN Tasks task "
            "ON task.task_id = assigned.task_id_fk "
            "WHERE assigned.stud_usr_fk = :student_username "
            "AND assigned.task_date = :task_date"
            ") AS listed "
            f"WHERE TRUE{filters} "
            "ORDER BY listed.task_index, listed.task_id"
        ),
        parameters,
    ).mappings().all()
    tasks = [dict(row) for row in rows]
    task_ids = [task["task_id"] for task in tasks]
    if task_ids:
        step_rows = db.execute(
            text(
                "SELECT step_id, step_description, step_finished, step_index, "
                "generic_task_id_fk FROM Steps "
                "WHERE generic_task_id_fk IN :task_ids "
                "ORDER BY generic_task_id_fk, step_index NULLS LAST, step_id"
            ).bindparams(bindparam("task_ids", expanding=True)),
            {"task_ids": task_ids},
        ).mappings().all()
        steps_by_task: dict[int, list[dict]] = {task_id: [] for task_id in task_ids}
        for step in step_rows:
            steps_by_task[step["generic_task_id_fk"]].append(
                {
                    "step_id": step["step_id"],
                    "step_description": step["step_description"],
                    "step_finished": step["step_finished"],
                    "step_index": step["step_index"],
                }
            )
        for task in tasks:
            task["steps"] = steps_by_task[task["task_id"]]
    return success_response(
        stud_usr_fk=student_username,
        task_date=task_date,
        tasks=tasks,
    )


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


def _lock_task_for_step_operation(
    db: Session,
    creator_role: str,
    creator_username: str,
    task_id: int,
    class_name: str | None,
) -> dict:
    """Autoriza al usuario y bloquea la tarea para serializar sus cambios de pasos."""
    if creator_role not in {"staff", "parent", "student"}:
        raise CatalogError(ErrorCode.TASK_CREATOR_REQUIRED)

    if creator_role == "student":
        task_permission = db.execute(
            text(
                "SELECT stud_access_task_mod FROM Student "
                "WHERE stud_usr = :creator_username"
            ),
            {"creator_username": creator_username},
        ).scalar_one_or_none()
        if task_permission is None:
            raise CatalogError(ErrorCode.TASK_STUDENT_NOT_FOUND)
        if task_permission is not True:
            raise CatalogError(ErrorCode.STUDENT_TASK_MODIFICATION_DENIED)

    if creator_role == "staff" and class_name is not None:
        assigned = db.execute(
            text(
                "SELECT 1 FROM class_staff WHERE class_name_fk = :class_name "
                "AND staff_usr_fk = :creator_username"
            ),
            {"class_name": class_name, "creator_username": creator_username},
        ).scalar_one_or_none()
        if assigned is None:
            raise CatalogError(ErrorCode.CLASS_ACCESS_DENIED)
        task = db.execute(
            text(
                "SELECT task.task_id, task.task_start_hour, task.task_duration FROM Tasks task "
                "JOIN Generic_Task generic ON generic.task_id_fk = task.task_id "
                "JOIN class_task linked ON linked.task_id_fk = task.task_id "
                "WHERE task.task_id = :task_id "
                "AND linked.class_name_fk = :class_name "
                "FOR UPDATE OF task"
            ),
            {"task_id": task_id, "class_name": class_name},
        ).mappings().first()
    elif creator_role == "staff":
        task = db.execute(
            text(
                "SELECT task.task_id, task.task_start_hour, task.task_duration FROM Tasks task "
                "JOIN Generic_Task generic ON generic.task_id_fk = task.task_id "
                "WHERE task.task_id = :task_id "
                "AND task.task_creator = :creator_username "
                "AND EXISTS ("
                "SELECT 1 FROM stud_task assigned "
                "WHERE assigned.task_id_fk = task.task_id "
                "AND assigned.class_name_fk IS NULL "
                "AND EXISTS ("
                "SELECT 1 FROM class_stud enrollment "
                "JOIN class_staff teaching "
                "ON teaching.class_name_fk = enrollment.class_name_fk "
                "WHERE enrollment.stud_usr_fk = assigned.stud_usr_fk "
                "AND teaching.staff_usr_fk = :creator_username)) "
                "FOR UPDATE OF task"
            ),
            {"task_id": task_id, "creator_username": creator_username},
        ).mappings().first()
    elif class_name is not None:
        raise CatalogError(ErrorCode.TASK_NOT_FOUND)
    elif creator_role == "parent":
        task = db.execute(
            text(
                "SELECT task.task_id, task.task_start_hour, task.task_duration FROM Tasks task "
                "JOIN Generic_Task generic ON generic.task_id_fk = task.task_id "
                "WHERE task.task_id = :task_id "
                "AND task.task_creator = :creator_username "
                "AND EXISTS (SELECT 1 FROM stud_task assigned "
                "JOIN par_stud linked ON linked.stud_usr_fk = assigned.stud_usr_fk "
                "WHERE assigned.task_id_fk = task.task_id "
                "AND assigned.class_name_fk IS NULL "
                "AND linked.par_usr_fk = :creator_username) "
                "FOR UPDATE OF task"
            ),
            {"task_id": task_id, "creator_username": creator_username},
        ).mappings().first()
    else:
        task = db.execute(
            text(
                "SELECT task.task_id, task.task_start_hour, task.task_duration FROM Tasks task "
                "JOIN Generic_Task generic ON generic.task_id_fk = task.task_id "
                "WHERE task.task_id = :task_id "
                "AND task.task_creator = :creator_username "
                "FOR UPDATE OF task"
            ),
            {"task_id": task_id, "creator_username": creator_username},
        ).mappings().first()
    if task is None:
        raise CatalogError(ErrorCode.TASK_NOT_FOUND)
    return dict(task)


def _validate_step_schedule(
    task: dict, creator_role: str, deleting: bool = False
) -> None:
    """Aplica las restricciones escolares de los pasos de tutores y personal."""
    if creator_role not in {"staff", "parent"}:
        return
    try:
        validate_task_schedule(
            creator_role, task["task_start_hour"], task["task_duration"]
        )
    except CatalogError as exc:
        if not deleting:
            raise
        delete_error = (
            ErrorCode.STAFF_DELETE_OUTSIDE_SCHOOL_HOURS
            if creator_role == "staff"
            else ErrorCode.PARENT_DELETE_DURING_SCHOOL_HOURS
        )
        raise CatalogError(delete_error) from exc


def _reindex_task_steps(db: Session, task_id: int) -> None:
    """Renombra índices existentes a una secuencia continua desde cero."""
    db.execute(
        text(
            "WITH ordered_steps AS ("
            "SELECT step_id, (ROW_NUMBER() OVER ("
            "ORDER BY step_index NULLS LAST, step_id) - 1)::INTEGER AS new_index "
            "FROM Steps WHERE generic_task_id_fk = :task_id) "
            "UPDATE Steps current_step SET step_index = ordered_steps.new_index "
            "FROM ordered_steps WHERE current_step.step_id = ordered_steps.step_id "
            "AND current_step.step_index IS DISTINCT FROM ordered_steps.new_index"
        ),
        {"task_id": task_id},
    )


def create_task_step(
    db: Session,
    creator_role: str,
    creator_username: str,
    task_id: int,
    step_description: str,
    class_name: str | None = None,
) -> dict:
    """Añade un paso a una tarea autorizada y lo coloca al final de su orden."""
    try:
        task = _lock_task_for_step_operation(
            db, creator_role, creator_username, task_id, class_name
        )
        _validate_step_schedule(task, creator_role)
        _reindex_task_steps(db, task_id)
        next_index = db.execute(
            text(
                "SELECT COALESCE(MAX(step_index), -1) + 1 "
                "FROM Steps WHERE generic_task_id_fk = :task_id"
            ),
            {"task_id": task_id},
        ).scalar_one()
        step = db.execute(
            text(
                "INSERT INTO Steps "
                "(step_description, step_finished, step_index, generic_task_id_fk) "
                "VALUES (:description, FALSE, :step_index, :task_id) "
                "RETURNING step_id, step_description, step_finished, "
                "step_index, generic_task_id_fk"
            ),
            {
                "description": step_description,
                "step_index": next_index,
                "task_id": task_id,
            },
        ).mappings().one()
        db.commit()
        return success_response(**dict(step), **({"class_name": class_name} if class_name else {}))
    except CatalogError:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        raise


def delete_task_step(
    db: Session,
    creator_role: str,
    creator_username: str,
    task_id: int,
    step_id: int,
    class_name: str | None = None,
) -> dict:
    """Elimina un paso autorizado y compacta el orden de los pasos restantes."""
    try:
        task = _lock_task_for_step_operation(
            db, creator_role, creator_username, task_id, class_name
        )
        _validate_step_schedule(task, creator_role, deleting=True)
        step = db.execute(
            text(
                "DELETE FROM Steps WHERE step_id = :step_id "
                "AND generic_task_id_fk = :task_id "
                "RETURNING step_id, step_index"
            ),
            {"step_id": step_id, "task_id": task_id},
        ).mappings().first()
        if step is None:
            raise CatalogError(ErrorCode.TASK_NOT_FOUND)

        _reindex_task_steps(db, task_id)
        remaining = db.execute(
            text("SELECT COUNT(*) FROM Steps WHERE generic_task_id_fk = :task_id"),
            {"task_id": task_id},
        ).scalar_one()
        db.commit()
        return success_response(
            task_id=task_id,
            deleted_step_id=step_id,
            deleted_step_index=step["step_index"],
            remaining_steps=remaining,
            **({"class_name": class_name} if class_name else {}),
        )
    except CatalogError:
        db.rollback()
        raise
    except Exception:
        db.rollback()
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
