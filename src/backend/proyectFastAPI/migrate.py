"""Explicit, repeatable migrations; never changes the database during import."""
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import text

load_dotenv(Path(__file__).with_name('.env'))
from .DB.database import engine


def migrate() -> None:
    with engine.begin() as connection:
        connection.execute(text("SELECT pg_advisory_xact_lock(73626191)"))
        connection.exec_driver_sql(
            "CREATE TABLE IF NOT EXISTS autovida_migrations "
            "(name TEXT PRIMARY KEY, applied_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP)"
        )
        for path in sorted(Path(__file__).with_name('migrations').glob('*.sql')):
            if connection.execute(text("SELECT 1 FROM autovida_migrations WHERE name=:name"),
                                  {"name": path.name}).scalar_one_or_none():
                continue
            connection.exec_driver_sql(path.read_text(encoding='utf-8'))
            connection.execute(text("INSERT INTO autovida_migrations(name) VALUES (:name)"),
                               {"name": path.name})
            print(f"Applied {path.name}")


if __name__ == '__main__':
    migrate()
