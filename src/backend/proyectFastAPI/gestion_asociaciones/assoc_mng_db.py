from sqlalchemy import text
from sqlalchemy.orm import Session

# Rol del tutor/familiar -> (tabla intermedia, columna con su email)
ASSOC_TABLE_MAP = {
    "parent": ("par_stud", "par_email_fk"),
    "staff": ("staff_stud", "staff_email_fk"),
}

# Rol del tutor/familiar -> (tabla de cuentas, columna del email, columna del usuario)
MEMBER_TABLE_MAP = {
    "parent": ("parents", "par_email", "par_usr"),
    "staff": ("staff", "staff_email", "staff_usr"),
}


class AssociationsManagementDB:
    """Acceso a datos de las asociaciones alumno - personal / familia (HU-07, HU-08)."""

    def _get_assoc_table(self, member_role: str):
        if member_role not in ASSOC_TABLE_MAP:
            raise ValueError(f"Rol no válido para asociaciones: '{member_role}'")
        return ASSOC_TABLE_MAP[member_role]

    # Indica si un tutor/familiar está asociado a un alumno
    def isAssociated(self, db: Session, student_email: str, member_email: str, member_role: str) -> bool:
        table, member_col = self._get_assoc_table(member_role)
        query = text(f"SELECT 1 FROM {table} WHERE stud_email_fk = :stud AND {member_col} = :member")
        return db.execute(query, {"stud": student_email, "member": member_email}).first() is not None

    # Crea varias asociaciones de un alumno a la vez (todas o ninguna).
    # Devuelve (emails asociados ahora, emails que ya estaban asociados).
    def createAssociations(self, db: Session, student_email: str, member_emails: list[str],
                           member_role: str) -> tuple[list[str], list[str]]:
        table, member_col = self._get_assoc_table(member_role)
        query = text(
            f"INSERT INTO {table} ({member_col}, stud_email_fk) VALUES (:member, :stud) "
            f"ON CONFLICT DO NOTHING RETURNING stud_email_fk"
        )
        created, existing = [], []
        try:
            for member_email in member_emails:
                inserted = db.execute(query, {"member": member_email, "stud": student_email}).first()
                (created if inserted else existing).append(member_email)
            db.commit()
        except Exception:
            db.rollback()
            raise
        return created, existing

    # Elimina solo la asociación indicada. Devuelve False si no existía.
    def deleteAssociation(self, db: Session, student_email: str, member_email: str, member_role: str) -> bool:
        table, member_col = self._get_assoc_table(member_role)
        query = text(f"DELETE FROM {table} WHERE stud_email_fk = :stud AND {member_col} = :member")
        try:
            result = db.execute(query, {"stud": student_email, "member": member_email})
            db.commit()
        except Exception:
            db.rollback()
            raise
        return result.rowcount > 0

    # Personal y familiares asociados a un alumno
    def getMembersOfStudent(self, db: Session, student_email: str) -> list[dict]:
        members = []
        for role, (table, member_col) in ASSOC_TABLE_MAP.items():
            acc_table, email_col, usr_col = MEMBER_TABLE_MAP[role]
            query = text(
                f"SELECT a.{email_col}, a.{usr_col} FROM {table} r "
                f"JOIN {acc_table} a ON a.{email_col} = r.{member_col} "
                f"WHERE r.stud_email_fk = :stud ORDER BY a.{usr_col}"
            )
            for email, username in db.execute(query, {"stud": student_email}):
                members.append({"email": email, "username": username, "role": role})
        return members

    # Alumnos asociados a un tutor/familiar
    def getStudentsOfMember(self, db: Session, member_email: str, member_role: str) -> list[dict]:
        table, member_col = self._get_assoc_table(member_role)
        query = text(
            f"SELECT s.stud_email, s.stud_usr FROM {table} r "
            f"JOIN student s ON s.stud_email = r.stud_email_fk "
            f"WHERE r.{member_col} = :member ORDER BY s.stud_usr"
        )
        return [{"email": email, "username": username}
                for email, username in db.execute(query, {"member": member_email})]


# Instancia única del repositorio
assoc_mng_db = AssociationsManagementDB()
