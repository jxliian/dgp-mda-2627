from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, EmailStr, Field, field_validator
from sqlalchemy.orm import Session

from auth.dependencies import get_current_user, require_roles
from auth.schemas import CurrentUser
from DB.database import get_db
from gestion_asociaciones.assoc_mng_db import assoc_mng_db
from gestion_usuarios.users_mng_db import users_mng_db

MemberRole = Literal["parent", "staff"]

router = APIRouter(prefix="/associations", tags=["Asociaciones"])


# --- Datos que entran y salen ---

class AssociationCreate(BaseModel):
    student_email: EmailStr
    member_role: MemberRole                     # "parent" (familia) o "staff" (personal)
    member_emails: list[EmailStr] = Field(min_length=1)

    @field_validator("student_email")
    @classmethod
    def normalize_student(cls, v: str) -> str:
        return v.strip().lower()

    @field_validator("member_emails")
    @classmethod
    def normalize_members(cls, v: list[str]) -> list[str]:
        # minúsculas y sin repetidos, conservando el orden
        return list(dict.fromkeys(e.strip().lower() for e in v))


class AssociationCreated(BaseModel):
    created: list[str]
    already_existing: list[str]


class AssociatedMember(BaseModel):
    email: str
    username: str
    role: MemberRole


class AssociatedStudent(BaseModel):
    email: str
    username: str


# --- Funciones auxiliares ---

def _user_exists(db: Session, email: str, role: str) -> bool:
    result = users_mng_db.getUserByEmail(db, email, role)
    if result.errorCode == 0:
        return True
    if result.errorCode == 1:
        return False
    raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Error interno del servidor")


def ensure_student_access(db: Session, user: CurrentUser, student_email: str) -> None:
    """Acceso derivado de la relación (HU-07): solo pueden actuar sobre un alumno
    el administrador, el propio alumno y el personal o familiares asociados a él.
    Al desasociar (HU-08) el acceso se pierde en ese momento, porque se consulta la BD."""
    if user.role == "admin":
        return
    if user.role == "student" and user.email == student_email:
        return
    if user.role in ("parent", "staff") and assoc_mng_db.isAssociated(db, student_email, user.email, user.role):
        return
    raise HTTPException(status.HTTP_403_FORBIDDEN, "No tienes acceso a este alumno")


# --- Endpoints ---

@router.post("", status_code=status.HTTP_201_CREATED, response_model=AssociationCreated)
def create_associations(
    data: AssociationCreate,
    admin: CurrentUser = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> AssociationCreated:
    """HU-07: asocia un alumno con uno o varios miembros del personal o familiares."""
    if not _user_exists(db, data.student_email, "student"):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "El alumno no existe")

    missing = [e for e in data.member_emails if not _user_exists(db, e, data.member_role)]
    if missing:
        raise HTTPException(status.HTTP_404_NOT_FOUND,
                            f"No existen estas cuentas con el rol indicado: {', '.join(missing)}")

    created, existing = assoc_mng_db.createAssociations(
        db, data.student_email, data.member_emails, data.member_role)
    if not created:
        raise HTTPException(status.HTTP_409_CONFLICT, "La asociación ya existe")
    return AssociationCreated(created=created, already_existing=existing)


@router.delete("/{member_role}/{member_email}/{student_email}", status_code=status.HTTP_204_NO_CONTENT)
def delete_association(
    member_role: MemberRole,
    member_email: str,
    student_email: str,
    admin: CurrentUser = Depends(require_roles("admin")),
    db: Session = Depends(get_db),
) -> Response:
    """HU-08: elimina solo la asociación indicada. No borra cuentas ni otras asociaciones."""
    deleted = assoc_mng_db.deleteAssociation(
        db, student_email.strip().lower(), member_email.strip().lower(), member_role)
    if not deleted:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "La asociación no existe")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/students/{student_email}", response_model=list[AssociatedMember])
def get_student_members(
    student_email: str,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    """Personal y familiares asociados a un alumno (se ve en la información del alumno)."""
    student_email = student_email.strip().lower()
    ensure_student_access(db, user, student_email)
    return assoc_mng_db.getMembersOfStudent(db, student_email)


@router.get("/{member_role}/{member_email}", response_model=list[AssociatedStudent])
def get_member_students(
    member_role: MemberRole,
    member_email: str,
    user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[dict]:
    """Alumnos asociados a un tutor o familiar (se ve en la información de esa persona)."""
    member_email = member_email.strip().lower()
    if user.role != "admin" and not (user.role == member_role and user.email == member_email):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "No tienes acceso a esta información")
    return assoc_mng_db.getStudentsOfMember(db, member_email, member_role)
