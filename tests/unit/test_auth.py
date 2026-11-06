"""Pruebas de HU-05: inicio de sesión, sesión (JWT) y permisos por rol.

No necesitan PostgreSQL: la base de datos se sustituye por un repositorio falso en memoria.
"""
from datetime import datetime, timedelta, timezone

import jwt
import pytest
from fastapi import Depends
from fastapi.testclient import TestClient

from auth.dependencies import require_roles
from auth.security import hash_password
from config import settings
from DB.database import get_db
from gestion_usuarios.users_mng_db import DBResponse, users_mng_db
from main import app

# Usuarios de prueba: (email, rol) -> (usuario, hash de la contraseña)
FAKE_USERS = {
    ("admin@autovida.es", "admin"): ("admin", hash_password("Admin1234")),
    ("lucia@autovida.es", "staff"): ("lucia", hash_password("Lucia1234")),
}


@app.get("/_test/solo-admin")
def _solo_admin(user=Depends(require_roles("admin"))):
    return {"ok": True, "email": user.email}


@pytest.fixture
def client(monkeypatch):
    def fake_get_password(db, email, role):
        found = FAKE_USERS.get((email, role))
        return found[1] if found else None

    def fake_get_user(db, email, role):
        found = FAKE_USERS.get((email, role))
        if not found:
            return DBResponse({"errorCode": 1, "errorMsg": "Usuario no encontrado por email"})
        return DBResponse({"errorCode": 0, "errorMsg": "OK", "username": found[0], "email": email})

    monkeypatch.setattr(users_mng_db, "getPasswordByEmail", fake_get_password)
    monkeypatch.setattr(users_mng_db, "getUserByEmail", fake_get_user)
    app.dependency_overrides[get_db] = lambda: None
    yield TestClient(app)
    app.dependency_overrides.clear()


def login(client, email, password, role):
    return client.post("/auth/login", json={"email": email, "password": password, "role": role})


def auth_header(token):
    return {"Authorization": f"Bearer {token}"}


# --- Inicio de sesión ---

def test_login_correcto_devuelve_token_y_rol(client):
    r = login(client, "lucia@autovida.es", "Lucia1234", "staff")
    assert r.status_code == 200
    body = r.json()
    assert body["role"] == "staff"
    assert body["token_type"] == "bearer"
    assert jwt.decode(body["access_token"], settings.jwt_secret_key, algorithms=["HS256"])["sub"] == "lucia@autovida.es"


def test_login_email_en_mayusculas_funciona(client):
    assert login(client, "  Lucia@AutoVida.es ", "Lucia1234", "staff").status_code == 200


def test_login_contrasena_incorrecta(client):
    r = login(client, "lucia@autovida.es", "otra", "staff")
    assert r.status_code == 401
    assert r.json()["detail"] == "Email o contraseña incorrectos"


def test_login_usuario_inexistente_mismo_mensaje(client):
    r = login(client, "nadie@autovida.es", "Lucia1234", "staff")
    assert r.status_code == 401
    assert r.json()["detail"] == "Email o contraseña incorrectos"


def test_login_rol_equivocado(client):
    # Lucía es personal: si pulsa el botón de familia, no existe en esa tabla
    assert login(client, "lucia@autovida.es", "Lucia1234", "parent").status_code == 401


@pytest.mark.parametrize("payload", [
    {"email": "no-es-un-email", "password": "x", "role": "staff"},
    {"email": "lucia@autovida.es", "password": "", "role": "staff"},
    {"email": "lucia@autovida.es", "password": "x", "role": "profesor"},
    {"email": "lucia@autovida.es", "role": "staff"},
])
def test_login_datos_invalidos(client, payload):
    assert client.post("/auth/login", json=payload).status_code == 422


# --- Sesión ---

def test_me_con_token_valido(client):
    token = login(client, "lucia@autovida.es", "Lucia1234", "staff").json()["access_token"]
    r = client.get("/auth/me", headers=auth_header(token))
    assert r.status_code == 200
    assert r.json() == {"email": "lucia@autovida.es", "username": "lucia", "role": "staff"}


def test_me_sin_token(client):
    assert client.get("/auth/me").status_code == 401


def test_me_token_manipulado(client):
    token = login(client, "lucia@autovida.es", "Lucia1234", "staff").json()["access_token"]
    falso = jwt.encode({"sub": "lucia@autovida.es", "role": "admin",
                        "exp": datetime.now(timezone.utc) + timedelta(hours=1)},
                       "otra-clave-que-no-es-la-del-servidor-xxxxxxxx", algorithm="HS256")
    assert client.get("/auth/me", headers=auth_header(falso)).status_code == 401
    assert client.get("/auth/me", headers=auth_header(token + "x")).status_code == 401


def test_me_token_caducado(client):
    caducado = jwt.encode({"sub": "lucia@autovida.es", "role": "staff",
                           "exp": datetime.now(timezone.utc) - timedelta(minutes=1)},
                          settings.jwt_secret_key, algorithm="HS256")
    assert client.get("/auth/me", headers=auth_header(caducado)).status_code == 401


def test_cuenta_eliminada_pierde_el_acceso(client):
    token = login(client, "lucia@autovida.es", "Lucia1234", "staff").json()["access_token"]
    del FAKE_USERS[("lucia@autovida.es", "staff")]  # el administrador la elimina (HU-02)
    try:
        assert client.get("/auth/me", headers=auth_header(token)).status_code == 401
    finally:
        FAKE_USERS[("lucia@autovida.es", "staff")] = ("lucia", hash_password("Lucia1234"))


# --- Permisos por rol ---

def test_require_roles_admin_permite_admin(client):
    token = login(client, "admin@autovida.es", "Admin1234", "admin").json()["access_token"]
    assert client.get("/_test/solo-admin", headers=auth_header(token)).status_code == 200


def test_require_roles_admin_rechaza_personal(client):
    token = login(client, "lucia@autovida.es", "Lucia1234", "staff").json()["access_token"]
    r = client.get("/_test/solo-admin", headers=auth_header(token))
    assert r.status_code == 403
    assert r.json()["detail"] == "No tienes permiso para esta acción"


def test_require_roles_sin_sesion(client):
    assert client.get("/_test/solo-admin").status_code == 401
