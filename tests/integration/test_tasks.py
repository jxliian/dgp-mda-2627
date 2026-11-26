"""HU-12 (tarea de la familia), HU-13 (tarea del personal) y HU-15 (eliminar tareas)."""
import pytest
from sqlalchemy import text

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


def test_el_personal_consulta_tareas_del_alumno_por_fecha(client):
    tarea_del_dia = create_task(client, "madre", fecha=LUNES, titulo="Lunes").json()["task_id"]
    create_task(client, "madre", fecha="2026-11-17", titulo="Martes")

    r = client.get(
        "/student-tasks/students/pablo",
        params={"task_date": LUNES},
        headers=as_user("lucia"),
    )

    assert r.status_code == 200
    datos = r.json()
    assert datos["stud_usr_fk"] == "pablo"
    assert datos["task_date"] == LUNES
    assert [task["task_id"] for task in datos["tasks"]] == [tarea_del_dia]
    assert [task["task_title"] for task in datos["tasks"]] == ["Lunes"]


def test_el_tutor_consulta_tareas_del_alumno_por_fecha(client):
    tarea_del_dia = create_task(client, "lucia", hora="10:00", fecha=LUNES, titulo="Clase").json()["task_id"]
    create_task(client, "lucia", hora="11:00", fecha="2026-11-17", titulo="Clase mañana")

    r = client.get(
        "/student-tasks/students/pablo",
        params={"task_date": LUNES},
        headers=as_user("madre"),
    )

    assert r.status_code == 200
    datos = r.json()
    assert datos["stud_usr_fk"] == "pablo"
    assert datos["task_date"] == LUNES
    assert [task["task_id"] for task in datos["tasks"]] == [tarea_del_dia]
    assert [task["task_title"] for task in datos["tasks"]] == ["Clase"]


def test_el_alumno_consulta_su_agenda_por_fecha(client):
    tarea_del_dia = create_task(client, "madre", fecha=LUNES, titulo="Lunes").json()["task_id"]
    create_task(client, "madre", fecha="2026-11-17", titulo="Martes")

    r = client.get(
        "/student-tasks/me",
        params={"task_date": LUNES},
        headers=as_user("pablo"),
    )

    assert r.status_code == 200
    datos = r.json()
    assert datos["stud_usr_fk"] == "pablo"
    assert datos["task_date"] == LUNES
    assert [task["task_id"] for task in datos["tasks"]] == [tarea_del_dia]
    assert [task["task_title"] for task in datos["tasks"]] == ["Lunes"]


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


def test_la_familia_no_crea_un_sabado_por_la_manana(client, count):
    r = create_task(client, "madre", hora="10:00", fecha=SABADO)
    assert r.status_code == 400
    assert error_code(r) == 1024
    assert count("Tasks") == 0


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


def test_el_personal_no_crea_una_tarea_solo_con_duracion(client, count):
    r = create_task(client, "lucia", hora=None, duracion=45)
    assert r.status_code == 400
    assert error_code(r) == 1023
    assert count("Tasks") == 0


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


def test_quitar_tarea_de_agenda_conserva_tarea_compartida_e_historico(client, count):
    historica = create_task(client, "lucia", hora="10:00").json()["task_id"]
    removed = delete_task(client, "lucia", historica, alumno="pablo")
    assert removed.status_code == 200
    assert count("stud_task WHERE task_id_fk = :t", t=historica) == 0
    assert count("Tasks WHERE task_id = :t", t=historica) == 1
    assert count("Generic_Task WHERE task_id_fk = :t", t=historica) == 1

    client.post("/classes/1A/students/ana", headers=as_user("lucia"))
    r = client.post(
        "/classes/1A/tasks",
        json={
            "task_title": "Tarea compartida",
            "task_date": LUNES,
            "task_start_hour": "10:00",
            "task_duration": 45,
        },
        headers=as_user("lucia"),
    )
    assert r.status_code == 201
    tarea = r.json()["task_id"]

    removed = delete_task(client, "lucia", tarea, alumno="pablo")
    assert removed.status_code == 200
    assert count("stud_task WHERE task_id_fk = :t AND stud_usr_fk = 'pablo'", t=tarea) == 0
    assert count("stud_task WHERE task_id_fk = :t AND stud_usr_fk = 'ana'", t=tarea) == 1
    assert count("Tasks WHERE task_id = :t", t=tarea) == 1

    removed = delete_task(client, "lucia", tarea, alumno="ana")
    assert removed.status_code == 200
    assert count("stud_task WHERE task_id_fk = :t", t=tarea) == 0
    assert count("Tasks WHERE task_id = :t", t=tarea) == 1
    assert count("Generic_Task WHERE task_id_fk = :t", t=tarea) == 1


