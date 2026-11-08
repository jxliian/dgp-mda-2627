"""Catálogo y utilidades para respuestas de error consistentes de la API."""

from enum import IntEnum

from fastapi import HTTPException


class ErrorCode(IntEnum):
    """Códigos estables de error que puede interpretar el frontend."""

    SUCCESS = 0
    INVALID_CREDENTIALS = 1001
    INVALID_TOKEN = 1002
    ADMIN_REQUIRED = 1003
    ASSOCIATION_ACCESS_DENIED = 1004
    INVALID_REQUEST = 1005
    USER_NOT_FOUND = 1006
    EMAIL_UNAVAILABLE = 1007
    EMAIL_USER_NOT_FOUND = 1008
    INVALID_ROLE = 1009
    EMAIL_REQUIRED = 1010
    LAST_ADMIN = 1011
    NO_UPDATE_FIELDS = 1012
    ASSOCIATED_ENTITY_NOT_FOUND = 1013
    ASSOCIATION_NOT_FOUND = 1014
    INVALID_ASSOCIATION_TYPE = 1015
    ROUTE_NOT_FOUND = 1016
    TASK_CREATOR_REQUIRED = 1017
    TASK_STUDENT_NOT_FOUND = 1018
    TASK_STUDENT_NOT_ASSOCIATED = 1019
    ALTERNATIVE_TASK_NOT_FOUND = 1020
    TASK_NOT_FOUND = 1021
    ALTERNATIVE_TASK_ALREADY_ASSIGNED = 1022
    STAFF_TASK_OUTSIDE_SCHOOL_HOURS = 1023
    PARENT_TASK_DURING_SCHOOL_HOURS = 1024
    PARENT_DELETE_DURING_SCHOOL_HOURS = 1025
    STAFF_DELETE_OUTSIDE_SCHOOL_HOURS = 1026
    USERNAME_TAKEN = 1027
    EMAIL_TAKEN = 1028
    PROFILE_UPDATE_DENIED = 1029
    CLASS_NOT_FOUND = 1030
    CLASS_NAME_TAKEN = 1031
    CLASS_ACCESS_DENIED = 1032
    STUDENT_ALREADY_IN_CLASS = 1033
    CLASS_STAFF_NOT_FOUND = 1034
    CLASS_HAS_NO_STUDENTS = 1035
    AVATAR_INVALID_IMAGE = 1036
    AVATAR_TOO_LARGE = 1037
    ROLE_CHANGE_DENIED = 1038
    STUDENT_TASK_MODIFICATION_DENIED = 1039
    STUDENT_TASK_OUTSIDE_SCHOOL_HOURS = 1040
    USER_LOOKUP_FAILED = 1501
    USER_LIST_FAILED = 1502
    PASSWORD_UPDATE_FAILED = 1503
    USER_CREATE_FAILED = 1504
    USER_DELETE_FAILED = 1505
    USER_UPDATE_FAILED = 1506
    AVATAR_UPDATE_FAILED = 1507
    LOGIN_FAILED = 1508
    INTERNAL_ERROR = 1500


