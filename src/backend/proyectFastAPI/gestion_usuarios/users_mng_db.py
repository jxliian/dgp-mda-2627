from typing import Optional, Any
from sqlalchemy.orm import Session
from sqlalchemy import text
from passlib.context import CryptContext

# Configuración del contexto para hashing de contraseñas con Bcrypt
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Mapeo de roles a tablas de PostgreSQL y sus columnas de usuario, email y contraseña
ROLE_TABLE_MAP = {
    "admin": "admn",
    "staff": "staff",
    "student": "student",
    "parent": "parents"
}

ROLE_COLUMNS = {
    "admin": ("admn_usr", "admn_email", "admn_passwd"),
    "staff": ("staff_usr", "staff_email", "staff_passwd"),
    "student": ("stud_usr", "stud_email", "stud_password"),
    "parent": ("par_usr", "par_email", "par_passwd")
}


class DBResponse(dict):
    """
    Clase auxiliar que permite acceder a las llaves del diccionario
    como atributos de un objeto (ej. response.errorCode o response['errorCode']).
    """
    def __getattr__(self, name: str) -> Any:
        try:
            return self[name]
        except KeyError:
            raise AttributeError(f"'DBResponse' object has no attribute '{name}'")

    def __setattr__(self, name: str, value: Any) -> None:
        self[name] = value