# ------------------------------------------------------ Pasos de tareas (HU-16)

def crear_paso(client, usuario, tarea, descripcion="Preparar el material"):
    return client.post(
        f"/student-tasks/{tarea}/steps",
        json={"step_description": descripcion},
        headers=as_user(usuario),
    )


def crear_tarea_de_clase(client, clase="1A", usuario="lucia"):
    return client.post(
        f"/classes/{clase}/tasks",
        json={
            "task_title": "Actividad con pasos",
            "task_date": LUNES,
            "task_start_hour": "10:00",
            "task_duration": 30,
        },
        headers=as_user(usuario),
    )


def test_el_tutor_anade_varios_pasos_en_orden_a_su_tarea(client, count):
    tarea = create_task(client, "madre", titulo="Rutina de tarde").json()["task_id"]

    primero = crear_paso(client, "madre", tarea, "Preparar la mochila")
    segundo = crear_paso(client, "madre", tarea, "Dejar la mochila en la entrada")

    assert primero.status_code == segundo.status_code == 201
    assert primero.json()["step_index"] == 0
    assert segundo.json()["step_index"] == 1
    assert primero.json()["step_finished"] is False
    assert count("Steps WHERE generic_task_id_fk = :t", t=tarea) == 2


def test_el_personal_anade_pasos_a_su_tarea_individual(client, count):
    tarea = create_task(client, "lucia", hora="10:00", titulo="Lectura").json()["task_id"]

    r = crear_paso(client, "lucia", tarea, "Leer la página 4")

    assert r.status_code == 201
    assert r.json()["generic_task_id_fk"] == tarea
    assert r.json()["step_description"] == "Leer la página 4"
    assert r.json()["step_index"] == 0
    assert count("Steps WHERE generic_task_id_fk = :t", t=tarea) == 1


def test_el_alumno_anade_pasos_a_su_tarea_propia(client, count):
    creada = client.post(
        "/student-tasks/me",
        json={
            "task_title": "Dibujo",
            "task_date": LUNES,
            "task_start_hour": "17:00",
            "task_duration": 30,
        },
        headers=as_user("pablo"),
    )
    assert creada.status_code == 201
    tarea = creada.json()["task_id"]

    r = crear_paso(client, "pablo", tarea, "Sacar los lápices")

    assert r.status_code == 201
    assert r.json()["step_index"] == 0
    assert count("Steps WHERE generic_task_id_fk = :t", t=tarea) == 1


def test_el_personal_anade_pasos_a_una_tarea_de_clase(client, count):
    creada = crear_tarea_de_clase(client)
    assert creada.status_code == 201
    tarea = creada.json()["task_id"]

    r = client.post(
        f"/classes/1A/tasks/{tarea}/steps",
        json={"step_description": "Abrir el cuaderno"},
        headers=as_user("lucia"),
    )

    assert r.status_code == 201
    assert r.json()["class_name"] == "1A"
    assert r.json()["generic_task_id_fk"] == tarea
    assert r.json()["step_index"] == 0
    assert count("Steps WHERE generic_task_id_fk = :t", t=tarea) == 1


