from typing import Literal

from pydantic import BaseModel, EmailStr, Field, field_validator

Role = Literal["admin", "staff", "parent", "student"]


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=72)
    role: Role                          # el botón de rol que pulsa el usuario en la pantalla inicial

    @field_validator("email")
    @classmethod
    def normalize_email(cls, v: str) -> str:
        return v.strip().lower()


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: Role                          # el frontend lo usa para enrutar a la pantalla del rol


class CurrentUser(BaseModel):
    email: str
    username: str
    role: Role