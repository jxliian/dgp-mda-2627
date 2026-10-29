from fastapi import FastAPI, Depends
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session

# Usamos las credenciales del docker-compose
DATABASE_URL = "postgresql://autovida_admin:Clench1234@localhost:5432/autovida_db"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

app = FastAPI(title="AUTOVIDA API")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/")
def comprobar_conexion(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    return {"estado": "ok", "mensaje": "¡FastAPI conectado con éxito a PostgreSQL!"}
