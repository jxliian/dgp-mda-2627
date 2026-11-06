"""Pruebas de HU-02 (eliminar cuentas) y de la parte de HU-03 que consulta una cuenta.

No necesitan PostgreSQL: cada prueba usa una base de datos SQLite en memoria con las
tablas de cuentas y de asociaciones del esquema.
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from auth.security import create_access_token, hash_password
from DB.database import get_db
from main import app

SCHEMA = [
    "CREATE TABLE admn (admn_email VARCHAR(255) PRIMARY KEY, admn_usr VARCHAR(50) NOT NULL, admn_passwd VARCHAR(255) NOT NULL)",
    "CREATE TABLE staff (staff_email VARCHAR(255) PRIMARY KEY, staff_usr VARCHAR(50) NOT NULL, staff_passwd VARCHAR(255) NOT NULL)",
    "CREATE TABLE parents (par_email VARCHAR(255) PRIMARY KEY, par_usr VARCHAR(50) NOT NULL, par_passwd VARCHAR(255) NOT NULL)",
    "CREATE TABLE student (stud_email VARCHAR(255) PRIMARY KEY, stud_usr VARCHAR(50) NOT NULL, stud_password VARCHAR(255) NOT NULL)",
    """CREATE TABLE staff_stud (
        staff_email_fk VARCHAR(255) REFERENCES staff(staff_email) ON DELETE CASCADE,
        stud_email_fk VARCHAR(255) REFERENCES student(stud_email) ON DELETE CASCADE,
        PRIMARY KEY (staff_email_fk, stud_email_fk))""",
    """CREATE TABLE par_stud (
        par_email_fk VARCHAR(255) REFERENCES parents(par_email) ON DELETE CASCADE,
        stud_email_fk VARCHAR(255) REFERENCES student(stud_email) ON DELETE CASCADE,
        PRIMARY KEY (par_email_fk, stud_email_fk))""",
]

PASSWORD = "Clave1234"

ADMIN = ("admin@autovida.es", "admin")
ADMIN2 = ("admin2@autovida.es", "admin")
STAFF = ("lucia@autovida.es", "staff")
MADRE = ("madre.pablo@mail.es", "parent")
PABLO = ("pablo@autovida.es", "student")
ANA = ("ana@autovida.es", "student")


@pytest.fixture
def db_session():
    engine = create_engine("sqlite://", poolclass=StaticPool,
                           connect_args={"check_same_thread": False})

    @event.listens_for(engine, "connect")
    def _enable_fk(dbapi_conn, _):
        dbapi_conn.execute("PRAGMA foreign_keys = ON")

    h = hash_password(PASSWORD)
    with engine.begin() as conn:
        for stmt in SCHEMA:
            conn.execute(text(stmt))
        conn.execute(text("INSERT INTO admn VALUES ('admin@autovida.es', 'admin', :h), "
                          "('admin2@autovida.es', 'admin2', :h)"), {"h": h})
        conn.execute(text("INSERT INTO staff VALUES ('lucia@autovida.es', 'lucia', :h)"), {"h": h})
        conn.execute(text("INSERT INTO parents VALUES ('madre.pablo@mail.es', 'madre_pablo', :h)"), {"h": h})
        conn.execute(text("INSERT INTO student VALUES ('pablo@autovida.es', 'pablo', :h), "
                          "('ana@autovida.es', 'ana', :h)"), {"h": h})
        conn.execute(text("INSERT INTO par_stud VALUES ('madre.pablo@mail.es', 'pablo@autovida.es'), "
                          "('madre.pablo@mail.es', 'ana@autovida.es')"))
        conn.execute(text("INSERT INTO staff_stud VALUES ('lucia@autovida.es', 'pablo@autovida.es')"))

    session = sessionmaker(bind=engine, autoflush=False)()
    yield session
    session.close()
    engine.dispose()


@pytest.fixture
def client(db_session):
    app.dependency_overrides[get_db] = lambda: db_session
    yield TestClient(app)
    app.dependency_overrides.clear()


def as_user(user):
    email, role = user
    return {"Authorization": f"Bearer {create_access_token(email, role)}"}


def count(db, sql):
    return db.execute(text(sql)).scalar()


# ------------------------------------------------------- HU-02: eliminar cuentas

def test_admin_elimina_una_cuenta(client, db_session):
    r = client.delete("/users/student/pablo@autovida.es", headers=as_user(ADMIN))
    assert r.status_code == 204
    assert count(db_session, "SELECT COUNT(*) FROM student WHERE stud_email = 'pablo@autovida.es'") == 0


def test_cuenta_eliminada_pierde_la_sesion_activa(client):
    token_pablo = as_user(PABLO)
    assert client.get("/auth/me", headers=token_pablo).status_code == 200
    client.delete("/users/student/pablo@autovida.es", headers=as_user(ADMIN))
    assert client.get("/auth/me", headers=token_pablo).status_code == 401


def test_cuenta_eliminada_no_puede_iniciar_sesion(client):
    datos = {"email": "lucia@autovida.es", "password": PASSWORD, "role": "staff"}
    assert client.post("/auth/login", json=datos).status_code == 200
    client.delete("/users/staff/lucia@autovida.es", headers=as_user(ADMIN))
    assert client.post("/auth/login", json=datos).status_code == 401


def test_eliminar_borra_sus_asociaciones_y_conserva_lo_demas(client, db_session):
    client.delete("/users/student/pablo@autovida.es", headers=as_user(ADMIN))
    # las asociaciones de Pablo desaparecen...
    assert count(db_session, "SELECT COUNT(*) FROM par_stud WHERE stud_email_fk = 'pablo@autovida.es'") == 0
    assert count(db_session, "SELECT COUNT(*) FROM staff_stud") == 0
    # ...pero la madre, Lucía, Ana y la asociación madre-Ana siguen ahí
    assert count(db_session, "SELECT COUNT(*) FROM parents") == 1
    assert count(db_session, "SELECT COUNT(*) FROM staff") == 1
    assert count(db_session, "SELECT COUNT(*) FROM student") == 1
    assert count(db_session, "SELECT COUNT(*) FROM par_stud WHERE stud_email_fk = 'ana@autovida.es'") == 1


def test_admin_no_puede_eliminar_su_propia_cuenta(client, db_session):
    r = client.delete("/users/admin/Admin@AutoVida.es", headers=as_user(ADMIN))
    assert r.status_code == 400
    assert r.json()["detail"] == "No puedes eliminar tu propia cuenta"
    assert count(db_session, "SELECT COUNT(*) FROM admn") == 2


def test_admin_puede_eliminar_a_otro_admin(client, db_session):
    assert client.delete("/users/admin/admin2@autovida.es", headers=as_user(ADMIN)).status_code == 204
    assert count(db_session, "SELECT COUNT(*) FROM admn") == 1


def test_eliminar_cuenta_inexistente(client):
    r = client.delete("/users/student/nadie@autovida.es", headers=as_user(ADMIN))
    assert r.status_code == 404
    assert r.json()["detail"] == "No existe ninguna cuenta con ese correo y rol"


def test_eliminar_con_rol_equivocado_no_borra_nada(client, db_session):
    # Lucía es personal: con rol "parent" no existe, así que no se borra
    assert client.delete("/users/parent/lucia@autovida.es", headers=as_user(ADMIN)).status_code == 404
    assert count(db_session, "SELECT COUNT(*) FROM staff") == 1


def test_eliminar_rol_invalido(client):
    assert client.delete("/users/profesor/lucia@autovida.es", headers=as_user(ADMIN)).status_code == 422


@pytest.mark.parametrize("user", [STAFF, MADRE, ANA])
def test_solo_admin_puede_eliminar(client, db_session, user):
    r = client.delete("/users/student/pablo@autovida.es", headers=as_user(user))
    assert r.status_code == 403
    assert count(db_session, "SELECT COUNT(*) FROM student") == 2


def test_eliminar_sin_sesion(client):
    assert client.delete("/users/student/pablo@autovida.es").status_code == 401


def test_si_se_cancela_la_cuenta_permanece(client, db_session):
    # Cancelar en la app = no enviar la petición DELETE. La cuenta sigue y puede entrar.
    datos = {"email": "pablo@autovida.es", "password": PASSWORD, "role": "student"}
    assert client.post("/auth/login", json=datos).status_code == 200
    assert count(db_session, "SELECT COUNT(*) FROM student") == 2


# ------------------------------------------------ HU-03: consultar una cuenta

def test_admin_consulta_los_datos_de_una_cuenta(client):
    r = client.get("/users/student/pablo@autovida.es", headers=as_user(ADMIN))
    assert r.status_code == 200
    assert r.json() == {"email": "pablo@autovida.es", "username": "pablo", "role": "student"}


def test_consulta_con_mayusculas(client):
    r = client.get("/users/staff/Lucia@AutoVida.es", headers=as_user(ADMIN))
    assert r.status_code == 200
    assert r.json()["email"] == "lucia@autovida.es"


def test_consulta_cuenta_inexistente_muestra_mensaje(client):
    r = client.get("/users/parent/nadie@mail.es", headers=as_user(ADMIN))
    assert r.status_code == 404
    assert r.json()["detail"] == "No existe ninguna cuenta con ese correo y rol"


@pytest.mark.parametrize("user", [STAFF, MADRE, PABLO])
def test_solo_admin_puede_consultar(client, user):
    assert client.get("/users/student/pablo@autovida.es", headers=as_user(user)).status_code == 403


def test_consultar_sin_sesion(client):
    assert client.get("/users/student/pablo@autovida.es").status_code == 401
