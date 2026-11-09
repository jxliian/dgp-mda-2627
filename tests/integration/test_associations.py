"""HU-07 y HU-08: asociaciones de alumnos con familias (directas) y personal (por clase)."""
import pytest

from conftest import as_user, error_code

NO_ADMIN = ["lucia", "madre", "pablo"]


# ------------------------------------------------------------------- Familias

def test_admin_asocia_familia_y_alumno(client, count):
    r = client.post("/student-links/students/ana/parents/otra_madre", headers=as_user("admin"))
    assert r.status_code == 200
    assert r.json()["association_created"] is True
    assert count("par_stud WHERE par_usr_fk = 'otra_madre' AND stud_usr_fk = 'ana'") == 1


def test_asociar_dos_veces_no_duplica(client, count):
    r = client.post("/student-links/students/pablo/parents/madre", headers=as_user("admin"))
    assert r.status_code == 200
    assert r.json()["association_created"] is False
    assert count("par_stud WHERE par_usr_fk = 'madre' AND stud_usr_fk = 'pablo'") == 1


def test_un_alumno_puede_tener_varias_familias(client, count):
    client.post("/student-links/students/pablo/parents/otra_madre", headers=as_user("admin"))
    assert count("par_stud WHERE stud_usr_fk = 'pablo'") == 2


@pytest.mark.parametrize(
    "alumno, familia", [("nadie", "madre"), ("pablo", "nadie"), ("madre", "madre"), ("pablo", "lucia")]
)
def test_asociar_cuentas_que_no_existen_con_ese_rol(client, count, alumno, familia):
    r = client.post(f"/student-links/students/{alumno}/parents/{familia}", headers=as_user("admin"))
    assert r.status_code == 404
    assert error_code(r) == 1013
    assert count("par_stud") == 1


@pytest.mark.parametrize("usuario", NO_ADMIN)
def test_solo_el_admin_puede_asociar(client, count, usuario):
    r = client.post("/student-links/students/ana/parents/madre", headers=as_user(usuario))
    assert r.status_code == 403
    assert count("par_stud") == 1


def test_asociar_sin_sesion(client):
    assert client.post("/student-links/students/ana/parents/madre").status_code == 401


def test_admin_quita_una_asociacion(client, count):
    r = client.delete("/student-links/students/pablo/parents/madre", headers=as_user("admin"))
    assert r.status_code == 200
    assert count("par_stud") == 0
    assert count("Parents WHERE par_usr = 'madre'") == 1


def test_quitar_una_asociacion_que_no_existe(client):
    r = client.delete("/student-links/students/ana/parents/madre", headers=as_user("admin"))
    assert r.status_code == 404
    assert error_code(r) == 1014


@pytest.mark.parametrize("usuario", NO_ADMIN)
def test_solo_el_admin_puede_quitar_asociaciones(client, count, usuario):
    r = client.delete("/student-links/students/pablo/parents/madre", headers=as_user(usuario))
    assert r.status_code == 403
    assert count("par_stud") == 1


# ---------------------------------------------------------------------- Consultas

def test_admin_ve_familia_y_personal_de_un_alumno(client):
    r = client.get("/student-links/students/pablo", headers=as_user("admin"))
    assert r.status_code == 200
    assert [p["username"] for p in r.json()["parents"]] == ["madre"]
    assert [s["username"] for s in r.json()["staff"]] == ["lucia"]


@pytest.mark.parametrize("usuario", NO_ADMIN)
def test_solo_el_admin_ve_los_vinculos_de_un_alumno(client, usuario):
    assert client.get("/student-links/students/pablo", headers=as_user(usuario)).status_code == 403


def test_la_familia_ve_sus_alumnos(client):
    r = client.get("/student-links/parents/madre/students", headers=as_user("madre"))
    assert [a["username"] for a in r.json()["students"]] == ["pablo"]


def test_una_familia_no_ve_los_alumnos_de_otra(client):
    r = client.get("/student-links/parents/madre/students", headers=as_user("otra_madre"))
    assert r.status_code == 403
    assert error_code(r) == 1004


def test_el_personal_ve_los_alumnos_de_su_clase(client):
    r = client.get("/student-links/staff/lucia/students", headers=as_user("lucia"))
    assert [a["username"] for a in r.json()["students"]] == ["pablo"]


def test_el_personal_no_ve_los_alumnos_de_otro(client):
    r = client.get("/student-links/staff/lucia/students", headers=as_user("pedro"))
    assert r.status_code == 403
    assert error_code(r) == 1004


def test_el_admin_ve_los_alumnos_de_cualquiera(client):
    r = client.get("/student-links/staff/lucia/students", headers=as_user("admin"))
    assert r.status_code == 200


# ----------------------------------------------------------- Personal, por clases

def test_admin_asigna_personal_a_una_clase(client, count):
    r = client.post("/classes/2B/staff/lucia", headers=as_user("admin"))
    assert r.status_code == 200
    assert count("class_staff WHERE staff_usr_fk = 'lucia'") == 2


@pytest.mark.parametrize("usuario", NO_ADMIN)
def test_solo_el_admin_asigna_personal(client, count, usuario):
    r = client.post("/classes/2B/staff/lucia", headers=as_user(usuario))
    assert r.status_code == 403
    assert count("class_staff WHERE staff_usr_fk = 'lucia'") == 1


def test_asignar_personal_inexistente(client):
    r = client.post("/classes/1A/staff/nadie", headers=as_user("admin"))
    assert r.status_code == 404
    assert error_code(r) == 1034


def test_asignar_personal_a_clase_inexistente(client):
    r = client.post("/classes/9Z/staff/lucia", headers=as_user("admin"))
    assert r.status_code == 404
    assert error_code(r) == 1030


def test_el_personal_inscribe_un_alumno_en_su_clase(client):
    r = client.post("/classes/1A/students/ana", headers=as_user("lucia"))
    assert r.status_code == 201
    alumnos = client.get("/student-links/staff/lucia/students", headers=as_user("lucia")).json()["students"]
    assert [a["username"] for a in alumnos] == ["ana", "pablo"]


def test_el_personal_no_inscribe_en_una_clase_ajena(client, count):
    r = client.post("/classes/1A/students/ana", headers=as_user("pedro"))
    assert r.status_code == 403
    assert error_code(r) == 1032
    assert count("class_stud WHERE stud_usr_fk = 'ana'") == 0


def test_un_alumno_no_puede_estar_en_dos_clases(client):
    r = client.post("/classes/2B/students/pablo", headers=as_user("pedro"))
    assert r.status_code == 409
    assert error_code(r) == 1033


def test_el_personal_saca_a_un_alumno_de_su_clase(client):
    r = client.delete("/classes/1A/students/pablo", headers=as_user("lucia"))
    assert r.status_code == 200
    alumnos = client.get("/student-links/staff/lucia/students", headers=as_user("lucia")).json()["students"]
    assert alumnos == []


@pytest.mark.xfail(strict=True, reason="HU-07/08: no existe ruta para quitar a un profesor de una clase")
def test_admin_quita_personal_de_una_clase(client, count):
    r = client.delete("/classes/1A/staff/lucia", headers=as_user("admin"))
    assert r.status_code == 200
    assert count("class_staff WHERE staff_usr_fk = 'lucia'") == 0
