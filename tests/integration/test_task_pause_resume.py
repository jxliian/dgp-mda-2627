"""Pausa, reanudación, reprogramación y avisos de tareas del alumno."""
from sqlalchemy import bindparam, text

from conftest import LUNES, as_user

FECHA_FUTURA = "2099-01-01"


def _crear_tarea(client, title, start_hour, duration):
    response = client.post(
        "/student-tasks/me",
        json={
            "task_title": title,
            "task_date": LUNES,
            "task_start_hour": start_hour,
            "task_duration": duration,
        },
        headers=as_user("pablo"),
    )
    assert response.status_code == 201, response.json()
    return response.json()["task_id"]


def _crear_tarea_personal(client, title, start_hour, duration):
    response = client.post(
        "/student-tasks/students/pablo",
        json={
            "task_title": title,
            "task_date": FECHA_FUTURA,
            "task_start_hour": start_hour,
            "task_duration": duration,
        },
        headers=as_user("lucia"),
    )
    assert response.status_code == 201, response.json()
    return response.json()["task_id"]


def test_pausar_y_reanudar_conserva_tiempo_y_estado(client, engine):
    task_id = _crear_tarea(client, "Lectura", "17:00", 60)
    started = client.post(
        f"/student-tasks/me/{task_id}/resume", params={"task_date": LUNES}, headers=as_user("pablo")
    )
    assert started.status_code == 200, started.json()
    assert started.json()["task_status"] == "in_progress"
    assert started.json()["task_started_at"] is not None

    paused = client.post(
        f"/student-tasks/me/{task_id}/pause", params={"task_date": LUNES}, headers=as_user("pablo")
    )
    assert paused.status_code == 200, paused.json()
    assert paused.json()["task_status"] == "paused"
    assert 0 <= paused.json()["remaining_seconds"] <= 3600

    resumed = client.post(
        f"/student-tasks/me/{task_id}/resume", params={"task_date": LUNES}, headers=as_user("pablo")
    )
    assert resumed.status_code == 200, resumed.json()
    assert resumed.json()["skipped"] is False
    assert resumed.json()["remaining_seconds"] == paused.json()["remaining_seconds"]

    with engine.connect() as conn:
        state = conn.execute(
            text(
                "SELECT task_status, task_remaining_seconds, task_started_at FROM stud_task "
                "WHERE stud_usr_fk = 'pablo' AND task_id_fk = :task_id AND task_date = :task_date"
            ),
            {"task_id": task_id, "task_date": LUNES},
        ).one()
    assert state.task_status == "in_progress"
    assert state.task_remaining_seconds == paused.json()["remaining_seconds"]
    assert state.task_started_at is not None


def test_conflicto_omite_tarea_y_genera_aviso_para_tutor(client, engine):
    task_id = _crear_tarea(client, "Lectura", "17:00", 60)
    assert client.post(
        f"/student-tasks/me/{task_id}/resume", params={"task_date": LUNES}, headers=as_user("pablo")
    ).status_code == 200
    assert client.post(
        f"/student-tasks/me/{task_id}/pause", params={"task_date": LUNES}, headers=as_user("pablo")
    ).status_code == 200
    next_id = _crear_tarea(client, "Deberes", "17:30", 30)

    resumed = client.post(
        f"/student-tasks/me/{task_id}/resume", params={"task_date": LUNES}, headers=as_user("pablo")
    )
    assert resumed.status_code == 200, resumed.json()
    assert resumed.json()["skipped"] is True
    assert resumed.json()["task_finished"] is False
    assert resumed.json()["tutor_notified"] is True

    notifications = client.get("/student-tasks/parents/me/task-notifications", headers=as_user("madre"))
    assert notifications.status_code == 200, notifications.json()
    assert len(notifications.json()["notifications"]) == 1
    assert notifications.json()["notifications"][0]["task_id_fk"] == task_id
    assert next_id != task_id
    notification_id = notifications.json()["notifications"][0]["notification_id"]
    read = client.patch(
        f"/student-tasks/parents/me/task-notifications/{notification_id}/read",
        headers=as_user("madre"),
    )
    assert read.status_code == 200, read.json()
    assert client.get(
        "/student-tasks/parents/me/task-notifications", headers=as_user("madre")
    ).json()["notifications"] == []

    with engine.connect() as conn:
        state = conn.execute(
            text(
                "SELECT task_finished, task_status, task_remaining_seconds FROM stud_task "
                "WHERE stud_usr_fk = 'pablo' AND task_id_fk = :task_id AND task_date = :task_date"
            ),
            {"task_id": task_id, "task_date": LUNES},
        ).one()
    assert state.task_finished is False
    assert state.task_status == "pending"
    assert state.task_remaining_seconds == resumed.json()["remaining_seconds"]
    assert 0 <= state.task_remaining_seconds <= 3600


