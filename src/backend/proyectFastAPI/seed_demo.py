"""Create fictional data only in a database whose name ends in _demo.

Run from src/backend: python -m proyectFastAPI.seed_demo
"""
import os
from pathlib import Path
import re

from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect, text

load_dotenv(Path(__file__).with_name('.env'))


def seed_demo() -> None:
    from .DB.database import DATABASE_URL, engine
    from .gestion_usuarios.users_mng_db import users_mng_db

    name = DATABASE_URL.database or ''
    if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*_demo', name):
        raise SystemExit('DB_NAME must end in _demo. Development and production databases are not seeded.')
    server = create_engine(DATABASE_URL.set(database='postgres'), isolation_level='AUTOCOMMIT')
    with server.connect() as conn:
        exists = conn.execute(text('SELECT 1 FROM pg_database WHERE datname=:name'), {'name': name}).scalar()
        if not exists:
            conn.exec_driver_sql('CREATE DATABASE ' + server.dialect.identifier_preparer.quote(name))
    server.dispose()
    if not inspect(engine).has_table('users'):
        schema = Path(__file__).resolve().parents[3] / 'docs/diseno_arquitectura/modelado_datos/CreacionTablas.sqlscript'
        with engine.begin() as conn:
            conn.exec_driver_sql(schema.read_text(encoding='utf-8').replace('COMMIT;', ''))
    from .migrate import migrate
    migrate()
    from .DB.database import SessionLocal
    with SessionLocal() as db:
        if db.execute(text('SELECT COUNT(*) FROM users')).scalar_one():
            print('Demo database already contains accounts; nothing was changed.')
            return
        access = {'stud_access_main_col':'#ffffff','stud_access_sec_col':'#00695c',
            'stud_access_ntasks_visible':3,'stud_access_pictograms':True,'stud_access_contrast':False,
            'stud_access_fontsize':20,'stud_access_filters':True,'stud_access_ndays_visible':7,
            'stud_access_prof_mod':False,'stud_access_timebar':True,'stud_access_talkback':True,
            'stud_access_profile_mod':True,'stud_access_task_mod':True}
        for username, role, full_name in [('admin','admin','Administración de prueba'),
            ('lucia','staff','Lucía Martín'),('familia','parent','Elena García'),
            ('pablo','student','Pablo García'),('ana','student','Ana García')]:
            result = users_mng_db.createUser(db, username,'1234',role,full_name,
                None if role=='student' else f'{username}@example.com', access_settings=access if role=='student' else None)
            if result['errorCode']:
                raise RuntimeError('Could not create demo accounts')
        db.execute(text("INSERT INTO Class VALUES ('Aula de la autonomía'),('Taller de reprografía')"))
        db.execute(text("INSERT INTO class_staff VALUES ('Aula de la autonomía','lucia'),('Taller de reprografía','lucia')"))
        db.execute(text("INSERT INTO class_stud VALUES ('Aula de la autonomía','pablo'),('Aula de la autonomía','ana')"))
        db.execute(text("INSERT INTO par_stud VALUES ('familia','pablo'),('familia','ana')"))
        db.commit()
    from datetime import date, time
    from .clases.clases_db import assign_task
    from .activity_content import ActivityFields, save_content
    with SessionLocal() as db:
        task = assign_task(db,'Aula de la autonomía','lucia','Preparar la mochila',date.today(),time(9),15,None,commit=False)
        save_content(db,task['task_id'],ActivityFields(steps=[
            {'step_title':'Buscar la mochila','step_description':'Pon la mochila sobre la mesa.','step_duration':5},
            {'step_title':'Guardar el material','step_description':'Guarda el cuaderno y el estuche.','step_duration':5},
            {'step_title':'Cerrar la mochila','step_description':'Cierra la cremallera.','step_duration':5},
        ]))
        db.commit()
    print('Fictional accounts created: admin, lucia, familia, pablo, ana. Password: 1234.')


if __name__ == '__main__':
    seed_demo()
