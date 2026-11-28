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


def update_task(
    client,
    usuario,
    task_id,
    alumno="pablo",
    fecha_origen=LUNES,
    fecha_nueva=LUNES,
    hora="18:00",
    duracion=45,
    titulo="Tarea modificada",
    alternativa=None,
):
    body = {
        "task_title": titulo,
        "task_date": fecha_nueva,
        "task_duration": duracion,
        "task_start_hour": hora,
        "alt_task_id_fk": alternativa,
    }
    return client.put(
        f"/student-tasks/students/{alumno}/{task_id}",
        params={"task_date": fecha_origen},
        json=body,
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


# -------------------------------------------------------- Consultar pasos

def test_el_tutor_consulta_pasos_ordenados_y_tareas_sin_pasos(client):
    con_pasos = create_task(client, "madre", titulo="Rutina con pasos").json()["task_id"]
    sin_pasos = create_task(client, "madre", titulo="Rutina sencilla").json()["task_id"]
    primero = crear_paso(client, "madre", con_pasos, "Preparar").json()
    segundo = crear_paso(client, "madre", con_pasos, "Salir").json()

    r = client.get(
        "/student-tasks/students/pablo",
        params={"task_date": LUNES},
        headers=as_user("madre"),
    )

    assert r.status_code == 200
    tareas = {tarea["task_id"]: tarea for tarea in r.json()["tasks"]}
    assert [paso["step_id"] for paso in tareas[con_pasos]["steps"]] == [
        primero["step_id"], segundo["step_id"]
    ]
    assert [paso["step_index"] for paso in tareas[con_pasos]["steps"]] == [0, 1]
    assert tareas[sin_pasos]["steps"] == []


def test_el_personal_consulta_el_orden_actualizado_de_pasos_individuales(client):
    tarea = create_task(client, "lucia", hora="10:00", titulo="Lectura").json()["task_id"]
    pasos = [
        crear_paso(client, "lucia", tarea, descripcion).json()
        for descripcion in ("Leer", "Responder", "Revisar")
    ]
    orden_nuevo = [pasos[2]["step_id"], pasos[0]["step_id"], pasos[1]["step_id"]]
    actualizado = client.put(
        f"/student-tasks/{tarea}/steps/order",
        json={"step_ids": orden_nuevo},
        headers=as_user("lucia"),
    )
    assert actualizado.status_code == 200

    r = client.get(
        "/student-tasks/students/pablo",
        params={"task_date": LUNES},
        headers=as_user("lucia"),
    )

    assert r.status_code == 200
    tarea_consultada = next(item for item in r.json()["tasks"] if item["task_id"] == tarea)
    assert [paso["step_id"] for paso in tarea_consultada["steps"]] == orden_nuevo
    assert [paso["step_index"] for paso in tarea_consultada["steps"]] == [0, 1, 2]


def test_el_alumno_consulta_los_pasos_de_su_agenda(client):
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
    primero = crear_paso(client, "pablo", tarea, "Empezar").json()
    segundo = crear_paso(client, "pablo", tarea, "Terminar").json()

    r = client.get(
        "/student-tasks/me", params={"task_date": LUNES}, headers=as_user("pablo")
    )

    assert r.status_code == 200
    tarea_consultada = next(item for item in r.json()["tasks"] if item["task_id"] == tarea)
    assert [paso["step_id"] for paso in tarea_consultada["steps"]] == [
        primero["step_id"], segundo["step_id"]
    ]
    assert [paso["step_description"] for paso in tarea_consultada["steps"]] == [
        "Empezar", "Terminar"
    ]


def test_el_personal_consulta_pasos_de_tareas_de_clase_y_lista_vacia(client):
    con_pasos = crear_tarea_de_clase(client).json()["task_id"]
    sin_pasos = crear_tarea_de_clase(client).json()["task_id"]
    primero = client.post(
        f"/classes/1A/tasks/{con_pasos}/steps",
        json={"step_description": "Abrir el libro"},
        headers=as_user("lucia"),
    ).json()
    segundo = client.post(
        f"/classes/1A/tasks/{con_pasos}/steps",
        json={"step_description": "Leer la página"},
        headers=as_user("lucia"),
    ).json()

    r = client.get("/classes/1A/tasks", headers=as_user("lucia"))

    assert r.status_code == 200
    tareas = {tarea["task_id"]: tarea for tarea in r.json()["tasks"]}
    assert [paso["step_id"] for paso in tareas[con_pasos]["steps"]] == [
        primero["step_id"], segundo["step_id"]
    ]
    assert tareas[sin_pasos]["steps"] == []


def test_el_tutor_no_consulta_pasos_de_un_alumno_no_asociado(client):
    tarea = create_task(client, "madre").json()["task_id"]
    crear_paso(client, "madre", tarea)

    r = client.get(
        "/student-tasks/students/ana",
        params={"task_date": LUNES},
        headers=as_user("madre"),
    )

    assert r.status_code == 403
    assert error_code(r) == 1019


def test_el_personal_no_consulta_pasos_de_un_alumno_de_otra_clase(client):
    tarea = create_task(client, "madre").json()["task_id"]
    crear_paso(client, "madre", tarea)

    r = client.get(
        "/student-tasks/students/pablo",
        params={"task_date": LUNES},
        headers=as_user("pedro"),
    )

    assert r.status_code == 403
    assert error_code(r) == 1019


@pytest.mark.parametrize("usuario", ["pedro", "madre", "pablo", "admin"])
def test_solo_personal_asignado_consulta_pasos_de_tareas_de_clase(client, usuario):
    crear_tarea_de_clase(client)

    r = client.get("/classes/1A/tasks", headers=as_user(usuario))

    assert r.status_code == 403
    assert error_code(r) == 1032


# ---------------------------------------------------------- Modificar pasos

def modificar_paso_individual(client, usuario, tarea, paso, payload):
    return client.put(
        f"/student-tasks/{tarea}/steps/{paso}",
        json=payload,
        headers=as_user(usuario),
    )


def test_el_tutor_modifica_contenido_y_orden_y_el_alumno_ve_el_cambio(client, engine):
    tarea = create_task(client, "madre", titulo="Rutina").json()["task_id"]
    pasos = [
        crear_paso(client, "madre", tarea, descripcion).json()
        for descripcion in ("Preparar", "Salir", "Volver")
    ]
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE Steps SET step_finished = TRUE WHERE step_id = :s"),
            {"s": pasos[1]["step_id"]},
        )

    actualizado = modificar_paso_individual(
        client,
        "madre",
        tarea,
        pasos[1]["step_id"],
        {"step_description": "Salir con la mochila", "step_index": 2},
    )
    assert actualizado.status_code == 200
    assert actualizado.json()["step_description"] == "Salir con la mochila"
    assert actualizado.json()["step_index"] == 2
    assert actualizado.json()["step_finished"] is True

    consulta = client.get(
        "/student-tasks/students/pablo",
        params={"task_date": LUNES},
        headers=as_user("madre"),
    )
    tarea_consultada = next(item for item in consulta.json()["tasks"] if item["task_id"] == tarea)
    assert [paso["step_description"] for paso in tarea_consultada["steps"]] == [
        "Preparar", "Volver", "Salir con la mochila"
    ]
    assert [paso["step_index"] for paso in tarea_consultada["steps"]] == [0, 1, 2]


