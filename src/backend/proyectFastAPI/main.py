
from fastapi import FastAPI, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from DB.database import get_db
from auth.router import router as auth_router
from gestion_asociaciones.assoc_mng_backend import router as associations_router
from gestion_usuarios.users_mng_backend import router as users_router



app = FastAPI(title="AUTOVIDA API")
app.include_router(auth_router)
app.include_router(associations_router)
app.include_router(users_router)



@app.get("/")
def comprobar_conexion(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    return {"estado": "ok", "mensaje": "¡FastAPI conectado con éxito a PostgreSQL!"}