def test_cualquier_personal_asignado_a_la_clase_puede_anadir_pasos(client):
    tarea = crear_tarea_de_clase(client).json()["task_id"]
    assert client.post("/classes/1A/staff/pedro", headers=as_user("admin")).status_code == 200

    r = client.post(
        f"/classes/1A/tasks/{tarea}/steps",
        json={"step_description": "Revisar la actividad"},
        headers=as_user("pedro"),
    )

    assert r.status_code == 201
    assert r.json()["step_index"] == 0


def test_el_personal_no_anade_pasos_a_una_clase_ajena(client, count):
    tarea = crear_tarea_de_clase(client).json()["task_id"]

    r = client.post(
        f"/classes/1A/tasks/{tarea}/steps",
        json={"step_description": "Paso no autorizado"},
        headers=as_user("pedro"),
    )

    assert r.status_code == 403
    assert error_code(r) == 1032
    assert count("Steps WHERE generic_task_id_fk = :t", t=tarea) == 0


def test_el_personal_no_anade_pasos_a_una_tarea_de_otra_clase(client, count):
    tarea = crear_tarea_de_clase(client).json()["task_id"]

    r = client.post(
        f"/classes/2B/tasks/{tarea}/steps",
        json={"step_description": "Paso en clase incorrecta"},
        headers=as_user("pedro"),
    )

    assert r.status_code == 404
    assert error_code(r) == 1021
    assert count("Steps WHERE generic_task_id_fk = :t", t=tarea) == 0


@pytest.mark.parametrize("usuario", ["otra_madre", "ana"])
def test_tutor_y_alumno_no_anaden_pasos_a_tareas_ajenas(client, usuario, count):
    tarea = create_task(client, "madre").json()["task_id"]

    r = crear_paso(client, usuario, tarea)

    assert r.status_code == 404
    assert error_code(r) == 1021
    assert count("Steps WHERE generic_task_id_fk = :t", t=tarea) == 0


def test_el_personal_no_anade_pasos_a_una_tarea_individual_ajena(client, count):
    tarea = create_task(client, "madre").json()["task_id"]

    r = crear_paso(client, "lucia", tarea)

    assert r.status_code == 404
    assert error_code(r) == 1021
    assert count("Steps WHERE generic_task_id_fk = :t", t=tarea) == 0


@pytest.mark.parametrize(
    "payload",
    [
        {"step_description": ""},
        {"step_description": "   "},
        {"step_description": "Paso", "campo_extra": True},
    ],
)
def test_no_se_aceptan_descripciones_de_paso_invalidas(client, count, payload):
    tarea = create_task(client, "madre").json()["task_id"]

    r = client.post(
        f"/student-tasks/{tarea}/steps", json=payload, headers=as_user("madre")
    )

    assert r.status_code == 422
    assert error_code(r) == 1005
    assert count("Steps WHERE generic_task_id_fk = :t", t=tarea) == 0


def test_anadir_paso_requiere_sesion(client):
    tarea = create_task(client, "madre").json()["task_id"]

    r = client.post(
        f"/student-tasks/{tarea}/steps", json={"step_description": "Paso"}
    )

    assert r.status_code == 401
    assert error_code(r) == 1002


@pytest.mark.parametrize("usuario", ["admin", "otra_madre", "pablo"])
def test_solo_el_personal_asignado_puede_anadir_pasos_a_tareas_de_clase(client, usuario):
    tarea = crear_tarea_de_clase(client).json()["task_id"]

    r = client.post(
        f"/classes/1A/tasks/{tarea}/steps",
        json={"step_description": "Paso no permitido"},
        headers=as_user(usuario),
    )

    assert r.status_code == 403
    assert error_code(r) == 1032


def eliminar_paso_individual(client, usuario, tarea, paso):
    return client.delete(
        f"/student-tasks/{tarea}/steps/{paso}", headers=as_user(usuario)
    )