# Each entry defines the public message and HTTP status for one error code.
ERRORS: dict[ErrorCode, tuple[int, str]] = {
    ErrorCode.INVALID_CREDENTIALS: (401, "Usuario o contraseña incorrectos"),
    ErrorCode.INVALID_TOKEN: (401, "Token ausente o inválido"),
    ErrorCode.ADMIN_REQUIRED: (403, "Se requiere una sesión de administrador"),
    ErrorCode.ASSOCIATION_ACCESS_DENIED: (403, "Solo puedes consultar los alumnos asociados a tu propia cuenta"),
    ErrorCode.INVALID_REQUEST: (422, "La solicitud contiene datos inválidos"),
    ErrorCode.USER_NOT_FOUND: (404, "Usuario no encontrado"),
    ErrorCode.EMAIL_UNAVAILABLE: (400, "Los estudiantes no tienen correo electrónico"),
    ErrorCode.EMAIL_USER_NOT_FOUND: (404, "Usuario no encontrado por correo"),
    ErrorCode.INVALID_ROLE: (400, "Rol no válido"),
    ErrorCode.EMAIL_REQUIRED: (400, "El correo electrónico es obligatorio"),
    ErrorCode.LAST_ADMIN: (400, "No se puede eliminar el último administrador"),
    ErrorCode.NO_UPDATE_FIELDS: (400, "Debe indicarse al menos un campo para editar"),
    ErrorCode.ASSOCIATED_ENTITY_NOT_FOUND: (404, "No se encontró el usuario o la asociación"),
    ErrorCode.ASSOCIATION_NOT_FOUND: (404, "La asociación no existe"),
    ErrorCode.INVALID_ASSOCIATION_TYPE: (400, "Tipo de usuario asociado no válido"),
    ErrorCode.ROUTE_NOT_FOUND: (404, "Ruta no encontrada"),
    ErrorCode.TASK_CREATOR_REQUIRED: (403, "Se requiere una sesión autorizada de personal, tutor o alumno"),
    ErrorCode.TASK_STUDENT_NOT_FOUND: (404, "Alumno no encontrado"),
    ErrorCode.TASK_STUDENT_NOT_ASSOCIATED: (403, "El alumno no está asociado a tu cuenta"),
    ErrorCode.ALTERNATIVE_TASK_NOT_FOUND: (404, "La tarea alternativa no existe"),
    ErrorCode.TASK_NOT_FOUND: (404, "Tarea no encontrada"),
    ErrorCode.ALTERNATIVE_TASK_ALREADY_ASSIGNED: (409, "La tarea alternativa ya está asociada a otra tarea"),
    ErrorCode.STAFF_TASK_OUTSIDE_SCHOOL_HOURS: (400, "La tarea completa del personal debe quedar entre las 09:00 y las 15:00"),
    ErrorCode.PARENT_TASK_DURING_SCHOOL_HOURS: (400, "La tarea completa del tutor no puede coincidir con el horario escolar"),
    ErrorCode.PARENT_DELETE_DURING_SCHOOL_HOURS: (400, "Los tutores no pueden eliminar tareas programadas durante el horario escolar"),
    ErrorCode.STAFF_DELETE_OUTSIDE_SCHOOL_HOURS: (400, "El personal no puede eliminar tareas programadas fuera del horario escolar"),
    ErrorCode.USERNAME_TAKEN: (409, "Ya existe un usuario con ese nombre de usuario"),
    ErrorCode.EMAIL_TAKEN: (409, "Ya existe un usuario con ese correo electrónico en el rol indicado"),
    ErrorCode.PROFILE_UPDATE_DENIED: (403, "No tienes permiso para modificar este perfil"),
    ErrorCode.CLASS_NOT_FOUND: (404, "Clase no encontrada"),
    ErrorCode.CLASS_NAME_TAKEN: (409, "Ya existe una clase con ese nombre"),
    ErrorCode.CLASS_ACCESS_DENIED: (403, "No tienes permiso para gestionar esta clase"),
    ErrorCode.STUDENT_ALREADY_IN_CLASS: (409, "El alumno ya pertenece a otra clase"),
    ErrorCode.CLASS_STAFF_NOT_FOUND: (404, "No se encontró el miembro del personal"),
    ErrorCode.CLASS_HAS_NO_STUDENTS: (400, "No se pueden asignar tareas a una clase sin alumnos"),
    ErrorCode.AVATAR_INVALID_IMAGE: (422, "El archivo debe ser una imagen PNG, JPEG o WebP válida"),
    ErrorCode.AVATAR_TOO_LARGE: (413, "La imagen no puede superar los 5 MB"),
    ErrorCode.ROLE_CHANGE_DENIED: (403, "No se permite cambiar el rol de un usuario"),
    ErrorCode.STUDENT_TASK_MODIFICATION_DENIED: (403, "El alumno no tiene permiso para modificar sus tareas"),
    ErrorCode.STUDENT_TASK_OUTSIDE_SCHOOL_HOURS: (400, "La tarea del alumno debe quedar fuera del horario escolar"),
    ErrorCode.USER_LOOKUP_FAILED: (500, "No se pudo consultar el usuario"),
    ErrorCode.USER_LIST_FAILED: (500, "No se pudo consultar la lista de usuarios"),
    ErrorCode.PASSWORD_UPDATE_FAILED: (500, "No se pudo actualizar la contraseña"),
    ErrorCode.USER_CREATE_FAILED: (500, "No se pudo crear el usuario"),
    ErrorCode.USER_DELETE_FAILED: (500, "No se pudo eliminar el usuario"),
    ErrorCode.USER_UPDATE_FAILED: (500, "No se pudo editar el usuario"),
    ErrorCode.AVATAR_UPDATE_FAILED: (500, "No se pudo actualizar el avatar"),
    ErrorCode.LOGIN_FAILED: (500, "No se pudo iniciar sesión"),
    ErrorCode.INTERNAL_ERROR: (500, "Error interno del servidor"),
}


def error_response(code: ErrorCode | int) -> dict:
    """Crea el sobre JSON estándar para un error conocido."""
    error_code = ErrorCode(code)
    _, details = ERRORS[error_code]
    return {"errorCode": int(error_code), "details": details}


def success_response(**data) -> dict:
    """Crea una respuesta correcta con el sobre común de la API."""
    return {"errorCode": int(ErrorCode.SUCCESS), "details": "successful", **data}


def error_status(code: ErrorCode | int) -> int:
    """Devuelve el estado HTTP asociado al código de error."""
    return ERRORS[ErrorCode(code)][0]


def raise_api_error(code: ErrorCode | int, headers: dict[str, str] | None = None) -> None:
    """Lanza una excepción HTTP con el estado y mensaje del catálogo."""
    response = error_response(code)
    raise HTTPException(status_code=error_status(code), detail=response, headers=headers)


class CatalogError(Exception):
    """Dominio interno para propagar un error catalogado entre capas."""

    def __init__(self, code: ErrorCode):
        self.code = code
        super().__init__(int(code))


def code_for_http_status(status_code: int) -> ErrorCode:
    """Traduce estados HTTP de FastAPI a códigos públicos del catálogo."""
    if status_code == 401:
        return ErrorCode.INVALID_TOKEN
    if status_code == 403:
        return ErrorCode.ADMIN_REQUIRED
    if status_code == 422:
        return ErrorCode.INVALID_REQUEST
    if status_code >= 500:
        return ErrorCode.INTERNAL_ERROR
    if status_code == 404:
        return ErrorCode.ROUTE_NOT_FOUND
    return ErrorCode.INVALID_REQUEST
