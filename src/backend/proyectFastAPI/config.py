from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuración leída de variables de entorno o del fichero .env (nunca se sube a Git)."""

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    jwt_secret_key: str                 # obligatoria: si falta, la API no arranca
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 480       # 8 horas: una jornada sin volver a iniciar sesión


settings = Settings()