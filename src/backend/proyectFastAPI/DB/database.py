import os
from typing import Generator
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session


DATABASE_URL = "postgresql://autovida_admin:Clench1234@localhost:5432/autovida_db"

engine = create_engine(
    DATABASE_URL,
    pool_size = 10, # Número máximo de conexiones abiertas en segundo plano
    max_overflow = 20, # Conexiones adicionales en picos de tráfico
    pool_pre_ping = True, # Verifica que la conexión funciona antes de conectarse
    echo = False # No muestra logs de SQL en consola
)

SessionLocal = sessionmaker(
    autocommit=False, 
    autoflush=False, 
    bind=engine
)

# Abre sesión de base de datos y la cierra al finalizar la respuesta
def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()