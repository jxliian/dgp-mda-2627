"""Preparación común de las pruebas del backend.

Las pruebas usan PostgreSQL de verdad, porque el código usa FOR UPDATE, LOCK TABLE y
otras cosas que SQLite no tiene. Trabajan en una base de datos aparte, autovida_test,
que se borra y se crea de nuevo en cada ejecución. La base autovida_db no se toca.

Datos de partida de cada prueba:
    admin (admin)
    lucia (personal de la clase 1A) y pedro (personal de la clase 2B)
    madre (familia de pablo) y otra_madre (familia sin alumnos)
    pablo (alumno de la clase 1A) y ana (alumna sin clase)
"""
import hashlib
import sys
from pathlib import Path

import pytest
from dotenv import load_dotenv
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

REPO = Path(__file__).resolve().parents[2]
BACKEND = REPO / "src" / "backend"
SCHEMA = REPO / "docs" / "diseno_arquitectura" / "modelado_datos" / "CreacionTablas.sqlscript"

sys.path.insert(0, str(BACKEND))
load_dotenv(BACKEND / "proyectFastAPI" / ".env")

from proyectFastAPI.DB.database import DATABASE_URL, get_db  # noqa: E402
from proyectFastAPI.gestion_usuarios.users_mng_db import pwd_context  # noqa: E402
from proyectFastAPI.main import app  # noqa: E402

TEST_DATABASE = "autovida_test"
PASSWORD = "Clave1234"
LUNES = "2026-11-16"
SABADO = "2026-11-14"

PASSWORD_HASH = pwd_context.hash(PASSWORD)


def stored_token(username: str) -> str:
    """Lo que hay guardado en users.token para la sesión de ese usuario."""
    return hashlib.sha256(f"token-{username}".encode()).hexdigest()


def as_user(username: str) -> dict:
    """Cabecera de una petición hecha con la sesión de ese usuario."""
    return {"Authorization": f"Bearer token-{username}"}


def error_code(response) -> int:
    return response.json()["errorCode"]


@pytest.fixture(scope="session")
def engine():
    server = create_engine(
        DATABASE_URL.set(database="postgres"), isolation_level="AUTOCOMMIT"
    )
    with server.connect() as conn:
        conn.execute(text(f"DROP DATABASE IF EXISTS {TEST_DATABASE} WITH (FORCE)"))
        conn.execute(text(f"CREATE DATABASE {TEST_DATABASE}"))
    server.dispose()

    test_engine = create_engine(
        DATABASE_URL.set(database=TEST_DATABASE), isolation_level="READ COMMITTED"
    )
    schema = SCHEMA.read_text(encoding="utf-8").replace("COMMIT;", "")
    with test_engine.begin() as conn:
        conn.exec_driver_sql(schema)
    yield test_engine
    test_engine.dispose()


def _add_account(conn, username, full_name):
    conn.execute(
        text(
            "INSERT INTO users (username, full_name, password, token) "
            "VALUES (:username, :full_name, :password, :token)"
        ),
        {
            "username": username,
            "full_name": full_name,
            "password": PASSWORD_HASH,
            "token": stored_token(username),
        },
    )


def add_admin(conn, username):
    _add_account(conn, username, "Persona Admin")
    conn.execute(
        text("INSERT INTO Admn VALUES (:u, :e)"),
        {"u": username, "e": f"{username}@autovida.es"},
    )


def _add_staff(conn, username):
    _add_account(conn, username, "Persona Personal")
    conn.execute(
        text("INSERT INTO Staff VALUES (:u, :e)"),
        {"u": username, "e": f"{username}@autovida.es"},
    )


def _add_parent(conn, username):
    _add_account(conn, username, "Persona Familia")
    conn.execute(
        text("INSERT INTO Parents VALUES (:u, :e)"),
        {"u": username, "e": f"{username}@mail.es"},
    )


def _add_student(conn, username):
    _add_account(conn, username, "Persona Alumna")
    conn.execute(
        text(
            "INSERT INTO Student (stud_usr, stud_access_main_col, stud_access_sec_col, "
            "stud_access_ntasks_visible, stud_access_pictograms, stud_access_contrast, "
            "stud_access_fontsize, stud_access_filters, stud_access_ndays_visible, "
            "stud_access_prof_mod, stud_access_timebar, stud_access_talkback, "
            "stud_access_profile_mod, stud_access_task_mod) "
            "VALUES (:u, '#ffffff', '#000000', 5, TRUE, FALSE, 18, TRUE, 7, "
            "FALSE, TRUE, FALSE, TRUE, TRUE)"
        ),
        {"u": username},
    )


@pytest.fixture(autouse=True)
def seed(engine):
    """Deja la base de datos igual antes de cada prueba."""
    with engine.begin() as conn:
        conn.execute(
            text("TRUNCATE users, Class, Avatar, Tasks, Alt_Tasks RESTART IDENTITY CASCADE")
        )
        add_admin(conn, "admin")
        _add_staff(conn, "lucia")
        _add_staff(conn, "pedro")
        _add_parent(conn, "madre")
        _add_parent(conn, "otra_madre")
        _add_student(conn, "pablo")
        _add_student(conn, "ana")
        conn.execute(text("INSERT INTO Class VALUES ('1A'), ('2B')"))
        conn.execute(text("INSERT INTO class_staff VALUES ('1A', 'lucia'), ('2B', 'pedro')"))
        conn.execute(text("INSERT INTO class_stud VALUES ('1A', 'pablo')"))
        conn.execute(text("INSERT INTO par_stud VALUES ('madre', 'pablo')"))


@pytest.fixture
def client(engine):
    session_factory = sessionmaker(bind=engine, autoflush=False)

    def override_get_db():
        session = session_factory()
        try:
            yield session
        finally:
            session.close()

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture
def count(engine):
    """Cuenta filas: count("users WHERE username = :u", u="ana")."""

    def _count(where: str, **params) -> int:
        with engine.connect() as conn:
            return conn.execute(text(f"SELECT COUNT(*) FROM {where}"), params).scalar_one()

    return _count
