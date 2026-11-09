from importlib import import_module

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

load_dotenv()

from .DB.database import get_db
from .asociaciones_alumnos.studs_links_backend import router as student_links_router
from .auth.auth_backend import router as auth_router
from .clases.clases_backend import router as classes_router
from .errors import ErrorCode, code_for_http_status, error_response, success_response
from .gestion_usuarios.users_mng_backend import router as users_router

student_tasks_router = import_module(
    ".tareas alumnos.studs_tasks_backend", package=__package__
).router

app = FastAPI(title="AUTOVIDA API")
app.include_router(auth_router)
app.include_router(users_router)
app.include_router(student_links_router)
app.include_router(student_tasks_router)
app.include_router(classes_router)


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    """Devuelve errores HTTP en el formato JSON común de la API."""
    if isinstance(exc.detail, dict) and "errorCode" in exc.detail and "details" in exc.detail:
        body = exc.detail
    else:
        body = error_response(code_for_http_status(exc.status_code))
    return JSONResponse(
        status_code=exc.status_code,
        content=body,
        headers=exc.headers,
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """Representa errores de validación sin incluir datos enviados por el cliente."""
    return JSONResponse(
        status_code=422,
        content=error_response(ErrorCode.INVALID_REQUEST),
    )


@app.exception_handler(Exception)
async def unexpected_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Oculta detalles internos, incluidos errores de la base de datos."""
    return JSONResponse(
        status_code=500,
        content=error_response(ErrorCode.INTERNAL_ERROR),
    )


@app.get("/", tags=["health"])
def comprobar_conexion(db: Session = Depends(get_db)) -> dict:
    """Comprueba que la API puede ejecutar una consulta en PostgreSQL."""
    db.execute(text("SELECT 1"))
    return success_response(estado="ok", mensaje="API conectada a PostgreSQL")
