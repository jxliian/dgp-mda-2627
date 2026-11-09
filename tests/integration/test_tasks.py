"""HU-12 (tarea de la familia), HU-13 (tarea del personal) y HU-15 (eliminar tareas)."""
import pytest

from conftest import LUNES, SABADO, as_user, error_code


def create_task(client, usuario, alumno="pablo", hora="17:00", duracion=30, fecha=LUNES, titulo="Tarea"):
    body = {"task_title": titulo, "task_date": fecha, "task_duration": duracion}
    if hora is not None:
        body["task_start_hour"] = hora
    return client.post(f"/student-tasks/students/{alumno}", json=body, headers=as_user(usuario))


def delete_task(client, usuario, task_id, alumno="pablo", fecha=LUNES):
    return client.delete(
        f"/student-tasks/students/{alumno}/{task_id}",
        params={"task_date": fecha},
        headers=as_user(usuario),
    )


# ---------------------------------------------------- HU-12: la familia crea tareas

def test_la_familia_crea_una_tarea_y_queda_en_la_agenda(client, count):
    r = create_task(client, "madre", titulo="Hacer la cama")
    assert r.status_code == 201
    datos = r.json()
    assert datos["task_title"] == "Hacer la cama"
    assert datos["task_creator"] == "madre"
    assert datos["task_finished"] is False
    assert datos["stud_usr_fk"] == "pablo"
    assert count("Generic_Task WHERE task_id_fk = :t", t=datos["task_id"]) == 1
    assert count(
        "stud_task WHERE task_id_fk = :t AND stud_usr_fk = 'pablo' AND task_date = :d",
        t=datos["task_id"], d=LUNES,
    ) == 1


def test_la_familia_puede_crear_una_tarea_solo_con_duracion(client):
    r = create_task(client, "madre", hora=None)
    assert r.status_code == 201
    assert r.json()["task_start_hour"] is None


@pytest.mark.parametrize(
    "hora, duracion",
    [("08:30", 30), ("15:00", 30), ("07:00", 60), ("23:00", 600)],
)
def test_la_familia_crea_fuera_del_horario_escolar(client, hora, duracion):
    assert create_task(client, "madre", hora=hora, duracion=duracion).status_code == 201


@pytest.mark.parametrize(
    "hora, duracion",
    [("08:30", 31), ("09:00", 10), ("10:00", 30), ("14:59", 1), ("23:00", 601)],
)
def test_la_familia_no_crea_dentro_del_horario_escolar(client, count, hora, duracion):
    r = create_task(client, "madre", hora=hora, duracion=duracion)
    assert r.status_code == 400
    assert error_code(r) == 1024
    assert count("Tasks") == 0


def test_familia_sin_relacion_con_el_alumno(client, count):
    r = create_task(client, "otra_madre")
    assert r.status_code == 403
    assert error_code(r) == 1019
    assert count("Tasks") == 0


def test_tarea_para_un_alumno_inexistente(client):
    r = create_task(client, "madre", alumno="nadie")
    assert r.status_code == 404
    assert error_code(r) == 1018


@pytest.mark.parametrize("usuario", ["admin", "pablo"])
def test_solo_familia_y_personal_crean_para_un_alumno(client, usuario):
    r = create_task(client, usuario)
    assert r.status_code == 403
    assert error_code(r) == 1017


def test_crear_tarea_sin_sesion(client):
    body = {"task_title": "T", "task_date": LUNES, "task_duration": 30}
    assert client.post("/student-tasks/students/pablo", json=body).status_code == 401


@pytest.mark.parametrize(
    "cambio",
    [
        {"task_title": "   "},
        {"task_title": "x" * 101},
        {"task_duration": 0},
        {"task_duration": "30"},
        {"task_date": "no-es-fecha"},
        {"task_start_hour": "25:00"},
        {"task_start_hour": "17:00+01:00"},
        {"campo_inventado": 1},
    ],
)
def test_crear_tarea_con_datos_invalidos(client, count, cambio):
    body = {"task_title": "T", "task_date": LUNES, "task_start_hour": "17:00", "task_duration": 30, **cambio}
    r = client.post("/student-tasks/students/pablo", json=body, headers=as_user("madre"))
    assert r.status_code == 422
    assert error_code(r) == 1005
    assert count("Tasks") == 0


def test_la_agenda_queda_ordenada_por_hora(client, engine):
    from sqlalchemy import text

    tarde = create_task(client, "madre", hora="18:00", titulo="Tarde").json()["task_id"]
    antes = create_task(client, "madre", hora="16:00", titulo="Antes").json()["task_id"]
    sin_hora = create_task(client, "madre", hora=None, titulo="Sin hora").json()["task_id"]
    with engine.connect() as conn:
        orden = conn.execute(
            text("SELECT task_id_fk FROM stud_task WHERE stud_usr_fk = 'pablo' ORDER BY task_index")
        ).scalars().all()
    assert orden == [antes, tarde, sin_hora]


@pytest.mark.xfail(strict=True, reason="Horario: se aplica de 9 a 15 también en fin de semana")
def test_la_familia_crea_un_sabado_por_la_manana(client):
    assert create_task(client, "madre", hora="10:00", fecha=SABADO).status_code == 201


# ---------------------------------------------------- HU-13: el personal crea tareas

def test_el_personal_crea_una_tarea_y_se_guarda(client, engine):
    from sqlalchemy import text

    r = create_task(client, "lucia", hora="10:00", duracion=45)
    assert r.status_code == 201
    with engine.connect() as conn:
        fila = conn.execute(
            text("SELECT task_start_hour, task_duration, task_creator FROM Tasks WHERE task_id = :t"),
            {"t": r.json()["task_id"]},
        ).one()
    assert (str(fila[0]), fila[1], fila[2]) == ("10:00:00", 45, "lucia")


