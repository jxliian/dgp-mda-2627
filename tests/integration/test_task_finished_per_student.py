"""El estado «terminada» es de cada alumno y día (stud_task.task_finished), no de la tarea.

En una tarea de clase hay una sola fila en Tasks compartida por todos sus alumnos;
completarla un alumno no debe marcarla como completada para el resto.
"""
import pytest
from sqlalchemy import text

from conftest import LUNES, as_user

MARTES = "2026-11-17"


def _crear_tarea_de_clase(client, fecha=LUNES, titulo="Plástica"):
    body = {"task_title": titulo, "task_date": fecha, "task_start_hour": "11:00", "task_duration": 60}
    respuesta = client.post("/classes/1A/tasks", json=body, headers=as_user("lucia"))
    assert respuesta.status_code == 201, respuesta.json()
    return respuesta.json()["task_id"]


def _completar(engine, alumno, task_id, fecha=LUNES):
    """Marca la tarea como terminada para un alumno, como hará la ruta de progreso."""
    with engine.begin() as conn:
        cambiadas = conn.execute(
            text(
                "UPDATE stud_task SET task_finished = TRUE "
                "WHERE stud_usr_fk = :alumno AND task_id_fk = :task_id AND task_date = :fecha"
            ),
            {"alumno": alumno, "task_id": task_id, "fecha": fecha},
        ).rowcount
    assert cambiadas == 1


def _estado(client, alumno, task_id, fecha=LUNES):
    respuesta = client.get(
        f"/student-tasks/students/{alumno}", params={"task_date": fecha}, headers=as_user("lucia")
    )
    assert respuesta.status_code == 200, respuesta.json()
    return {t["task_id"]: t["task_finished"] for t in respuesta.json()["tasks"]}[task_id]


def _tarea_de_la_clase(client, task_id):
    respuesta = client.get("/classes/1A/tasks", headers=as_user("lucia"))
    assert respuesta.status_code == 200, respuesta.json()
    return next(t for t in respuesta.json()["tasks"] if t["task_id"] == task_id)


@pytest.fixture
def clase_con_dos_alumnos(client):
    respuesta = client.post("/classes/1A/students/ana", headers=as_user("lucia"))
    assert respuesta.status_code == 201, respuesta.json()


def test_completar_una_tarea_de_clase_no_afecta_a_los_companeros(client, engine, clase_con_dos_alumnos):
    task_id = _crear_tarea_de_clase(client)
    _completar(engine, "pablo", task_id)

    assert _estado(client, "pablo", task_id) is True
    assert _estado(client, "ana", task_id) is False


def test_el_alumno_ve_su_propio_estado_en_su_agenda(client, engine, clase_con_dos_alumnos):
    task_id = _crear_tarea_de_clase(client)
    _completar(engine, "pablo", task_id)

    for alumno, esperado in [("pablo", True), ("ana", False)]:
        respuesta = client.get("/student-tasks/me", params={"task_date": LUNES}, headers=as_user(alumno))
        assert respuesta.status_code == 200, respuesta.json()
        assert [t["task_finished"] for t in respuesta.json()["tasks"]] == [esperado]


def test_el_filtro_por_estado_usa_el_estado_de_cada_alumno(client, engine, clase_con_dos_alumnos):
    task_id = _crear_tarea_de_clase(client)
    _completar(engine, "pablo", task_id)

    def ids(alumno, terminada):
        respuesta = client.get(
            f"/student-tasks/students/{alumno}",
            params={"task_date": LUNES, "finished": terminada},
            headers=as_user("lucia"),
        )
        return [t["task_id"] for t in respuesta.json()["tasks"]]

    assert ids("pablo", "true") == [task_id]
    assert ids("pablo", "false") == []
    assert ids("ana", "true") == []
    assert ids("ana", "false") == [task_id]


def test_la_clase_muestra_quien_la_ha_completado(client, engine, clase_con_dos_alumnos):
    task_id = _crear_tarea_de_clase(client)

    tarea = _tarea_de_la_clase(client, task_id)
    assert tarea["task_finished"] is False
    assert tarea["students_finished"] == []

    _completar(engine, "pablo", task_id)
    tarea = _tarea_de_la_clase(client, task_id)
    assert tarea["task_finished"] is False
    assert tarea["students_finished"] == ["pablo"]

    _completar(engine, "ana", task_id)
    tarea = _tarea_de_la_clase(client, task_id)
    assert tarea["task_finished"] is True
    assert tarea["students_finished"] == ["ana", "pablo"]


def test_editar_la_tarea_el_mismo_dia_conserva_lo_completado(client, engine, clase_con_dos_alumnos):
    task_id = _crear_tarea_de_clase(client)
    _completar(engine, "pablo", task_id)

    body = {"task_title": "Plástica con témperas", "task_date": LUNES, "task_start_hour": "12:00", "task_duration": 45}
    respuesta = client.put(f"/classes/1A/tasks/{task_id}", json=body, headers=as_user("lucia"))
    assert respuesta.status_code == 200, respuesta.json()
    assert respuesta.json()["task_finished"] is False

    assert _estado(client, "pablo", task_id) is True
    assert _estado(client, "ana", task_id) is False


def test_mover_la_tarea_a_otro_dia_la_deja_pendiente(client, engine, clase_con_dos_alumnos):
    task_id = _crear_tarea_de_clase(client)
    _completar(engine, "pablo", task_id)

    body = {"task_title": "Plástica", "task_date": MARTES, "task_start_hour": "11:00", "task_duration": 60}
    respuesta = client.put(f"/classes/1A/tasks/{task_id}", json=body, headers=as_user("lucia"))
    assert respuesta.status_code == 200, respuesta.json()

    assert _estado(client, "pablo", task_id, fecha=MARTES) is False


def test_las_tareas_nuevas_empiezan_pendientes(client, count):
    familia = client.post(
        "/student-tasks/students/pablo",
        json={"task_title": "Hacer la cama", "task_date": LUNES, "task_start_hour": "17:00", "task_duration": 30},
        headers=as_user("madre"),
    )
    assert familia.status_code == 201
    assert familia.json()["task_finished"] is False
    clase = _crear_tarea_de_clase(client)

    assert count("stud_task WHERE task_finished") == 0
    assert _estado(client, "pablo", familia.json()["task_id"]) is False
    assert _estado(client, "pablo", clase) is False


def test_el_estado_ya_no_se_guarda_en_la_tarea(count):
    assert count(
        "information_schema.columns WHERE table_name = 'tasks' AND column_name = 'task_finished'"
    ) == 0
    assert count(
        "information_schema.columns WHERE table_name = 'stud_task' AND column_name = 'task_finished'"
    ) == 1


def test_cambiar_la_alternativa_devuelve_el_estado_del_alumno(client, engine):
    creada = client.post(
        "/student-tasks/students/pablo",
        json={"task_title": "Hacer la cama", "task_date": LUNES, "task_start_hour": "17:00", "task_duration": 30},
        headers=as_user("madre"),
    ).json()
    _completar(engine, "pablo", creada["task_id"])

    respuesta = client.put(
        f"/student-tasks/{creada['task_id']}/alternative",
        json={"alt_task_id_fk": None},
        headers=as_user("madre"),
    )
    assert respuesta.status_code == 200, respuesta.json()
    assert respuesta.json()["task_finished"] is True