class UsersManagementDB:
    """
    Capa de Acceso a Datos (DAO / Repository) para la gestión de usuarios en PostgreSQL.
    """

    def _get_table_and_cols(self, role: str):
        role_lower = role.lower()
        if role_lower not in ROLE_TABLE_MAP:
            raise ValueError(f"Rol no válido: '{role}'. Roles permitidos: {list(ROLE_TABLE_MAP.keys())}")
        table = ROLE_TABLE_MAP[role_lower]
        usr_col, email_col, pwd_col = ROLE_COLUMNS[role_lower]
        return table, usr_col, email_col, pwd_col

    #Función para obtener un usuario dado su nombre de usuario
    def getUserByUsername(self, db: Session, username: str, role: str) -> DBResponse:
        try:
            table, usr_col, email_col, _ = self._get_table_and_cols(role)
            query = text(f"SELECT {usr_col}, {email_col} FROM {table} WHERE {usr_col} = :usr")
            result = db.execute(query, {"usr": username}).fetchone()

            if result:
                return DBResponse({
                    "errorCode": 0,
                    "errorMsg": "OK",
                    "username": result[0],
                    "email": result[1]
                })
            return DBResponse({"errorCode": 1, "errorMsg": "Usuario no encontrado"})
        except Exception as e:
            return DBResponse({"errorCode": 500, "errorMsg": f"Error de base de datos: {str(e)}"})

    #Función para obtener un usuario dada su dirección de correo electrónico
    def getUserByEmail(self, db: Session, email: str, role: str) -> DBResponse:
        try:
            table, usr_col, email_col, _ = self._get_table_and_cols(role)
            query = text(f"SELECT {usr_col}, {email_col} FROM {table} WHERE {email_col} = :email")
            result = db.execute(query, {"email": email}).fetchone()

            if result:
                return DBResponse({
                    "errorCode": 0,
                    "errorMsg": "OK",
                    "username": result[0],
                    "email": result[1]
                })
            return DBResponse({"errorCode": 1, "errorMsg": "Usuario no encontrado por email"})
        except Exception as e:
            return DBResponse({"errorCode": 500, "errorMsg": f"Error de base de datos: {str(e)}"})

    # Función para obtener el hash de la contraseña de un usuario
    def getPassword(self, db: Session, username: str, role: str) -> Optional[str]:
        try:
            table, usr_col, _, pwd_col = self._get_table_and_cols(role)
            query = text(f"SELECT {pwd_col} FROM {table} WHERE {usr_col} = :usr")
            result = db.execute(query, {"usr": username}).fetchone()
            return result[0] if result else None
        except Exception:
            return None

    # Función para obtener el hash de la contraseña de un usuario dado su email
    def getPasswordByEmail(self, db: Session, email: str, role: str) -> Optional[str]:
        table, _, email_col, pwd_col = self._get_table_and_cols(role)
        query = text(f"SELECT {pwd_col} FROM {table} WHERE {email_col} = :email")
        result = db.execute(query, {"email": email}).fetchone()
        return result[0] if result else None


    #Función que comprueba las credenciales del usuario y entrega el token si son correctos
    def login(self, db: Session, username: str, passwd_plain: str, role: str) -> DBResponse:
        stored_hash = self.getPassword(db, username, role)

        if not stored_hash:
            return DBResponse({"errorCode": 1, "errorMsg": "Usuario o contraseña incorrectos"})

        if pwd_context.verify(passwd_plain, stored_hash):
            return DBResponse({
                "errorCode": 0,
                "errorMsg": "OK",
                "username": username,
                "token": f"session_token_for_{username}"
            })

        return DBResponse({"errorCode": 1, "errorMsg": "Usuario o contraseña incorrectos"})

    # Función para cerrar sesión
    def logout(self, db: Session, username: str, role: str) -> DBResponse:
        return DBResponse({"errorCode": 0, "errorMsg": "OK"})

    def updatePassword(self, db: Session, username: str, new_password_plain: str, role: str) -> DBResponse:
        """Actualiza la contraseña de un usuario."""
        try:
            table, usr_col, _, pwd_col = self._get_table_and_cols(role)
            new_hash = pwd_context.hash(new_password_plain)

            query = text(f"UPDATE {table} SET {pwd_col} = :pwd WHERE {usr_col} = :usr")
            result = db.execute(query, {"pwd": new_hash, "usr": username})

            if result.rowcount == 0:
                db.rollback()
                return DBResponse({"errorCode": 1, "errorMsg": "No se encontró el usuario para actualizar"})

            db.commit()
            return DBResponse({"errorCode": 0, "errorMsg": "Contraseña actualizada correctamente"})
        except Exception as e:
            db.rollback()
            return DBResponse({"errorCode": 500, "errorMsg": f"Error al actualizar la contraseña: {str(e)}"})

    def createUser(self, db: Session, username: str, passwd_plain: str, role: str, email: Optional[str] = None) -> DBResponse:
        """Inserta un nuevo usuario en la base de datos."""
        try:
            table, usr_col, email_col, pwd_col = self._get_table_and_cols(role)
            hashed_pwd = pwd_context.hash(passwd_plain)

            query = text(f"INSERT INTO {table} ({usr_col}, {email_col}, {pwd_col}) VALUES (:usr, :email, :pwd)")
            db.execute(query, {"usr": username, "email": email, "pwd": hashed_pwd})
            db.commit()

            return DBResponse({"errorCode": 0, "errorMsg": "Usuario creado con éxito"})
        except Exception as e:
            db.rollback()
            return DBResponse({"errorCode": 500, "errorMsg": f"Error al crear el usuario: {str(e)}"})

    def deleteUser(self, db: Session, username: str, role: str) -> DBResponse:
        """Elimina un usuario por su nombre."""
        try:
            table, usr_col, _, _ = self._get_table_and_cols(role)
            query = text(f"DELETE FROM {table} WHERE {usr_col} = :usr")
            result = db.execute(query, {"usr": username})

            if result.rowcount == 0:
                db.rollback()
                return DBResponse({"errorCode": 1, "errorMsg": "El usuario a eliminar no existe"})

            db.commit()
            return DBResponse({"errorCode": 0, "errorMsg": "Usuario eliminado correctamente"})
        except Exception as e:
            db.rollback()
            return DBResponse({"errorCode": 500, "errorMsg": f"Error al eliminar el usuario: {str(e)}"})

    # Función para eliminar un usuario dado su email. Devuelve False si no existía.
    # Sus asociaciones (par_stud, staff_stud...) las borra la BD en cascada.
    def deleteUserByEmail(self, db: Session, email: str, role: str) -> bool:
        table, _, email_col, _ = self._get_table_and_cols(role)
        query = text(f"DELETE FROM {table} WHERE {email_col} = :email")
        try:
            result = db.execute(query, {"email": email})
            db.commit()
        except Exception:
            db.rollback()
            raise
        return result.rowcount > 0

    def updateUser(self, db: Session, username: str, passwd_plain: str, role: str) -> DBResponse:
        """Actualiza la información del usuario."""
        return self.updatePassword(db, username, passwd_plain, role)

    def updateAvatar(self, db: Session, username: str, avatar_id: int) -> DBResponse:
        """Actualiza la clave foránea del avatar para un estudiante."""
        try:
            query = text("UPDATE Student SET avatar_id_fk = :avatar_id WHERE stud_usr = :usr")
            result = db.execute(query, {"avatar_id": avatar_id, "usr": username})

            if result.rowcount == 0:
                db.rollback()
                return DBResponse({"errorCode": 1, "errorMsg": "Estudiante no encontrado"})

            db.commit()
            return DBResponse({"errorCode": 0, "errorMsg": "Avatar actualizado correctamente"})
        except Exception as e:
            db.rollback()
            return DBResponse({"errorCode": 500, "errorMsg": f"Error al actualizar el avatar: {str(e)}"})


# Instancia única del repositorio
users_mng_db = UsersManagementDB()