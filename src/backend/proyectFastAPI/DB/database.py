from typing import Generator
import os

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.engine import URL

DATABASE_URL = URL.create(
    "postgresql+psycopg2",
    username=os.environ.get("DB_USER", "autovida_admin"),
    password=os.environ.get("DB_PASSWORD"),
    host=os.environ.get("DB_HOST", "localhost"),
    port=int(os.environ.get("DB_PORT", "5432")),
    database=os.environ.get("DB_NAME", "autovida_db"),
)
if not DATABASE_URL.password:
    raise RuntimeError("Define DB_PASSWORD en el entorno antes de iniciar la API")

engine = create_engine(
    DATABASE_URL,
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,
    echo=False,
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

def get_db() -> Generator[Session, None, None]:
    """Proporciona una sesión de base de datos y la cierra al terminar la petición."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