def test_el_personal_modifica_contenido_y_orden_de_su_tarea_individual(client):
    tarea = create_task(client, "lucia", hora="10:00", titulo="Lectura").json()["task_id"]
    pasos = [
        crear_paso(client, "lucia", tarea, descripcion).json()
        for descripcion in ("Leer", "Responder", "Revisar")
    ]

    r = modificar_paso_individual(
        client,
        "lucia",
        tarea,
        pasos[1]["step_id"],
        {"step_description": "Responder con frases completas", "step_index": 0},
    )

    assert r.status_code == 200
    assert r.json()["step_description"] == "Responder con frases completas"
    assert r.json()["step_index"] == 0
    consulta = client.get(
        "/student-tasks/students/pablo",
        params={"task_date": LUNES},
        headers=as_user("lucia"),
    )
    tarea_consultada = next(item for item in consulta.json()["tasks"] if item["task_id"] == tarea)
    assert [paso["step_id"] for paso in tarea_consultada["steps"]] == [
        pasos[1]["step_id"], pasos[0]["step_id"], pasos[2]["step_id"]
    ]


def test_el_alumno_modifica_pasos_de_su_tarea_propia(client):
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
    primero = crear_paso(client, "pablo", tarea, "Empezar").json()
    segundo = crear_paso(client, "pablo", tarea, "Terminar").json()

    r = modificar_paso_individual(
        client, "pablo", tarea, segundo["step_id"], {"step_description": "Revisar y terminar", "step_index": 0}
    )

    assert r.status_code == 200
    assert r.json()["step_description"] == "Revisar y terminar"
    assert r.json()["step_index"] == 0
    consulta = client.get(
        "/student-tasks/me", params={"task_date": LUNES}, headers=as_user("pablo")
    )
    tarea_consultada = next(item for item in consulta.json()["tasks"] if item["task_id"] == tarea)
    assert [paso["step_id"] for paso in tarea_consultada["steps"]] == [
        segundo["step_id"], primero["step_id"]
    ]