def test_reanudar_con_hora_y_siguiente_sin_hora_reprograma_agenda(client):
    task_id = _crear_tarea(client, "Lectura", "17:00", 30)
    client.post(
        f"/student-tasks/me/{task_id}/resume", params={"task_date": LUNES}, headers=as_user("pablo")
    )
    client.post(
        f"/student-tasks/me/{task_id}/pause", params={"task_date": LUNES}, headers=as_user("pablo")
    )
    next_id = _crear_tarea(client, "Deberes", None, 20)

    resumed = client.post(
        f"/student-tasks/me/{task_id}/resume", params={"task_date": LUNES}, headers=as_user("pablo")
    )
    assert resumed.status_code == 200, resumed.json()
    assert resumed.json()["skipped"] is False

    agenda = client.get("/student-tasks/me", params={"task_date": LUNES}, headers=as_user("pablo"))
    assert agenda.status_code == 200, agenda.json()
    by_id = {task["task_id"]: task for task in agenda.json()["tasks"]}
    assert by_id[task_id]["task_start_hour"] == "17:00:00"
    assert by_id[next_id]["task_start_hour"] is not None
    assert by_id[next_id]["task_start_hour"] >= "17:30:00"


def test_tarea_pausada_sin_hora_se_aplaza_despues_de_horarios_fijos(client):
    task_id = _crear_tarea(client, "Lectura", None, 30)
    client.post(
        f"/student-tasks/me/{task_id}/resume", params={"task_date": LUNES}, headers=as_user("pablo")
    )
    client.post(
        f"/student-tasks/me/{task_id}/pause", params={"task_date": LUNES}, headers=as_user("pablo")
    )
    next_id = _crear_tarea(client, "Deberes", "17:30", 30)
    later_id = _crear_tarea(client, "Preparar mochila", "18:00", 15)

    resumed = client.post(
        f"/student-tasks/me/{task_id}/resume", params={"task_date": LUNES}, headers=as_user("pablo")
    )
    assert resumed.status_code == 200, resumed.json()
    assert resumed.json()["skipped"] is False

    agenda = client.get("/student-tasks/me", params={"task_date": LUNES}, headers=as_user("pablo"))
    assert agenda.status_code == 200, agenda.json()
    by_id = {task["task_id"]: task for task in agenda.json()["tasks"]}
    assert by_id[next_id]["task_start_hour"] == "17:30:00"
    assert by_id[task_id]["task_start_hour"] == "18:15:00"
    assert by_id[later_id]["task_start_hour"] == "18:00:00"


def test_reanudar_no_desplaza_tareas_del_personal_fuera_del_horario_escolar(client, engine):
    task_id = _crear_tarea_personal(client, "Actividad inicial", "09:00", 30)
    started = client.post(
        f"/student-tasks/me/{task_id}/resume",
        params={"task_date": FECHA_FUTURA},
        headers=as_user("pablo"),
    )
    assert started.status_code == 200, started.json()
    paused = client.post(
        f"/student-tasks/me/{task_id}/pause",
        params={"task_date": FECHA_FUTURA},
        headers=as_user("pablo"),
    )
    assert paused.status_code == 200, paused.json()

    siguiente_id = _crear_tarea_personal(client, "Actividad larga", "09:30", 330)
    ultima_id = _crear_tarea_personal(client, "Actividad final", "09:45", 315)
    resumed = client.post(
        f"/student-tasks/me/{task_id}/resume",
        params={"task_date": FECHA_FUTURA},
        headers=as_user("pablo"),
    )

    assert resumed.status_code == 200, resumed.json()
    assert resumed.json()["skipped"] is True
    assert resumed.json()["task_status"] == "pending"
    assert resumed.json()["staff_notified"] is True
    assert resumed.json()["tutor_notified"] is False

    staff_notices = client.get(
        "/student-tasks/staff/me/task-notifications", headers=as_user("lucia")
    )
    assert staff_notices.status_code == 200, staff_notices.json()
    assert len(staff_notices.json()["notifications"]) == 1
    assert staff_notices.json()["notifications"][0]["task_id_fk"] == task_id
    staff_notification_id = staff_notices.json()["notifications"][0]["notification_id"]
    assert client.patch(
        f"/student-tasks/staff/me/task-notifications/{staff_notification_id}/read",
        headers=as_user("lucia"),
    ).status_code == 200
    assert client.get(
        "/student-tasks/staff/me/task-notifications", headers=as_user("lucia")
    ).json()["notifications"] == []
    assert client.get(
        "/student-tasks/parents/me/task-notifications", headers=as_user("madre")
    ).json()["notifications"] == []

    with engine.connect() as conn:
        schedule = conn.execute(
            text(
                "SELECT task.task_id, COALESCE(assigned.task_scheduled_start_hour, task.task_start_hour) AS start_hour "
                "FROM stud_task assigned JOIN Tasks task ON task.task_id = assigned.task_id_fk "
                "WHERE assigned.stud_usr_fk = 'pablo' AND assigned.task_date = :task_date "
                "AND task.task_id IN :task_ids"
            ).bindparams(bindparam("task_ids", expanding=True)),
            {"task_date": FECHA_FUTURA, "task_ids": [task_id, siguiente_id, ultima_id]},
        ).mappings().all()
    starts = {row["task_id"]: str(row["start_hour"]) for row in schedule}
    assert starts == {task_id: "09:00:00", siguiente_id: "09:30:00", ultima_id: "09:45:00"}
