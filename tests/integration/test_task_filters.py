"""SCRUM-692: el personal y la familia filtran las tareas de su alumno por clase,
estado y rol del creador. Cada prueba corresponde a una prueba de aceptación."""
import pytest
from sqlalchemy import text

from conftest import LUNES, as_user, error_code


def _post(client, ruta, usuario, titulo, hora, duracion=30):
    body = {"task_title": titulo, "task_date": LUNES, "task_start_hour": hora, "task_duration": duracion}
    respuesta = client.post(ruta, json=body, headers=as_user(usuario))
    assert respuesta.status_code == 201, respuesta.json()
    return respuesta.json()


@pytest.fixture
def agenda(client, engine):
    """Agenda de un lunes de pablo (matriculado en 1A) con tareas de todas las procedencias:
    - «Plástica»: clase 1A (lucia), completada.
    - «Música»: clase 1A (lucia), pendiente.
    - «Lavarse los dientes»: personal suelta de lucia, pendiente.
    - «Hacer la cama»: de la familia (madre), completada.
    - «Leer un cuento»: del propio alumno, pendiente.
    """
    _post(client, "/classes/1A/tasks", "lucia", "Plástica", "10:00")
    _post(client, "/classes/1A/tasks", "lucia", "Música", "11:00")
    _post(client, "/student-tasks/students/pablo", "lucia", "Lavarse los dientes", "12:00")
    _post(client, "/student-tasks/students/pablo", "madre", "Hacer la cama", "17:00")
    _post(client, "/student-tasks/me", "pablo", "Leer un cuento", "19:00")
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE Tasks SET task_finished = TRUE WHERE task_title IN ('Plástica', 'Hacer la cama')")
        )


def titulos(client, usuario="lucia", alumno="pablo", **filtros):
    respuesta = client.get(
        f"/student-tasks/students/{alumno}",
        params={"task_date": LUNES, **filtros},
        headers=as_user(usuario),
    )
    assert respuesta.status_code == 200, respuesta.json()
    return {tarea["task_title"] for tarea in respuesta.json()["tasks"]}


# 1. Filtrar por clase
@pytest.mark.parametrize("usuario", ["lucia", "madre"])
def test_filtrar_por_clase(client, agenda, usuario):
    assert titulos(client, usuario, class_name="1A") == {"Plástica", "Música"}
    assert titulos(client, usuario, class_name="2B") == set()


# 2. Filtrar por estado
@pytest.mark.parametrize("usuario", ["lucia", "madre"])
def test_filtrar_por_estado(client, agenda, usuario):
    assert titulos(client, usuario, finished="false") == {"Música", "Lavarse los dientes", "Leer un cuento"}
    assert titulos(client, usuario, finished="true") == {"Plástica", "Hacer la cama"}


# 3. Filtrar por rol del creador
@pytest.mark.parametrize("usuario", ["lucia", "madre"])
def test_filtrar_por_rol_del_creador(client, agenda, usuario):
    assert titulos(client, usuario, creator_role="staff") == {"Plástica", "Música", "Lavarse los dientes"}
    assert titulos(client, usuario, creator_role="parent") == {"Hacer la cama"}
    assert titulos(client, usuario, creator_role="student") == {"Leer un cuento"}


def test_cada_tarea_indica_el_rol_de_su_creador(client, agenda):
    respuesta = client.get(
        "/student-tasks/students/pablo", params={"task_date": LUNES}, headers=as_user("lucia")
    )
    roles = {tarea["task_title"]: tarea["creator_role"] for tarea in respuesta.json()["tasks"]}
    assert roles == {
        "Plástica": "staff",
        "Música": "staff",
        "Lavarse los dientes": "staff",
        "Hacer la cama": "parent",
        "Leer un cuento": "student",
    }


# 4. Combinar filtros
def test_combinar_filtros(client, agenda):
    assert titulos(client, creator_role="staff", finished="false") == {"Música", "Lavarse los dientes"}
    assert titulos(client, class_name="1A", finished="true", creator_role="staff") == {"Plástica"}
    assert titulos(client, class_name="1A", creator_role="parent") == set()


# 5. Sin filtros se ven todas, como antes
def test_sin_filtros_se_ven_todas(client, agenda):
    assert titulos(client) == {
        "Plástica", "Música", "Lavarse los dientes", "Hacer la cama", "Leer un cuento",
    }


# 6. Sin relación con el alumno no se puede filtrar
@pytest.mark.parametrize("usuario", ["pedro", "otra_madre"])
def test_sin_relacion_se_deniega_el_acceso(client, agenda, usuario):
    respuesta = client.get(
        "/student-tasks/students/pablo",
        params={"task_date": LUNES, "class_name": "1A"},
        headers=as_user(usuario),
    )
    assert respuesta.status_code == 403
    assert error_code(respuesta) != 0


# 7. Un filtro sin coincidencias devuelve una lista vacía, no un error
def test_filtro_sin_coincidencias_devuelve_lista_vacia(client, agenda):
    assert titulos(client, class_name="Clase que no existe") == set()
    assert titulos(client, usuario="madre", class_name="1A", creator_role="student") == set()


@pytest.mark.parametrize(
    "filtro",
    [{"creator_role": "perro"}, {"creator_role": "admin"}, {"finished": "quizas"}, {"class_name": ""}],
)
def test_filtros_con_valores_invalidos(client, agenda, filtro):
    respuesta = client.get(
        "/student-tasks/students/pablo",
        params={"task_date": LUNES, **filtro},
        headers=as_user("lucia"),
    )
    assert respuesta.status_code == 422