def test_el_personal_modifica_pasos_de_una_tarea_de_clase(client):
    tarea = crear_tarea_de_clase(client).json()["task_id"]
    primero = client.post(
        f"/classes/1A/tasks/{tarea}/steps",
        json={"step_description": "Abrir el libro"},
        headers=as_user("lucia"),
    ).json()
    segundo = client.post(
        f"/classes/1A/tasks/{tarea}/steps",
        json={"step_description": "Leer"},
        headers=as_user("lucia"),
    ).json()

    r = client.put(
        f"/classes/1A/tasks/{tarea}/steps/{segundo['step_id']}",
        json={"step_description": "Leer el apartado indicado", "step_index": 0},
        headers=as_user("lucia"),
    )

    assert r.status_code == 200
    assert r.json()["class_name"] == "1A"
    assert r.json()["step_description"] == "Leer el apartado indicado"
    assert r.json()["step_index"] == 0
    consulta = client.get("/classes/1A/tasks", headers=as_user("lucia"))
    tarea_consultada = next(item for item in consulta.json()["tasks"] if item["task_id"] == tarea)
    assert [paso["step_id"] for paso in tarea_consultada["steps"]] == [
        segundo["step_id"], primero["step_id"]
    ]


def test_el_personal_no_modifica_una_tarea_de_clase_que_no_creo(client, count):
    tarea = crear_tarea_de_clase(client).json()["task_id"]
    paso = client.post(
        f"/classes/1A/tasks/{tarea}/steps",
        json={"step_description": "Paso inicial"},
        headers=as_user("lucia"),
    ).json()["step_id"]
    assert client.post("/classes/1A/staff/pedro", headers=as_user("admin")).status_code == 200

    r = client.put(
        f"/classes/1A/tasks/{tarea}/steps/{paso}",
        json={"step_description": "Cambio no autorizado"},
        headers=as_user("pedro"),
    )

    assert r.status_code == 404
    assert error_code(r) == 1021
    assert count("Steps WHERE step_id = :s AND step_description = 'Paso inicial'", s=paso) == 1


def test_el_personal_no_modifica_pasos_de_una_tarea_individual_ajena(client, count):
    tarea = create_task(client, "madre").json()["task_id"]
    paso = crear_paso(client, "madre", tarea).json()["step_id"]

    r = modificar_paso_individual(
        client, "lucia", tarea, paso, {"step_description": "Cambio no autorizado"}
    )

    assert r.status_code == 404
    assert error_code(r) == 1021
    assert count("Steps WHERE step_id = :s AND step_description = 'Preparar el material'", s=paso) == 1


def test_no_se_modifica_un_paso_que_pertenece_a_otra_tarea(client, count):
    tarea_a = create_task(client, "lucia", hora="10:00", titulo="Tarea A").json()["task_id"]
    tarea_b = create_task(client, "lucia", hora="11:00", titulo="Tarea B").json()["task_id"]
    paso_b = crear_paso(client, "lucia", tarea_b, "Paso de B").json()["step_id"]

    r = modificar_paso_individual(
        client, "lucia", tarea_a, paso_b, {"step_description": "No debe cambiar"}
    )

    assert r.status_code == 404
    assert error_code(r) == 1021
    assert count("Steps WHERE step_id = :s AND step_description = 'Paso de B'", s=paso_b) == 1


