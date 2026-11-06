"""Pruebas de HU-07 (asociar) y HU-08 (desasociar) alumnos con personal y familiares.

No necesitan PostgreSQL: cada prueba usa una base de datos SQLite en memoria con las
tablas de cuentas y de asociaciones del esquema, así que las consultas SQL se ejecutan de verdad.
"""
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from auth.security import create_access_token
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

SEED = [
    "INSERT INTO admn VALUES ('admin@autovida.es', 'admin', 'x')",
    "INSERT INTO staff VALUES ('lucia@autovida.es', 'lucia', 'x')",
    "INSERT INTO parents VALUES ('madre.pablo@mail.es', 'madre_pablo', 'x')",
    "INSERT INTO parents VALUES ('padre.pablo@mail.es', 'padre_pablo', 'x')",
    "INSERT INTO student VALUES ('pablo@autovida.es', 'pablo', 'x')",
    "INSERT INTO student VALUES ('ana@autovida.es', 'ana', 'x')",
]

ADMIN = ("admin@autovida.es", "admin")
STAFF = ("lucia@autovida.es", "staff")
MADRE = ("madre.pablo@mail.es", "parent")
PADRE = ("padre.pablo@mail.es", "parent")
PABLO = ("pablo@autovida.es", "student")
ANA = ("ana@autovida.es", "student")


@pytest.fixture
def db_session():
    engine = create_engine("sqlite://", poolclass=StaticPool,
                           connect_args={"check_same_thread": False})

    @event.listens_for(engine, "connect")
    def _enable_fk(dbapi_conn, _):
        dbapi_conn.execute("PRAGMA foreign_keys = ON")

    with engine.begin() as conn:
        for stmt in SCHEMA + SEED:
            conn.execute(text(stmt))

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


def associate(client, student, role, members, user=ADMIN):
    return client.post("/associations", headers=as_user(user),
                       json={"student_email": student, "member_role": role, "member_emails": members})


def count_rows(db, table):
    return db.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar()


# ---------------------------------------------------------------- HU-07: asociar

def test_admin_asocia_alumno_con_varios_familiares(client, db_session):
    r = associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es", "padre.pablo@mail.es"])
    assert r.status_code == 201
    assert r.json() == {"created": ["madre.pablo@mail.es", "padre.pablo@mail.es"], "already_existing": []}
    assert count_rows(db_session, "par_stud") == 2          # persistida en la BD


def test_admin_asocia_alumno_con_personal(client, db_session):
    assert associate(client, "pablo@autovida.es", "staff", ["lucia@autovida.es"]).status_code == 201
    assert count_rows(db_session, "staff_stud") == 1


def test_asociacion_aparece_en_la_informacion_de_ambos(client):
    associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es"])
    associate(client, "pablo@autovida.es", "staff", ["lucia@autovida.es"])

    del_alumno = client.get("/associations/students/pablo@autovida.es", headers=as_user(ADMIN)).json()
    assert {"email": "madre.pablo@mail.es", "username": "madre_pablo", "role": "parent"} in del_alumno
    assert {"email": "lucia@autovida.es", "username": "lucia", "role": "staff"} in del_alumno

    de_la_madre = client.get("/associations/parent/madre.pablo@mail.es", headers=as_user(MADRE)).json()
    assert de_la_madre == [{"email": "pablo@autovida.es", "username": "pablo"}]


def test_duplicada_no_se_crea_e_informa(client, db_session):
    associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es"])
    r = associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es"])
    assert r.status_code == 409
    assert r.json()["detail"] == "La asociación ya existe"
    assert count_rows(db_session, "par_stud") == 1


def test_parcialmente_duplicada_crea_solo_las_nuevas(client, db_session):
    associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es"])
    r = associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es", "padre.pablo@mail.es"])
    assert r.status_code == 201
    assert r.json() == {"created": ["padre.pablo@mail.es"], "already_existing": ["madre.pablo@mail.es"]}
    assert count_rows(db_session, "par_stud") == 2


def test_email_repetido_en_la_peticion_y_mayusculas(client, db_session):
    r = associate(client, "Pablo@AutoVida.es", "parent", ["madre.pablo@mail.es", "MADRE.pablo@mail.es"])
    assert r.status_code == 201
    assert r.json()["created"] == ["madre.pablo@mail.es"]
    assert count_rows(db_session, "par_stud") == 1


def test_alumno_inexistente(client, db_session):
    r = associate(client, "nadie@autovida.es", "parent", ["madre.pablo@mail.es"])
    assert r.status_code == 404
    assert count_rows(db_session, "par_stud") == 0


def test_cuenta_inexistente_o_de_otro_rol_no_crea_ninguna(client, db_session):
    # lucia es personal, no familiar: con rol "parent" no existe
    r = associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es", "lucia@autovida.es"])
    assert r.status_code == 404
    assert "lucia@autovida.es" in r.json()["detail"]
    assert count_rows(db_session, "par_stud") == 0          # tampoco la de la madre


