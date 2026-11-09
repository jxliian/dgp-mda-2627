"""Resto de historias del sprint 1: crear y modificar usuarios, tareas propias del alumno,
clases, tareas de clase y foto de perfil."""
import struct
import zlib

from sqlalchemy import text

from conftest import LUNES, as_user

AJUSTES_ALUMNO = {
    "stud_access_main_col": "#ffffff",
    "stud_access_sec_col": "#000000",
    "stud_access_ntasks_visible": 5,
    "stud_access_pictograms": True,
    "stud_access_contrast": False,
    "stud_access_fontsize": 18,
    "stud_access_filters": True,
    "stud_access_ndays_visible": 7,
    "stud_access_prof_mod": False,
    "stud_access_timebar": True,
    "stud_access_talkback": False,
    "stud_access_profile_mod": True,
    "stud_access_task_mod": True,
}


def _bloque_png(tipo, datos):
    return struct.pack(">I", len(datos)) + tipo + datos + struct.pack(">I", zlib.crc32(tipo + datos))


PNG = (
    b"\x89PNG\r\n\x1a\n"
    + _bloque_png(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
    + _bloque_png(b"IDAT", zlib.compress(b"\x00\xff\x00\x00"))
    + _bloque_png(b"IEND", b"")
)
JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 32 + b"\xff\xd9"
_CUERPO_WEBP = b"WEBPVP8 " + b"\x00" * 24
WEBP = b"RIFF" + struct.pack("<I", len(_CUERPO_WEBP)) + _CUERPO_WEBP


def subir_foto(client, usuario, contenido, nombre="foto"):
    return client.put(
        "/users/students/me/avatar", files={"file": (nombre, contenido)}, headers=as_user(usuario)
    )


def crear_tarea_propia(client, usuario="pablo", hora="17:00"):
    body = {"task_title": "Mia", "task_date": LUNES, "task_duration": 30}
    if hora is not None:
        body["task_start_hour"] = hora
    return client.post("/student-tasks/me", json=body, headers=as_user(usuario))


def crear_tarea_individual(client, usuario, hora):
    body = {"task_title": "Tarea", "task_date": LUNES, "task_start_hour": hora, "task_duration": 30}
    return client.post("/student-tasks/students/pablo", json=body, headers=as_user(usuario))


def crear_tarea_de_clase(client, usuario="lucia"):
    body = {"task_title": "Clase", "task_date": LUNES, "task_start_hour": "10:00", "task_duration": 30}
    return client.post("/classes/1A/tasks", json=body, headers=as_user(usuario))


# ---------------------------------------------------------- crear usuarios

def test_admin_crea_un_alumno_que_puede_entrar(client):
    body = {"username": "luis", "full_name": "Luis Perez", "password": "Clave", "role": "student", **AJUSTES_ALUMNO}
    assert client.post("/users", json=body, headers=as_user("admin")).status_code == 200
    datos = {"username": "luis", "password": "Clave", "role": "student"}
    assert client.post("/auth/login", json=datos).status_code == 200


def test_admin_crea_cuentas_con_correo(client, count):
    for rol in ["admin", "staff", "parent"]:
        body = {"username": f"n{rol}", "full_name": "Nombre", "password": "x", "role": rol, "email": f"n{rol}@mail.es"}
        assert client.post("/users", json=body, headers=as_user("admin")).status_code == 200
    assert count("users WHERE username LIKE 'n%'") == 3


def test_no_se_repiten_usuario_ni_correo(client):
    base = {"full_name": "Nombre", "password": "x", "role": "parent"}
    cabecera = as_user("admin")
    assert client.post("/users", json={**base, "username": "madre", "email": "z@mail.es"}, headers=cabecera).status_code == 409
    assert client.post("/users", json={**base, "username": "nueva", "email": "madre@mail.es"}, headers=cabecera).status_code == 409


def test_solo_el_admin_crea_usuarios(client):
    body = {"username": "x1", "full_name": "Nombre", "password": "x", "role": "parent", "email": "x1@mail.es"}
    assert client.post("/users", json=body, headers=as_user("lucia")).status_code == 403


# ------------------------------------------------------ modificar usuarios

def test_admin_modifica_nombre_y_correo(client, count):
    body = {"full_name": "Otra", "email": "nueva@mail.es"}
    assert client.put("/users/parent/madre", json=body, headers=as_user("admin")).status_code == 200
    assert count("Parents WHERE par_email = 'nueva@mail.es'") == 1
    assert count("users WHERE username = 'madre' AND full_name = 'Otra'") == 1


def test_cambiar_la_contrasena_cierra_la_sesion(client):
    cabecera = as_user("madre")
    assert client.put("/users/parent/madre", json={"password": "Nueva1"}, headers=as_user("admin")).status_code == 200
    assert client.get("/student-links/parents/madre/students", headers=cabecera).status_code == 401
    datos = {"username": "madre", "password": "Nueva1", "role": "parent"}
    assert client.post("/auth/login", json=datos).status_code == 200


def test_renombrar_un_alumno_conserva_sus_vinculos(client, count):
    assert crear_tarea_de_clase(client).status_code == 201
    assert client.put("/users/student/pablo", json={"username": "pablito"}, headers=as_user("admin")).status_code == 200
    assert count("class_stud WHERE stud_usr_fk = 'pablito'") == 1
    assert count("par_stud WHERE stud_usr_fk = 'pablito'") == 1
    assert count("stud_task WHERE stud_usr_fk = 'pablito'") == 1


def test_renombrar_al_personal_actualiza_el_autor_de_sus_tareas(client, count):
    crear_tarea_individual(client, "lucia", "10:00")
    assert client.put("/users/staff/lucia", json={"username": "lucia2"}, headers=as_user("admin")).status_code == 200
    assert count("Tasks WHERE task_creator = 'lucia2'") == 1


def test_sin_ser_admin_no_se_editan_otras_cuentas_ni_el_nombre(client):
    assert client.put("/users/parent/otra_madre", json={"password": "x"}, headers=as_user("madre")).status_code == 403
    assert client.put("/users/parent/madre", json={"full_name": "Otro"}, headers=as_user("madre")).status_code == 403


def test_no_se_puede_cambiar_el_rol(client):
    assert client.put("/users/parent/madre", json={"role": "staff"}, headers=as_user("admin")).status_code == 403


# ----------------------------------------------- consulta y tareas del alumno

def test_admin_consulta_los_alumnos_de_un_tutor(client):
    r = client.get("/student-links/parents/madre/students", headers=as_user("admin"))
    assert r.status_code == 200
    assert [a["username"] for a in r.json()["students"]] == ["pablo"]


def test_el_alumno_crea_y_elimina_su_tarea(client, count):
    r = crear_tarea_propia(client)
    assert r.status_code == 201
    assert r.json()["task_creator"] == "pablo"
    tarea = r.json()["task_id"]
    borrado = client.delete(f"/student-tasks/me/{tarea}", params={"task_date": LUNES}, headers=as_user("pablo"))
    assert borrado.status_code == 200
    assert count("Tasks WHERE task_id = :t", t=tarea) == 0


def test_el_alumno_crea_una_tarea_sin_hora(client):
    assert crear_tarea_propia(client, hora=None).status_code == 201


def test_el_alumno_no_crea_en_horario_escolar(client):
    assert crear_tarea_propia(client, hora="10:00").status_code == 400


def test_el_alumno_sin_permiso_no_crea_tareas(client, engine):
    with engine.begin() as conn:
        conn.execute(text("UPDATE Student SET stud_access_task_mod = FALSE WHERE stud_usr = 'pablo'"))
    assert crear_tarea_propia(client).status_code == 403


def test_el_alumno_no_elimina_tareas_de_otros(client, count):
    tarea = crear_tarea_individual(client, "madre", "17:00").json()["task_id"]
    r = client.delete(f"/student-tasks/me/{tarea}", params={"task_date": LUNES}, headers=as_user("pablo"))
    assert r.status_code == 404
    assert count("stud_task WHERE task_id_fk = :t", t=tarea) == 1


def test_un_adulto_no_usa_las_rutas_del_alumno(client):
    assert crear_tarea_propia(client, usuario="madre").status_code == 403


# ------------------------------------------------------------------ clases

def test_admin_crea_edita_y_borra_una_clase(client, count):
    cabecera = as_user("admin")
    assert client.post("/classes", json={"class_name": "3C"}, headers=cabecera).status_code == 201
    assert client.post("/classes", json={"class_name": "3C"}, headers=cabecera).status_code == 409
    assert client.put("/classes/3C", json={"class_name": "3D"}, headers=cabecera).status_code == 200
    assert count("Class WHERE class_name = '3D'") == 1
    assert client.put("/classes/3D", json={"class_name": "1A"}, headers=cabecera).status_code == 409
    assert client.delete("/classes/3D", headers=cabecera).status_code == 200
    assert count("Class WHERE class_name = '3D'") == 0


def test_solo_el_admin_gestiona_las_clases(client):
    cabecera = as_user("lucia")
    assert client.post("/classes", json={"class_name": "X"}, headers=cabecera).status_code == 403
    assert client.put("/classes/1A", json={"class_name": "X"}, headers=cabecera).status_code == 403
    assert client.delete("/classes/1A", headers=cabecera).status_code == 403


def test_renombrar_una_clase_conserva_alumnos_y_tareas(client, count):
    assert crear_tarea_de_clase(client).status_code == 201
    assert client.put("/classes/1A", json={"class_name": "1Z"}, headers=as_user("admin")).status_code == 200
    assert count("stud_task WHERE class_name_fk = '1Z'") == 1
    assert count("class_stud WHERE class_name_fk = '1Z'") == 1


def test_borrar_una_clase_borra_sus_tareas_y_no_los_alumnos(client, count):
    tarea = crear_tarea_de_clase(client).json()["task_id"]
    assert client.delete("/classes/1A", headers=as_user("admin")).status_code == 200
    assert count("stud_task WHERE task_id_fk = :t", t=tarea) == 0
    assert count("Tasks WHERE task_id = :t", t=tarea) == 0
    assert count("Student WHERE stud_usr = 'pablo'") == 1


def test_el_personal_consulta_solo_sus_clases(client):
    r = client.get("/classes", headers=as_user("lucia"))
    assert [c["class_name"] for c in r.json()["classes"]] == ["1A"]
    assert client.get("/classes/1A", headers=as_user("lucia")).status_code == 200
    assert client.get("/classes/2B", headers=as_user("lucia")).status_code == 403
    assert client.get("/classes", headers=as_user("madre")).status_code == 403


def test_el_admin_no_apunta_alumnos_a_una_clase(client, count):
    assert client.post("/classes/1A/students/ana", headers=as_user("admin")).status_code == 403
    assert count("class_stud WHERE stud_usr_fk = 'ana'") == 0


def test_un_alumno_nuevo_recibe_las_tareas_de_su_clase(client, count):
    crear_tarea_de_clase(client)
    r = client.post("/classes/1A/students/ana", headers=as_user("lucia"))
    assert r.json()["class_tasks_assigned"] == 1
    assert count("stud_task WHERE stud_usr_fk = 'ana'") == 1


def test_sacar_a_un_alumno_quita_solo_las_tareas_de_clase(client, count):
    crear_tarea_de_clase(client)
    crear_tarea_individual(client, "lucia", "11:00")
    assert client.delete("/classes/1A/students/pablo", headers=as_user("lucia")).status_code == 200
    assert count("stud_task WHERE stud_usr_fk = 'pablo' AND class_name_fk IS NOT NULL") == 0
    assert count("stud_task WHERE stud_usr_fk = 'pablo' AND class_name_fk IS NULL") == 1


# --------------------------------------------------------- tareas de clase

def test_el_personal_consulta_las_tareas_de_su_clase(client):
    tarea = crear_tarea_de_clase(client).json()["task_id"]
    r = client.get("/classes/1A/tasks", headers=as_user("lucia"))
    assert r.status_code == 200
    assert (r.json()["tasks"][0]["task_id"], r.json()["tasks"][0]["students"]) == (tarea, ["pablo"])


def test_el_personal_modifica_una_tarea_de_clase(client, count):
    tarea = crear_tarea_de_clase(client).json()["task_id"]
    body = {"task_title": "Nuevo", "task_date": "2026-11-17", "task_start_hour": "11:00", "task_duration": 20}
    r = client.put(f"/classes/1A/tasks/{tarea}", json=body, headers=as_user("lucia"))
    assert r.status_code == 200
    assert r.json()["task_title"] == "Nuevo"
    assert count("stud_task WHERE task_id_fk = :t", t=tarea) == 1
    assert count("stud_task WHERE task_id_fk = :t AND task_date = '2026-11-17'", t=tarea) == 1


def test_una_tarea_de_clase_no_se_mueve_fuera_del_horario(client):
    tarea = crear_tarea_de_clase(client).json()["task_id"]
    body = {"task_title": "Nuevo", "task_date": LUNES, "task_start_hour": "17:00", "task_duration": 20}
    assert client.put(f"/classes/1A/tasks/{tarea}", json=body, headers=as_user("lucia")).status_code == 400


def test_el_personal_elimina_una_tarea_de_clase(client, count):
    tarea = crear_tarea_de_clase(client).json()["task_id"]
    assert client.delete(f"/classes/1A/tasks/{tarea}", headers=as_user("lucia")).status_code == 200
    assert count("stud_task WHERE task_id_fk = :t", t=tarea) == 0
    assert count("Tasks WHERE task_id = :t", t=tarea) == 0


def test_personal_de_otra_clase_no_gestiona_sus_tareas(client):
    tarea = crear_tarea_de_clase(client).json()["task_id"]
    assert crear_tarea_de_clase(client, usuario="pedro").status_code == 403
    assert client.get("/classes/1A/tasks", headers=as_user("pedro")).status_code == 403
    assert client.delete(f"/classes/1A/tasks/{tarea}", headers=as_user("pedro")).status_code == 403


# --------------------------------------------------------- foto de perfil

def test_el_alumno_sube_un_png(client):
    assert subir_foto(client, "pablo", PNG).status_code == 200
    foto = client.get("/users/students/me/avatar", headers=as_user("pablo"))
    assert foto.headers["content-type"] == "image/png"
    assert foto.content == PNG


def test_el_alumno_sube_un_jpeg(client):
    assert subir_foto(client, "pablo", JPEG).status_code == 200
    foto = client.get("/users/students/me/avatar", headers=as_user("pablo"))
    assert foto.headers["content-type"] == "image/jpeg"


def test_el_alumno_sube_un_webp(client):
    assert subir_foto(client, "pablo", WEBP).status_code == 200


def test_cambiar_la_foto_no_acumula_imagenes(client, count):
    subir_foto(client, "pablo", JPEG)
    subir_foto(client, "pablo", WEBP)
    assert count("Avatar") == 1


def test_sin_foto_se_ve_la_imagen_por_defecto(client):
    r = client.get("/users/students/me/avatar", headers=as_user("pablo"))
    assert r.headers["content-type"].startswith("image/svg+xml")


def test_se_rechazan_ficheros_invalidos_o_demasiado_grandes(client):
    assert subir_foto(client, "pablo", b"hola").status_code == 422
    assert subir_foto(client, "pablo", b"\xff\xd8\xff" + b"0" * (5 * 1024 * 1024 + 1)).status_code == 413


def test_solo_un_alumno_sube_su_foto(client):
    assert subir_foto(client, "madre", JPEG).status_code == 403


def test_admin_y_personal_de_su_clase_ven_la_foto(client):
    subir_foto(client, "pablo", JPEG)
    assert client.get("/users/students/pablo/avatar-image", headers=as_user("lucia")).status_code == 200
    assert client.get("/users/students/pablo/avatar-image", headers=as_user("admin")).status_code == 200
    assert client.get("/users/students/pablo/avatar-image", headers=as_user("pedro")).status_code == 403


def test_la_familia_no_ve_la_foto(client):
    subir_foto(client, "pablo", JPEG)
    assert client.get("/users/students/pablo/avatar-image", headers=as_user("madre")).status_code == 403