@pytest.mark.parametrize(
    "payload, estado, codigo",
    [
        ({}, 400, 1012),
        ({"step_description": "   "}, 422, 1005),
        ({"step_index": -1}, 422, 1005),
        ({"step_description": "Válido", "extra": True}, 422, 1005),
    ],
)
def test_modificar_paso_rechaza_payloads_invalidos(client, count, payload, estado, codigo):
    tarea = create_task(client, "lucia", hora="10:00").json()["task_id"]
    paso = crear_paso(client, "lucia", tarea).json()["step_id"]

    r = modificar_paso_individual(client, "lucia", tarea, paso, payload)

    assert r.status_code == estado
    assert error_code(r) == codigo
    assert count("Steps WHERE step_id = :s AND step_description = 'Preparar el material'", s=paso) == 1


@pytest.mark.parametrize(
    "creador, hora_inicial, hora_fuera, codigo",
    [("lucia", "10:00", "16:00", 1023), ("madre", "17:00", "10:00", 1024)],
)
def test_modificar_pasos_respeta_el_horario_escolar(
    client, engine, count, creador, hora_inicial, hora_fuera, codigo
):
    tarea = create_task(client, creador, hora=hora_inicial).json()["task_id"]
    paso = crear_paso(client, creador, tarea).json()["step_id"]
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE Tasks SET task_start_hour = :hour WHERE task_id = :task_id"),
            {"hour": hora_fuera, "task_id": tarea},
        )

    r = modificar_paso_individual(
        client, creador, tarea, paso, {"step_description": "Cambio fuera de horario"}
    )

    assert r.status_code == 400
    assert error_code(r) == codigo
    assert count("Steps WHERE step_id = :s AND step_description = 'Preparar el material'", s=paso) == 1


def test_el_alumno_no_modifica_pasos_si_no_puede_modificar_tareas(client, engine, count):
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

    r = modificar_paso_individual(
        client, "pablo", tarea, paso, {"step_description": "No autorizado"}
    )

    assert r.status_code == 403
    assert error_code(r) == 1039
    assert count("Steps WHERE step_id = :s AND step_description = 'Preparar el material'", s=paso) == 1


def test_modificar_paso_requiere_sesion(client):
    tarea = create_task(client, "lucia", hora="10:00").json()["task_id"]
    paso = crear_paso(client, "lucia", tarea).json()["step_id"]

    r = client.put(
        f"/student-tasks/{tarea}/steps/{paso}",
        json={"step_description": "Cambio"},
    )

    assert r.status_code == 401
    assert error_code(r) == 1002


@pytest.mark.parametrize("usuario", ["pedro", "madre", "pablo", "admin"])
def test_solo_personal_asignado_y_creador_modifica_pasos_de_clase(client, usuario):
    tarea = crear_tarea_de_clase(client).json()["task_id"]
    paso = client.post(
        f"/classes/1A/tasks/{tarea}/steps",
        json={"step_description": "Paso inicial"},
        headers=as_user("lucia"),
    ).json()["step_id"]

    r = client.put(
        f"/classes/1A/tasks/{tarea}/steps/{paso}",
        json={"step_description": "Cambio"},
        headers=as_user(usuario),
    )

    if usuario == "pedro":
        assert r.status_code == 403
        assert error_code(r) == 1032
    else:
        assert r.status_code == 403
        assert error_code(r) == 1032


def test_indice_superior_al_maximo_se_limita_al_final(client):
    tarea = create_task(client, "lucia", hora="10:00").json()["task_id"]
    primero = crear_paso(client, "lucia", tarea, "Primero").json()["step_id"]
    segundo = crear_paso(client, "lucia", tarea, "Segundo").json()["step_id"]

    r = modificar_paso_individual(client, "lucia", tarea, primero, {"step_index": 999})

    assert r.status_code == 200
    assert r.json()["step_index"] == 1
    consulta = client.get(
        "/student-tasks/students/pablo",
        params={"task_date": LUNES},
        headers=as_user("lucia"),
    )
    tarea_consultada = next(item for item in consulta.json()["tasks"] if item["task_id"] == tarea)
    assert [paso["step_id"] for paso in tarea_consultada["steps"]] == [segundo, primero]
# ----------------------------------------------------------- Modificar tareas individuales

