from abc import ABC
from typing import Optional

from ..gestion_usuarios.users_mng_db import users_mng_db


class User(ABC):
    """Entidad de usuario. Las operaciones devuelven diccionarios serializables a JSON."""

    role = ""

    def __init__(self, username: Optional[str] = None, full_name: Optional[str] = None, email: Optional[str] = None):
        """Inicializa los datos básicos y el rol de una entidad de usuario."""
        self.username = username
        self.full_name = full_name
        self.email = email

    def searchUserByUsername(self, db, username: str) -> dict:
        """Busca el usuario por nombre de usuario y actualiza esta entidad si existe."""
        result = users_mng_db.getUserByUsername(db, username, self.role)
        if result["errorCode"] == 0:
            self.username = result.get("username")
            self.full_name = result.get("full_name")
            self.email = result.get("email")
        return result

    def searchUserByEmail(self, db, email: str) -> dict:
        """Busca por correo y actualiza los datos de esta entidad si existe."""
        result = users_mng_db.getUserByEmail(db, email, self.role)
        if result["errorCode"] == 0:
            self.username = result.get("username")
            self.full_name = result.get("full_name")
            self.email = result.get("email")
        return result

    def updatePassword(self, db, new_password: str) -> dict:
        """Cambia la contraseña del usuario y revoca su sesión activa."""
        return users_mng_db.updatePassword(db, self.username, new_password, self.role)


class Student(User):
    role = "student"

    def updateAvatar(self, db, avatar_id: int) -> dict:
        """Asigna al estudiante el avatar indicado."""
        return users_mng_db.updateAvatar(db, self.username, avatar_id)


class Admin(User):
    role = "admin"

    def createUser(self, db, username: str, passwd: str, role: str, full_name: str, email: Optional[str] = None) -> dict:
        """Crea una cuenta con el rol y los datos proporcionados."""
        return users_mng_db.createUser(db, username, passwd, role, full_name, email)

    def deleteUser(self, db, username: str, role: str) -> dict:
        """Elimina la cuenta indicada, respetando la regla del último administrador."""
        return users_mng_db.deleteUser(db, username, role)


class Staff(User):
    role = "staff"


class Parent(User):
    role = "parent"
