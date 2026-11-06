from dotenv import load_dotenv
from fastapi import Depends, FastAPI
from sqlalchemy import text
from sqlalchemy.orm import Session

load_dotenv()

from .DB.database import get_db
from .asociaciones_alumnos.studs_links_backend import router as student_links_router
from .auth.auth_backend import router as auth_router
from .gestion_usuarios.users_mng_backend import router as users_router

app = FastAPI(title="AUTOVIDA API")
app.include_router(auth_router)
app.include_router(users_router)
app.include_router(student_links_router)


@app.get("/", tags=["health"])
def comprobar_conexion(db: Session = Depends(get_db)) -> dict:
    """Comprueba que la API puede ejecutar una consulta en PostgreSQL."""
    db.execute(text("SELECT 1"))
    return {"estado": "ok", "mensaje": "API conectada a PostgreSQL"}