def test_el_tutor_modifica_una_tarea_y_se_refleja_en_la_agenda(client, count):
    tarea = create_task(
        client, "madre", hora="17:00", duracion=20, fecha=LUNES, titulo="Leer cuento"
    ).json()["task_id"]

    r = update_task(
        client,
        "madre",
        tarea,
        fecha_origen=LUNES,
        fecha_nueva="2026-11-17",
        hora="18:30",
        duracion=35,
        titulo="Leer cómic",
    )

    assert r.status_code == 200
    datos = r.json()
    assert datos["task_id"] == tarea
    assert datos["task_title"] == "Leer cómic"
    assert datos["task_date"] == "2026-11-17"
    assert datos["task_start_hour"] == "18:30:00"
    assert datos["task_duration"] == 35
    assert datos["stud_usr_fk"] == "pablo"
    assert count("stud_task WHERE task_id_fk = :t AND task_date = :d", t=tarea, d=LUNES) == 0
    assert count("stud_task WHERE task_id_fk = :t AND task_date = '2026-11-17'", t=tarea) == 1

    agenda_nueva = client.get(
        "/student-tasks/students/pablo",
        params={"task_date": "2026-11-17"},
        headers=as_user("madre"),
    )
    assert agenda_nueva.status_code == 200
    assert [t["task_title"] for t in agenda_nueva.json()["tasks"]] == ["Leer cómic"]


def test_el_tutor_puede_quitar_hora_y_reordena_la_agenda(client, engine):
    from sqlalchemy import text

    primera = create_task(client, "madre", hora="16:00", titulo="Primera").json()["task_id"]
    segunda = create_task(client, "madre", hora="18:00", titulo="Segunda").json()["task_id"]

    r = update_task(client, "madre", primera, hora=None, duracion=25, titulo="Sin hora")
    assert r.status_code == 200
    assert r.json()["task_start_hour"] is None

    with engine.connect() as conn:
        orden = conn.execute(
            text(
                "SELECT task_id_fk FROM stud_task "
                "WHERE stud_usr_fk = 'pablo' AND task_date = :d ORDER BY task_index"
            ),
            {"d": LUNES},
        ).scalars().all()
    assert orden == [segunda, primera]


@pytest.mark.parametrize(
    "hora, duracion",
    [("08:30", 30), ("15:00", 30), ("17:00", 45), (None, 20)],
)
def test_el_tutor_modifica_tareas_fuera_del_horario_escolar(client, hora, duracion):
    tarea = create_task(client, "madre", hora="17:00", titulo="Tarde").json()["task_id"]
    r = update_task(client, "madre", tarea, hora=hora, duracion=duracion, titulo="Actualizada")
    assert r.status_code == 200
    assert r.json()["task_title"] == "Actualizada"


@pytest.mark.parametrize(
    "hora, duracion",
    [("08:30", 31), ("09:00", 10), ("10:00", 30), ("14:59", 1), ("23:00", 601)],
)
def test_el_tutor_no_modifica_hacia_el_horario_escolar(client, engine, hora, duracion):
    from sqlalchemy import text

    tarea = create_task(client, "madre", hora="17:00", duracion=20, titulo="Tarde").json()["task_id"]
    r = update_task(client, "madre", tarea, hora=hora, duracion=duracion, titulo="Intento")
    assert r.status_code == 400
    assert error_code(r) == 1024
    assert "horario escolar" in r.json()["details"].lower()
    with engine.connect() as conn:
        titulo = conn.execute(
            text("SELECT task_title FROM Tasks WHERE task_id = :t"), {"t": tarea}
        ).scalar_one()
    assert titulo == "Tarde"


def test_el_tutor_no_modifica_una_tarea_ya_programada_en_horario_escolar(client, engine):
    from sqlalchemy import text

    with engine.begin() as conn:
        task_id = conn.execute(
            text(
                "INSERT INTO Tasks (task_title, task_start_hour, task_duration, task_creator) "
                "VALUES ('En clase', '10:00:00', 30, 'madre') RETURNING task_id"
            )
        ).scalar_one()
        conn.execute(text("INSERT INTO Generic_Task (task_id_fk) VALUES (:t)"), {"t": task_id})
        conn.execute(
            text(
                "INSERT INTO stud_task (stud_usr_fk, task_id_fk, task_index, task_date) "
                "VALUES ('pablo', :t, 0, :d)"
            ),
            {"t": task_id, "d": LUNES},
        )

    r = update_task(client, "madre", task_id, hora="17:00", duracion=30, titulo="Movida")
    assert r.status_code == 400
    assert error_code(r) == 1024
    assert "horario escolar" in r.json()["details"].lower()