@pytest.mark.parametrize("payload", [
    {"student_email": "pablo@autovida.es", "member_role": "parent", "member_emails": []},
    {"student_email": "pablo@autovida.es", "member_role": "student", "member_emails": ["ana@autovida.es"]},
    {"student_email": "no-es-email", "member_role": "parent", "member_emails": ["madre.pablo@mail.es"]},
])
def test_datos_invalidos(client, payload):
    assert client.post("/associations", headers=as_user(ADMIN), json=payload).status_code == 422


@pytest.mark.parametrize("user", [STAFF, MADRE, PABLO])
def test_solo_admin_puede_asociar(client, db_session, user):
    r = associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es"], user=user)
    assert r.status_code == 403
    assert count_rows(db_session, "par_stud") == 0


def test_asociar_sin_sesion(client):
    r = client.post("/associations", json={"student_email": "pablo@autovida.es",
                                           "member_role": "parent", "member_emails": ["madre.pablo@mail.es"]})
    assert r.status_code == 401


# ------------------------------------------------- HU-07: acceso derivado de la relación

def test_familiar_asociado_accede_al_alumno(client):
    associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es"])
    assert client.get("/associations/students/pablo@autovida.es", headers=as_user(MADRE)).status_code == 200


def test_no_asociado_no_accede(client):
    associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es"])
    assert client.get("/associations/students/ana@autovida.es", headers=as_user(MADRE)).status_code == 403
    assert client.get("/associations/students/pablo@autovida.es", headers=as_user(PADRE)).status_code == 403
    assert client.get("/associations/students/pablo@autovida.es", headers=as_user(STAFF)).status_code == 403


def test_alumno_ve_lo_suyo_y_no_lo_de_otro(client):
    assert client.get("/associations/students/pablo@autovida.es", headers=as_user(PABLO)).status_code == 200
    assert client.get("/associations/students/pablo@autovida.es", headers=as_user(ANA)).status_code == 403


def test_alumnos_de_un_familiar_solo_el_mismo_o_admin(client):
    associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es"])
    assert client.get("/associations/parent/madre.pablo@mail.es", headers=as_user(ADMIN)).status_code == 200
    assert client.get("/associations/parent/madre.pablo@mail.es", headers=as_user(PADRE)).status_code == 403


# ------------------------------------------------------------- HU-08: desasociar

def delete(client, role, member, student, user=ADMIN):
    return client.delete(f"/associations/{role}/{member}/{student}", headers=as_user(user))


def test_admin_desasocia_y_el_familiar_pierde_el_acceso(client, db_session):
    associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es"])
    assert delete(client, "parent", "madre.pablo@mail.es", "pablo@autovida.es").status_code == 204
    assert count_rows(db_session, "par_stud") == 0
    assert client.get("/associations/students/pablo@autovida.es", headers=as_user(MADRE)).status_code == 403


def test_desasociar_conserva_otras_relaciones_y_las_cuentas(client, db_session):
    associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es", "padre.pablo@mail.es"])
    associate(client, "ana@autovida.es", "parent", ["madre.pablo@mail.es"])
    associate(client, "pablo@autovida.es", "staff", ["lucia@autovida.es"])

    assert delete(client, "parent", "madre.pablo@mail.es", "pablo@autovida.es").status_code == 204

    restantes = db_session.execute(text("SELECT par_email_fk, stud_email_fk FROM par_stud ORDER BY 1, 2")).all()
    assert restantes == [("madre.pablo@mail.es", "ana@autovida.es"), ("padre.pablo@mail.es", "pablo@autovida.es")]
    assert count_rows(db_session, "staff_stud") == 1
    assert count_rows(db_session, "parents") == 2           # las cuentas siguen ahí
    assert count_rows(db_session, "student") == 2
    # la madre sigue accediendo a su otra alumna
    assert client.get("/associations/students/ana@autovida.es", headers=as_user(MADRE)).status_code == 200


def test_desasociar_inexistente(client):
    r = delete(client, "parent", "madre.pablo@mail.es", "pablo@autovida.es")
    assert r.status_code == 404
    assert r.json()["detail"] == "La asociación no existe"


@pytest.mark.parametrize("user", [STAFF, MADRE, PABLO])
def test_solo_admin_puede_desasociar(client, db_session, user):
    associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es"])
    assert delete(client, "parent", "madre.pablo@mail.es", "pablo@autovida.es", user=user).status_code == 403
    assert count_rows(db_session, "par_stud") == 1          # la relación permanece


def test_si_se_cancela_la_relacion_permanece(client, db_session):
    # Cancelar en la app = no enviar la petición DELETE. La relación debe seguir intacta.
    associate(client, "pablo@autovida.es", "parent", ["madre.pablo@mail.es"])
    assert count_rows(db_session, "par_stud") == 1
    assert client.get("/associations/students/pablo@autovida.es", headers=as_user(MADRE)).status_code == 200
