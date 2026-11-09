"""HU-02 (eliminar cuentas) y HU-03 (consultar cuentas)."""
import pytest
from sqlalchemy import text

from conftest import PASSWORD, add_admin, as_user, error_code

NO_ADMIN = ["lucia", "madre", "pablo"]


# ------------------------------------------------------- HU-02: eliminar cuentas

def test_admin_elimina_una_cuenta(client, count):
    r = client.delete("/users/student/ana", headers=as_user("admin"))
    assert r.status_code == 200
    assert count("users WHERE username = 'ana'") == 0
    assert count("Student WHERE stud_usr = 'ana'") == 0


def test_eliminar_un_alumno_borra_sus_vinculos_y_nada_mas(client, count):
    client.delete("/users/student/pablo", headers=as_user("admin"))
    assert count("par_stud WHERE stud_usr_fk = 'pablo'") == 0
    assert count("class_stud WHERE stud_usr_fk = 'pablo'") == 0
    assert count("Parents WHERE par_usr = 'madre'") == 1
    assert count("Staff WHERE staff_usr = 'lucia'") == 1
    assert count("Student WHERE stud_usr = 'ana'") == 1


def test_la_cuenta_eliminada_pierde_su_sesion(client):
    cabecera = as_user("madre")
    assert client.get("/student-links/parents/madre/students", headers=cabecera).status_code == 200
    client.delete("/users/parent/madre", headers=as_user("admin"))
    assert client.get("/student-links/parents/madre/students", headers=cabecera).status_code == 401


def test_la_cuenta_eliminada_no_puede_entrar(client):
    datos = {"username": "lucia", "password": PASSWORD, "role": "staff"}
    assert client.post("/auth/login", json=datos).status_code == 200
    client.delete("/users/staff/lucia", headers=as_user("admin"))
    assert client.post("/auth/login", json=datos).status_code == 401


def test_no_se_puede_eliminar_al_ultimo_admin(client, count):
    r = client.delete("/users/admin/admin", headers=as_user("admin"))
    assert r.status_code == 403
    assert error_code(r) == 1042
    assert count("Admn") == 1


def test_con_dos_admins_se_puede_eliminar_uno(client, engine, count):
    with engine.begin() as conn:
        add_admin(conn, "admin2")
    assert client.delete("/users/admin/admin2", headers=as_user("admin")).status_code == 200
    assert count("Admn") == 1


def test_eliminar_cuenta_inexistente(client):
    r = client.delete("/users/student/nadie", headers=as_user("admin"))
    assert r.status_code == 404
    assert error_code(r) == 1006


def test_eliminar_con_rol_equivocado_no_borra_nada(client, count):
    r = client.delete("/users/parent/lucia", headers=as_user("admin"))
    assert r.status_code == 404
    assert count("users WHERE username = 'lucia'") == 1


def test_eliminar_con_rol_inventado(client):
    r = client.delete("/users/profesor/lucia", headers=as_user("admin"))
    assert r.status_code == 422
    assert error_code(r) == 1005


@pytest.mark.parametrize("usuario", NO_ADMIN)
def test_solo_el_admin_puede_eliminar(client, count, usuario):
    r = client.delete("/users/student/ana", headers=as_user(usuario))
    assert r.status_code == 403
    assert error_code(r) == 1003
    assert count("Student WHERE stud_usr = 'ana'") == 1


def test_eliminar_sin_sesion(client):
    assert client.delete("/users/student/ana").status_code == 401


# ------------------------------------------------------ HU-03: consultar cuentas

def test_admin_ve_todas_las_cuentas(client):
    r = client.get("/users", headers=as_user("admin"))
    assert r.status_code == 200
    nombres = [u["username"] for u in r.json()["users"]]
    assert nombres == sorted(["admin", "lucia", "pedro", "madre", "otra_madre", "pablo", "ana"])


def test_la_consulta_no_devuelve_contrasenas_ni_tokens(client):
    for usuario in client.get("/users", headers=as_user("admin")).json()["users"]:
        assert "password" not in usuario
        assert "token" not in usuario


def test_filtrar_por_rol(client):
    r = client.get("/users?role=parent", headers=as_user("admin"))
    usuarios = r.json()["users"]
    assert [u["username"] for u in usuarios] == ["madre", "otra_madre"]
    assert usuarios[0]["email"] == "madre@mail.es"
    assert usuarios[0]["role"] == "parent"


def test_los_alumnos_no_tienen_correo(client):
    for alumno in client.get("/users?role=student", headers=as_user("admin")).json()["users"]:
        assert "email" not in alumno


def test_consulta_sin_resultados(client, engine):
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM users WHERE username IN ('madre', 'otra_madre')"))
    r = client.get("/users?role=parent", headers=as_user("admin"))
    assert r.status_code == 200
    assert r.json()["users"] == []


def test_filtrar_por_rol_inventado(client):
    r = client.get("/users?role=profesor", headers=as_user("admin"))
    assert r.status_code == 422


@pytest.mark.parametrize("usuario", NO_ADMIN)
def test_solo_el_admin_puede_consultar(client, usuario):
    r = client.get("/users", headers=as_user(usuario))
    assert r.status_code == 403
    assert error_code(r) == 1003


def test_consultar_sin_sesion(client):
    assert client.get("/users").status_code == 401


@pytest.mark.xfail(strict=True, reason="HU-03: no existe ruta para consultar una sola cuenta")
def test_admin_consulta_una_cuenta_concreta(client):
    r = client.get("/users/parent/madre", headers=as_user("admin"))
    assert r.status_code == 200
    assert r.json()["username"] == "madre"