@pytest.mark.parametrize("hora, duracion", [("09:00", 360), ("14:30", 30)])
def test_el_personal_crea_dentro_del_horario(client, hora, duracion):
    assert create_task(client, "lucia", hora=hora, duracion=duracion).status_code == 201


@pytest.mark.parametrize("hora, duracion", [("08:59", 30), ("14:30", 31), ("15:00", 10), ("17:00", 30)])
def test_el_personal_no_crea_fuera_del_horario(client, count, hora, duracion):
    r = create_task(client, "lucia", hora=hora, duracion=duracion)
    assert r.status_code == 400
    assert error_code(r) == 1023
    assert count("Tasks") == 0


def test_personal_de_otra_clase(client, count):
    r = create_task(client, "pedro", hora="10:00")
    assert r.status_code == 403
    assert error_code(r) == 1019
    assert count("Tasks") == 0


def test_tarea_de_clase_llega_a_todos_sus_alumnos(client, count):
    client.post("/classes/1A/students/ana", headers=as_user("lucia"))
    body = {"task_title": "Plástica", "task_date": LUNES, "task_start_hour": "11:00", "task_duration": 60}
    r = client.post("/classes/1A/tasks", json=body, headers=as_user("lucia"))
    assert r.status_code == 201
    assert count("stud_task WHERE class_name_fk = '1A'") == 2


@pytest.mark.xfail(strict=True, reason="HU-13: al personal se le exige hora de inicio")
def test_el_personal_crea_una_tarea_solo_con_duracion(client):
    assert create_task(client, "lucia", hora=None, duracion=45).status_code == 201


# ----------------------------------------------------------- HU-15: eliminar tareas

def test_el_personal_elimina_una_tarea_del_horario_escolar(client, count):
    tarea = create_task(client, "lucia", hora="10:00").json()["task_id"]
    r = delete_task(client, "lucia", tarea)
    assert r.status_code == 200
    assert count("stud_task WHERE task_id_fk = :t", t=tarea) == 0


def test_el_personal_no_elimina_fuera_del_horario_escolar(client, count):
    tarea = create_task(client, "madre", hora="17:00").json()["task_id"]
    r = delete_task(client, "lucia", tarea)
    assert r.status_code == 400
    assert error_code(r) == 1026
    assert count("stud_task WHERE task_id_fk = :t", t=tarea) == 1


def test_la_familia_elimina_fuera_del_horario_escolar(client, count):
    tarea = create_task(client, "madre", hora="17:00").json()["task_id"]
    assert delete_task(client, "madre", tarea).status_code == 200
    assert count("stud_task WHERE task_id_fk = :t", t=tarea) == 0


def test_la_familia_no_elimina_dentro_del_horario_escolar(client, count):
    tarea = create_task(client, "lucia", hora="10:00").json()["task_id"]
    r = delete_task(client, "madre", tarea)
    assert r.status_code == 400
    assert error_code(r) == 1025
    assert count("stud_task WHERE task_id_fk = :t", t=tarea) == 1


@pytest.mark.parametrize(
    "usuario, hora, autor, permitido",
    [
        ("lucia", "09:00", "lucia", True),
        ("lucia", "14:59", "lucia", True),
        ("madre", "09:00", "lucia", False),
        ("madre", "14:59", "lucia", False),
        ("lucia", "15:00", "madre", False),
        ("madre", "15:00", "madre", True),
    ],
)
def test_limites_del_horario_al_eliminar(client, usuario, hora, autor, permitido):
    tarea = create_task(client, autor, hora=hora, duracion=1).json()["task_id"]
    assert (delete_task(client, usuario, tarea).status_code == 200) is permitido


def test_eliminar_una_tarea_inexistente(client):
    r = delete_task(client, "lucia", 9999)
    assert r.status_code == 404
    assert error_code(r) == 1021


def test_eliminar_con_una_fecha_que_no_es_la_suya(client, count):
    tarea = create_task(client, "lucia", hora="10:00").json()["task_id"]
    r = delete_task(client, "lucia", tarea, fecha="2026-11-17")
    assert r.status_code == 404
    assert count("stud_task WHERE task_id_fk = :t", t=tarea) == 1


def test_eliminar_sin_indicar_la_fecha(client):
    r = client.delete("/student-tasks/students/pablo/1", headers=as_user("lucia"))
    assert r.status_code == 422


@pytest.mark.parametrize("usuario", ["pedro", "otra_madre"])
def test_eliminar_sin_relacion_con_el_alumno(client, count, usuario):
    tarea = create_task(client, "lucia", hora="10:00").json()["task_id"]
    r = delete_task(client, usuario, tarea)
    assert r.status_code == 403
    assert error_code(r) == 1019
    assert count("stud_task WHERE task_id_fk = :t", t=tarea) == 1


@pytest.mark.parametrize("usuario", ["admin", "pablo"])
def test_solo_familia_y_personal_eliminan_de_un_alumno(client, usuario):
    tarea = create_task(client, "lucia", hora="10:00").json()["task_id"]
    r = delete_task(client, usuario, tarea)
    assert r.status_code == 403
    assert error_code(r) == 1017


def test_eliminar_sin_sesion(client):
    r = client.delete("/student-tasks/students/pablo/1", params={"task_date": LUNES})
    assert r.status_code == 401


@pytest.mark.xfail(strict=True, reason="HU-15: la fila de Tasks se queda sin agenda que la use")
def test_eliminar_no_deja_la_tarea_huerfana(client, count):
    tarea = create_task(client, "lucia", hora="10:00").json()["task_id"]
    delete_task(client, "lucia", tarea)
    assert count("Tasks WHERE task_id = :t", t=tarea) == 0