def test_el_tutor_no_puede_modificar_tarea_creada_por_personal(client, engine):
    from sqlalchemy import text

    # 1. Tarea individual creada por el personal en horario escolar.
    tarea_escolar = create_task(client, "lucia", hora="10:00", titulo="Clase").json()["task_id"]
    r = update_task(client, "madre", tarea_escolar, hora="17:00", duracion=30, titulo="Cambiada")
    assert r.status_code == 403
    assert error_code(r) == 1041
    assert "personal" in r.json()["details"].lower()

    # 2. Tarea creada por el personal incluso si estuviera fuera del horario escolar.
    with engine.begin() as conn:
        tarea_staff_tarde = conn.execute(
            text(
                "INSERT INTO Tasks (task_title, task_start_hour, task_duration, task_creator) "
                "VALUES ('Apoyo personal', '17:00:00', 20, 'lucia') RETURNING task_id"
            )
        ).scalar_one()
        conn.execute(
            text("INSERT INTO Generic_Task (task_id_fk) VALUES (:t)"),
            {"t": tarea_staff_tarde},
        )
        conn.execute(
            text(
                "INSERT INTO stud_task (stud_usr_fk, task_id_fk, task_index, task_date) "
                "VALUES ('pablo', :t, 1, :d)"
            ),
            {"t": tarea_staff_tarde, "d": LUNES},
        )

    r2 = update_task(client, "madre", tarea_staff_tarde, hora="18:00", duracion=25, titulo="Editada")
    assert r2.status_code == 403
    assert error_code(r2) == 1041
    assert "personal" in r2.json()["details"].lower()

    # 3. Tarea grupal de clase creada por el personal.
    grupal = client.post(
        "/classes/1A/tasks",
        json={
            "task_title": "Plástica",
            "task_date": LUNES,
            "task_start_hour": "11:00",
            "task_duration": 30,
        },
        headers=as_user("lucia"),
    ).json()["task_id"]
    r3 = update_task(client, "madre", grupal, hora="17:30", duracion=30, titulo="Editada")
    assert r3.status_code == 403
    assert error_code(r3) == 1041

    with engine.connect() as conn:
        titulos = conn.execute(
            text("SELECT task_title FROM Tasks WHERE task_id IN (:a, :b, :c) ORDER BY task_id"),
            {"a": tarea_escolar, "b": tarea_staff_tarde, "c": grupal},
        ).scalars().all()
    assert titulos == ["Clase", "Apoyo personal", "Plástica"]


def test_el_alumno_ve_en_su_agenda_los_cambios_hechos_por_el_tutor(client):
    tarea = create_task(
        client, "madre", hora="17:00", duracion=20, fecha=LUNES, titulo="Hacer deberes"
    ).json()["task_id"]

    r = update_task(
        client,
        "madre",
        tarea,
        fecha_origen=LUNES,
        fecha_nueva="2026-11-17",
        hora="18:15",
        duracion=40,
        titulo="Hacer deberes de lengua",
    )
    assert r.status_code == 200

    agenda_antigua = client.get(
        "/student-tasks/me",
        params={"task_date": LUNES},
        headers=as_user("pablo"),
    )
    assert agenda_antigua.status_code == 200
    assert agenda_antigua.json()["tasks"] == []

    agenda_nueva = client.get(
        "/student-tasks/me",
        params={"task_date": "2026-11-17"},
        headers=as_user("pablo"),
    )
    assert agenda_nueva.status_code == 200
    tareas = agenda_nueva.json()["tasks"]
    assert len(tareas) == 1
    assert tareas[0]["task_id"] == tarea
    assert tareas[0]["task_title"] == "Hacer deberes de lengua"
    assert tareas[0]["task_start_hour"] == "18:15:00"
    assert tareas[0]["task_duration"] == 40
    assert tareas[0]["task_date"] == "2026-11-17"


