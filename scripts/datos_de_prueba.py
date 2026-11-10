"""Crea el esquema y unas cuentas de prueba en la base de datos local.

Vive fuera de `src/backend` a propósito: el backend es el de la rama `main` y
no se toca. Este script solo usa sus funciones públicas, igual que haría
cualquier cliente.

    python scripts/datos_de_prueba.py        # crea lo que falte
    python scripts/datos_de_prueba.py --borrar   # vacía y vuelve a crear

La contraseña de todas las cuentas de prueba es 1234.
"""
import sys
from datetime import date, time
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
BACKEND = RAIZ / 'src' / 'backend'
ESQUEMA = RAIZ / 'docs/diseno_arquitectura/modelado_datos/CreacionTablas.sqlscript'
sys.path.insert(0, str(BACKEND))

from dotenv import load_dotenv  # noqa: E402

load_dotenv(BACKEND / 'proyectFastAPI' / '.env')

from sqlalchemy import inspect, text  # noqa: E402

from proyectFastAPI.DB.database import SessionLocal, engine  # noqa: E402
from proyectFastAPI.clases import clases_db  # noqa: E402
from proyectFastAPI.gestion_usuarios.users_mng_db import users_mng_db  # noqa: E402

# El backend exige que un alumno traiga todos sus ajustes de accesibilidad.
# Los apoyos nacen apagados; se encienden uno a uno según cada alumno.
AJUSTES_DE_ALUMNO = {
    'stud_access_main_col': '#fbf9f5',
    'stud_access_sec_col': '#1b4332',
    'stud_access_ntasks_visible': 2,
    'stud_access_pictograms': False,
    'stud_access_contrast': False,
    'stud_access_fontsize': 20,
    'stud_access_filters': False,
    'stud_access_ndays_visible': 7,
    'stud_access_prof_mod': False,
    'stud_access_timebar': False,
    'stud_access_talkback': False,
    'stud_access_profile_mod': True,
    'stud_access_task_mod': True,
}

CUENTAS = [
    ('admin', 'admin', 'Administración de prueba', 'admin@example.com'),
    ('lucia', 'staff', 'Lucía Martín', 'lucia@example.com'),
    ('familia', 'parent', 'Elena García', 'familia@example.com'),
    ('pablo', 'student', 'Pablo García', None),
    ('ana', 'student', 'Ana García', None),
]

AULAS = ['Aula de la autonomía', 'Taller de reprografía']
PERSONAL_POR_AULA = [('Aula de la autonomía', 'lucia'), ('Taller de reprografía', 'lucia')]
ALUMNOS_POR_AULA = [('Aula de la autonomía', 'pablo'), ('Aula de la autonomía', 'ana')]
FAMILIAS = [('familia', 'pablo'), ('familia', 'ana')]

TAREAS_DE_AULA = [
    ('Aula de la autonomía', 'Preparar la mochila', time(9, 0), 15),
    ('Aula de la autonomía', 'Regar las plantas', time(10, 30), 20),
]


def crear_esquema_si_falta() -> None:
    if inspect(engine).has_table('users'):
        return
    print('Creando el esquema a partir de CreacionTablas.sqlscript')
    with engine.begin() as conexion:
        conexion.exec_driver_sql(ESQUEMA.read_text(encoding='utf-8').replace('COMMIT;', ''))


def borrar_datos() -> None:
    print('Vaciando las tablas')
    with engine.begin() as conexion:
        conexion.exec_driver_sql(
            'TRUNCATE stud_task, class_task, par_stud, class_stud, class_staff, '
            'Steps, Generic_Task, Tasks, Class, Avatar, Student, Parents, Staff, '
            'Admn, users RESTART IDENTITY CASCADE'
        )


def crear_cuentas(db) -> None:
    for username, rol, nombre, correo in CUENTAS:
        resultado = users_mng_db.createUser(
            db, username, '1234', rol, nombre, correo,
            access_settings=AJUSTES_DE_ALUMNO if rol == 'student' else None,
        )
        if resultado['errorCode']:
            raise SystemExit(f'No se pudo crear «{username}»: {resultado}')
        print(f'  cuenta {username} ({rol})')


def crear_aulas(db) -> None:
    for aula in AULAS:
        db.execute(text('INSERT INTO Class VALUES (:nombre)'), {'nombre': aula})
    for aula, usuario in PERSONAL_POR_AULA:
        db.execute(text('INSERT INTO class_staff VALUES (:aula,:usuario)'),
                   {'aula': aula, 'usuario': usuario})
    for aula, usuario in ALUMNOS_POR_AULA:
        db.execute(text('INSERT INTO class_stud VALUES (:aula,:usuario)'),
                   {'aula': aula, 'usuario': usuario})
    for tutor, alumno in FAMILIAS:
        db.execute(text('INSERT INTO par_stud VALUES (:tutor,:alumno)'),
                   {'tutor': tutor, 'alumno': alumno})
    db.commit()
    print(f'  {len(AULAS)} aulas con su personal, alumnos y familias')


def crear_tareas(db) -> None:
    for aula, titulo, hora, duracion in TAREAS_DE_AULA:
        clases_db.assign_task(db, aula, 'lucia', titulo, date.today(), hora, duracion, None)
        print(f'  tarea de aula «{titulo}»')


def main() -> None:
    crear_esquema_si_falta()
    if '--borrar' in sys.argv:
        borrar_datos()
    with SessionLocal() as db:
        if db.execute(text('SELECT COUNT(*) FROM users')).scalar_one():
            print('La base ya tiene cuentas; no se ha cambiado nada.')
            return
        print('Creando datos de prueba')
        crear_cuentas(db)
        crear_aulas(db)
        crear_tareas(db)
    print('Listo. Cuentas: admin, lucia, familia, pablo, ana. Contraseña: 1234.')


if __name__ == '__main__':
    main()