def test_el_personal_elimina_un_paso_y_se_reindexa_el_resto(client, engine, count):
    tarea = create_task(client, "lucia", hora="10:00").json()["task_id"]
    pasos = [
        crear_paso(client, "lucia", tarea, descripcion).json()
        for descripcion in ("Paso A", "Paso B", "Paso C")
    ]

    r = eliminar_paso_individual(client, "lucia", tarea, pasos[1]["step_id"])

    assert r.status_code == 200
    assert r.json()["task_id"] == tarea
    assert r.json()["deleted_step_id"] == pasos[1]["step_id"]
    assert r.json()["deleted_step_index"] == 1
    assert r.json()["remaining_steps"] == 2
    assert count("Steps WHERE step_id = :s", s=pasos[1]["step_id"]) == 0
    with engine.connect() as conn:
        restantes = conn.execute(
            text(
                "SELECT step_description, step_index FROM Steps "
                "WHERE generic_task_id_fk = :t ORDER BY step_index"
            ),
            {"t": tarea},
        ).all()
    assert [(fila[0], fila[1]) for fila in restantes] == [("Paso A", 0), ("Paso C", 1)]


def test_el_personal_no_elimina_pasos_de_una_tarea_fuera_del_horario(client, engine, count):
    tarea = create_task(client, "lucia", hora="10:00").json()["task_id"]
    paso = crear_paso(client, "lucia", tarea).json()["step_id"]
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE Tasks SET task_start_hour = '16:00' WHERE task_id = :t"),
            {"t": tarea},
        )

    r = eliminar_paso_individual(client, "lucia", tarea, paso)

    assert r.status_code == 400
    assert error_code(r) == 1026
    assert count("Steps WHERE step_id = :s", s=paso) == 1


def test_el_tutor_elimina_pasos_de_una_tarea_fuera_del_horario(client, count):
    tarea = create_task(client, "madre", hora="17:00").json()["task_id"]
    primero = crear_paso(client, "madre", tarea, "Paso A").json()["step_id"]
    segundo = crear_paso(client, "madre", tarea, "Paso B").json()["step_id"]

    r = eliminar_paso_individual(client, "madre", tarea, primero)

    assert r.status_code == 200
    assert r.json()["deleted_step_id"] == primero
    assert r.json()["remaining_steps"] == 1
    assert count("Steps WHERE step_id = :s", s=primero) == 0
    assert count("Steps WHERE step_id = :s", s=segundo) == 1


def test_el_tutor_no_elimina_pasos_de_una_tarea_dentro_del_horario(client, engine, count):
    tarea = create_task(client, "madre", hora="17:00").json()["task_id"]
    paso = crear_paso(client, "madre", tarea).json()["step_id"]
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE Tasks SET task_start_hour = '10:00' WHERE task_id = :t"),
            {"t": tarea},
        )

    r = eliminar_paso_individual(client, "madre", tarea, paso)

    assert r.status_code == 400
    assert error_code(r) == 1025
    assert count("Steps WHERE step_id = :s", s=paso) == 1


def test_el_personal_elimina_un_paso_de_una_tarea_de_clase(client, engine, count):
    tarea = crear_tarea_de_clase(client).json()["task_id"]
    primero = client.post(
        f"/classes/1A/tasks/{tarea}/steps",
        json={"step_description": "Paso A"},
        headers=as_user("lucia"),
    ).json()
    segundo = client.post(
        f"/classes/1A/tasks/{tarea}/steps",
        json={"step_description": "Paso B"},
        headers=as_user("lucia"),
    ).json()

    r = client.delete(
        f"/classes/1A/tasks/{tarea}/steps/{primero['step_id']}",
        headers=as_user("lucia"),
    )

    assert r.status_code == 200
    assert r.json()["class_name"] == "1A"
    assert r.json()["deleted_step_id"] == primero["step_id"]
    assert r.json()["remaining_steps"] == 1
    assert count("Steps WHERE step_id = :s", s=primero["step_id"]) == 0
    with engine.connect() as conn:
        indice = conn.execute(
            text("SELECT step_index FROM Steps WHERE step_id = :s"),
            {"s": segundo["step_id"]},
        ).scalar_one()
    assert indice == 0


