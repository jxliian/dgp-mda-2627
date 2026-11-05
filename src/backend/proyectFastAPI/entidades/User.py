from abc import ABC, abstractmethod
from ..gestion_usuarios import users_mng_db

class User(ABC):
    def __init_(self):
        self.email = None
        self.username = None 
        self.token = None

    @abstractmethod
    def searchUserByUsername(self, username):
        pass

    @abstractmethod
    def searchUserByEmail(self, email):
        pass

    @abstractmethod
    def login(self, username, passwd):
        pass

    @abstractmethod
    def logout(self, username):
        pass

    @abstractmethod
    def updatePassword(self, newPassword):
        pass


class Student (User):
    def __init_(self):
        return super().__init_()

    def searchUserByUsername(self, username):
        jsonDB = db.getUserByUsername(username, "student")

        if jsonDB.errorCode == 0:
            self.username = jsonDB.username
        
        return {jsonDB.errorCode, jsonDB.ErrorMsg}

    def searchUserByEmail(self, email):
        jsonDB = db.getUserByEmail(email, "student")

        if jsonDB.errorCode == 0:
            self.email = jsonDB.email
        
        return {jsonDB.errorCode, jsonDB.ErrorMsg}

    def login(self, username, passwd):
        jsonDB = db.login(username, passwd, "student")

        if jsonDB.errorCode == 0:
            self.username = jsonDB.username
            self.token = jsonDB.token
        
        return {jsonDB.errorCode, jsonDB.errorMsg}

    def logout(self):
        jsonDB = db.logout(self.username, "student")

        if jsonDB.errorCode == 0:
            self.token = None
            self.username = None
        
        return {jsonDB.errorCode, jsonDB.errorMsg}

    def updateAvatar(self, avatarID):
        return db.updateAvatar(self.username, avatarID)

    def updatePassword(self, newPassword, oldPassword):
        if(oldPassword.hash == db.getPassword(self.username, "student")):
            return db.updatePassword(self.username, newPassword, "student")
        else:
            return {"errorCode": "", "errorMsg": ""}

class Admin (User):
    def __init_(self):
        return super().__init_()

    def searchUserByUsername(self, username):
        jsonDB = db.getUserByUsername(username, "admin")

        if jsonDB.errorCode == 0:
            self.username = jsonDB.username
            
        return {jsonDB.errorCode, jsonDB.errorMs}

    def searchUserByEmail(self, email):
        jsonDB = db.getUserByEmail(email, "admin")

        if jsonDB.errorCode == 0:
            self.email = jsonDB.email
        
        return {jsonDB.errorCode, jsonDB.ErrorMsg}

    def login(self, username, passwd):
        jsonDB = db.login(username, passwd, "admin")

        if jsonDB.errorCode == 0:
            self.username = jsonDB.username
            self.token = jsonDB.token
        
        return {jsonDB.errorCode, jsonDB.errorMsg}

    def logout(self):
        jsonDB = db.logout(self.username, "admin")

        if jsonDB.errorCode == 0:
            self.username = None
            self.token = None

        return {jsonDB.errorCode, jsonDB.errorMsg} 

    def createUser(self, username, passwd, role):
        return db.createUser(username, passwd, role) 

    def deleteUser(self, username, role):
        return db.deleteUser(username, role)

    def updateUser(self, username, passwd, role):
        return db.updateUser(username, passwd, role)

    def updatePassword(self, newPassword, oldPassword):
        if(oldPassword.hash == db.getPassword(self.username, "admin")):
            return db.updatePassword(self.username, newPassword, "admin")
        else:
            return {"errorCode": "", "errorMsg": ""}

class Staff (User):
    def __init_(self):
        return super().__init_()

    def searchUserByUsername(self, username):
        jsonDB = db.getUserByUsername(username, "staff")

        if jsonDB.errorCode == 0:
            self.username = jsonDB.username
        
        return {jsonDB.errorCode, jsonDB.errorMsg}

    def searchUserByEmail(self, email):
        jsonDB = db.getUserByEmail(email, "staff")

        if jsonDB.errorCode == 0:
            self.email = jsonDB.email
        
        return {jsonDB.errorCode, jsonDB.ErrorMsg}

    def login(self, username, passwd):
        jsonDB = db.login(username, passwd, "staff")

        if jsonDB.errorCode == 0:
            self.username = jsonDB.username
            self.token = jsonDB.token
        
        return {jsonDB.errorCode, jsonDB.errorMsg}

    def logout(self):
        jsonDB = db.logout(self.username, "staff")
        if jsonDB.errorCode == 0:
            self.token = None
            self.username = None
        
        return {jsonDB.errorCode, jsonDB.errorMsg}
    
    def updatePassword(self, newPassword, oldPassword):
        if(oldPassword.hash == db.getPassword(self.username, "staff")):
            return db.updatePassword(self.username, newPassword, "staff")
        else:
            return {"errorCode": "", "errorMsg": "La contraseña no coincide con la actual."
            " Vuelve a intentarlo"}

class Parent (User):
    def __init_(self):
        return super().__init_()
    
    def searchUser(self, username):
        jsonDB = db.getUserByUsername(username, "parent")

        if jsonDB.errorCode == 0:
            self.username = jsonDB.username

        return {jsonDB.errorCode, jsonDB.errorMsg}

    def searchUserByEmail(self, email):
        jsonDB = db.getUserByEmail(email, "admin")

        if jsonDB.errorCode == 0:
            self.email = jsonDB.email
        
        return {jsonDB.errorCode, jsonDB.ErrorMsg}

    def login(self, username, passwd):
        jsonDB = db.login(username, passwd, "parent")

        if jsonDB.errorCode == 0:
            self.username = jsonDB.username
            self.token = jsonDB.token

        return {jsonDB.errorCode, jsonDB.errorMsg}

    def logout(self):
        jsonDB = db.logout(self.username, "parent")

        if jsonDB.errorcode == 0:
            self.token = None
            self.username = None
    
        return {jsonDB.errorCode, jsonDB.errorMsg}

    def updatePassword(self, newPassword, oldPassword):
        if(oldPassword.hash == db.getPassword(self.username, "parent")):
            return db.updatePassword(self.username, newPassword, "parent")
        else:
            return {"errorCode": "", "errorMsg": "La contraseña no coincide con la actual."
            " Vuelve a intentarlo"}