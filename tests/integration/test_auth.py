"""HU-05: sesión autenticada y rol de cada usuario."""
import pytest

from conftest import PASSWORD, as_user, error_code


def login(client, username, role, password=PASSWORD):
    return client.post(
        "/auth/login", json={"username": username, "password": password, "role": role}
    )


def bearer(response) -> dict:
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


@pytest.mark.parametrize(
    "username, role",
    [("admin", "admin"), ("lucia", "staff"), ("madre", "parent"), ("pablo", "student")],
)
def test_login_correcto_devuelve_token_y_rol(client, username, role):
    r = login(client, username, role)
    assert r.status_code == 200
    assert r.json()["token_type"] == "bearer"
    assert r.json()["user"] == {"username": username, "role": role}


def test_el_token_no_se_guarda_tal_cual(client, count):
    token = login(client, "admin", "admin").json()["access_token"]
    assert count("users WHERE token = :t", t=token) == 0


def test_contrasena_incorrecta(client):
    r = login(client, "admin", "admin", password="otra")
    assert r.status_code == 401
    assert error_code(r) == 1001


def test_usuario_inexistente_da_el_mismo_error(client):
    r = login(client, "nadie", "admin")
    assert r.status_code == 401
    assert error_code(r) == 1001


def test_rol_que_no_es_el_suyo(client):
    r = login(client, "lucia", "parent")
    assert r.status_code == 401
    assert error_code(r) == 1001


@pytest.mark.parametrize(
    "body",
    [
        {"username": "admin", "password": PASSWORD},
        {"username": "admin", "password": PASSWORD, "role": "profesor"},
        {"username": "con espacio", "password": PASSWORD, "role": "admin"},
        {"username": "admin", "password": "x" * 73, "role": "admin"},
        {"username": "admin", "password": PASSWORD, "role": "admin", "extra": 1},
    ],
)
def test_login_con_datos_invalidos(client, body):
    r = client.post("/auth/login", json=body)
    assert r.status_code == 422
    assert error_code(r) == 1005


def test_el_token_del_login_sirve_para_entrar(client):
    r = client.get("/users", headers=bearer(login(client, "admin", "admin")))
    assert r.status_code == 200


def test_ruta_protegida_sin_token(client):
    r = client.get("/users")
    assert r.status_code == 401
    assert error_code(r) == 1002


def test_ruta_protegida_con_token_falso(client):
    r = client.get("/users", headers={"Authorization": "Bearer inventado"})
    assert r.status_code == 401
    assert error_code(r) == 1002


def test_un_login_nuevo_invalida_la_sesion_anterior(client):
    primera = bearer(login(client, "admin", "admin"))
    segunda = bearer(login(client, "admin", "admin"))
    assert client.get("/users", headers=primera).status_code == 401
    assert client.get("/users", headers=segunda).status_code == 200


def test_logout_cierra_la_sesion(client):
    cabecera = as_user("admin")
    r = client.post("/auth/logout", headers=cabecera)
    assert r.status_code == 200
    assert r.json()["username"] == "admin"
    assert client.get("/users", headers=cabecera).status_code == 401


def test_logout_dos_veces(client):
    client.post("/auth/logout", headers=as_user("admin"))
    assert client.post("/auth/logout", headers=as_user("admin")).status_code == 401


def test_logout_solo_cierra_la_sesion_propia(client):
    client.post("/auth/logout", headers=as_user("lucia"))
    assert client.get("/users", headers=as_user("admin")).status_code == 200