@pytest.mark.parametrize(
    "cambio",
    [
        {"task_title": "   "},
        {"task_title": "x" * 101},
        {"task_duration": 0},
        {"task_duration": -15},
        {"task_duration": "30"},
        {"task_date": "no-es-fecha"},
        {"task_start_hour": "25:00"},
        {"task_start_hour": "17:00+01:00"},
        {"campo_inventado": 1},
    ],
)
def test_modificar_tarea_con_datos_invalidos_devuelve_mensaje_descriptivo(client, engine, cambio):
    from sqlalchemy import text

    tarea = create_task(
        client, "madre", hora="17:00", duracion=20, fecha=LUNES, titulo="Original"
    ).json()["task_id"]
    body = {
        "task_title": "Valida",
        "task_date": LUNES,
        "task_start_hour": "18:00",
        "task_duration": 30,
        **cambio,
    }
    r = client.put(
        f"/student-tasks/students/pablo/{tarea}",
        params={"task_date": LUNES},
        json=body,
        headers=as_user("madre"),
    )
    assert r.status_code == 422
    assert error_code(r) == 1005
    assert r.json()["details"]
    with engine.connect() as conn:
        titulo = conn.execute(
            text("SELECT task_title FROM Tasks WHERE task_id = :t"), {"t": tarea}
        ).scalar_one()
    assert titulo == "Original"


def test_el_personal_modifica_solo_tareas_individuales_en_horario_escolar(client):
    individual = create_task(client, "lucia", hora="10:00", titulo="Fichas").json()["task_id"]
    r = update_task(client, "lucia", individual, hora="11:30", duracion=40, titulo="Fichas 2")
    assert r.status_code == 200
    assert r.json()["task_title"] == "Fichas 2"
    assert r.json()["task_start_hour"] == "11:30:00"

    fuera = create_task(client, "madre", hora="17:00", titulo="Casa").json()["task_id"]
    r_fuera = update_task(client, "lucia", fuera, hora="10:00", duracion=20)
    assert r_fuera.status_code == 400
    assert error_code(r_fuera) == 1023

    sin_hora = create_task(client, "madre", hora=None, titulo="Libre").json()["task_id"]
    r_sin_hora = update_task(client, "lucia", sin_hora, hora="10:00", duracion=20)
    assert r_sin_hora.status_code == 400
    assert error_code(r_sin_hora) == 1023

    grupal = client.post(
        "/classes/1A/tasks",
        json={
            "task_title": "Plástica",
            "task_date": LUNES,
            "task_start_hour": "11:00",
            "task_duration": 30,
        },
        headers=as_user("lucia"),
    ).json()["task_id"]
    r_grupal = update_task(client, "lucia", grupal, hora="12:00", duracion=30)
    assert r_grupal.status_code == 404
    assert error_code(r_grupal) == 1021


@pytest.mark.parametrize("usuario", ["pedro", "otra_madre"])
def test_modificar_sin_relacion_con_el_alumno(client, usuario):
    tarea = create_task(client, "madre", hora="17:00").json()["task_id"]
    r = update_task(client, usuario, tarea, hora="10:00" if usuario == "pedro" else "18:00")
    assert r.status_code == 403
    assert error_code(r) == 1019


@pytest.mark.parametrize("usuario", ["admin", "pablo"])
def test_solo_familia_y_personal_modifican_para_un_alumno(client, usuario):
    tarea = create_task(client, "madre", hora="17:00").json()["task_id"]
    r = update_task(client, usuario, tarea)
    assert r.status_code == 403
    assert error_code(r) == 1017


def test_modificar_errores_de_validacion_y_existencia(client):
    assert update_task(client, "madre", 9999).status_code == 404
    assert error_code(update_task(client, "madre", 9999)) == 1021

    r_no_student = update_task(client, "madre", 1, alumno="nadie")
    assert r_no_student.status_code == 404
    assert error_code(r_no_student) == 1018

    tarea = create_task(client, "madre", hora="17:00", fecha=LUNES).json()["task_id"]
    r_wrong_date = update_task(client, "madre", tarea, fecha_origen="2026-11-17")
    assert r_wrong_date.status_code == 404
    assert error_code(r_wrong_date) == 1021

    r_no_session = client.put(
        f"/student-tasks/students/pablo/{tarea}",
        params={"task_date": LUNES},
        json={"task_title": "X", "task_date": LUNES, "task_duration": 15},
    )
    assert r_no_session.status_code == 401

    r_no_query = client.put(
        f"/student-tasks/students/pablo/{tarea}",
        json={"task_title": "X", "task_date": LUNES, "task_duration": 15},
        headers=as_user("madre"),
    )
    assert r_no_query.status_code == 422


def test_openapi_anuncia_put_de_tareas_individuales(client):
    schema = client.get("/openapi.json").json()
    assert "put" in schema["paths"]["/student-tasks/students/{student_username}/{task_id}"]