def test_el_personal_no_elimina_pasos_de_una_tarea_de_clase_ajena(client, count):
    tarea = crear_tarea_de_clase(client).json()["task_id"]
    paso = client.post(
        f"/classes/1A/tasks/{tarea}/steps",
        json={"step_description": "Paso"},
        headers=as_user("lucia"),
    ).json()["step_id"]

    r = client.delete(
        f"/classes/1A/tasks/{tarea}/steps/{paso}", headers=as_user("pedro")
    )

    assert r.status_code == 403
    assert error_code(r) == 1032
    assert count("Steps WHERE step_id = :s", s=paso) == 1


def test_no_se_elimina_un_paso_que_pertenece_a_otra_tarea(client, count):
    tarea_a = create_task(client, "lucia", hora="10:00", titulo="Tarea A").json()["task_id"]
    tarea_b = create_task(client, "lucia", hora="11:00", titulo="Tarea B").json()["task_id"]
    paso_b = crear_paso(client, "lucia", tarea_b, "Paso de B").json()["step_id"]

    r = eliminar_paso_individual(client, "lucia", tarea_a, paso_b)

    assert r.status_code == 404
    assert error_code(r) == 1021
    assert count("Steps WHERE step_id = :s", s=paso_b) == 1


def test_no_se_elimina_un_paso_inexistente(client):
    tarea = create_task(client, "lucia", hora="10:00").json()["task_id"]

    r = eliminar_paso_individual(client, "lucia", tarea, 9999)

    assert r.status_code == 404
    assert error_code(r) == 1021


def test_eliminar_un_paso_requiere_sesion(client):
    tarea = create_task(client, "lucia", hora="10:00").json()["task_id"]
    paso = crear_paso(client, "lucia", tarea).json()["step_id"]

    r = client.delete(f"/student-tasks/{tarea}/steps/{paso}")

    assert r.status_code == 401
    assert error_code(r) == 1002


def test_el_alumno_elimina_pasos_de_una_tarea_propia(client, count):
    creada = client.post(
        "/student-tasks/me",
        json={
            "task_title": "Tarea propia",
            "task_date": LUNES,
            "task_start_hour": "17:00",
            "task_duration": 30,
        },
        headers=as_user("pablo"),
    )
    assert creada.status_code == 201
    tarea = creada.json()["task_id"]
    paso = crear_paso(client, "pablo", tarea).json()["step_id"]

    r = eliminar_paso_individual(client, "pablo", tarea, paso)

    assert r.status_code == 200
    assert r.json()["deleted_step_id"] == paso
    assert r.json()["remaining_steps"] == 0
    assert count("Steps WHERE step_id = :s", s=paso) == 0


def test_el_alumno_no_elimina_pasos_de_una_tarea_ajena(client, count):
    tarea = create_task(client, "madre").json()["task_id"]
    paso = crear_paso(client, "madre", tarea).json()["step_id"]

    r = eliminar_paso_individual(client, "pablo", tarea, paso)

    assert r.status_code == 404
    assert error_code(r) == 1021
    assert count("Steps WHERE step_id = :s", s=paso) == 1


def test_el_alumno_no_elimina_pasos_si_no_puede_modificar_tareas(client, engine, count):
    creada = client.post(
        "/student-tasks/me",
        json={
            "task_title": "Tarea propia",
            "task_date": LUNES,
            "task_start_hour": "17:00",
            "task_duration": 30,
        },
        headers=as_user("pablo"),
    )
    tarea = creada.json()["task_id"]
    paso = crear_paso(client, "pablo", tarea).json()["step_id"]
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE Student SET stud_access_task_mod = FALSE WHERE stud_usr = 'pablo'")
        )

    r = eliminar_paso_individual(client, "pablo", tarea, paso)

    assert r.status_code == 403
    assert error_code(r) == 1039
    assert count("Steps WHERE step_id = :s", s=paso) == 1
