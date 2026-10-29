# INSTALACIÓN DE HERRAMIENTAS

Para desarrollar el proyecto necesitaremos instalar las siguientes herramientas:

- **Flutter y Android Studio:** desarrollo de la aplicación móvil.
- **FastAPI (Python):** desarrollo del backend y de la API.
- **PostgreSQL:** sistema de gestión de bases de datos.
- **Docker:** ejecución de PostgreSQL en un contenedor.

---

# PASOS PARA DESPLEGAR LA BASE DE DATOS EN TU PC

### 1. Descargar e instalar `uv`

Ejecutamos el siguiente comando en la terminal para descargar e instalar `uv`, el gestor de paquetes y proyectos de Python:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 2. Reiniciar la terminal

Cerramos y volvemos a abrir la terminal para que los cambios surtan efecto y el sistema reconozca el comando `uv`.

### 3. Iniciar la base de datos

Nos situamos en la carpeta del proyecto FastAPI, donde se encuentra el archivo `docker-compose.yml`, y ejecutamos:

```bash
sudo docker compose up -d
```

Este comando inicia los servicios definidos en Docker Compose en segundo plano.

### 4. Iniciar FastAPI

Para iniciar el servidor de desarrollo de FastAPI, ejecutamos:

```bash
uv run fastapi dev main.py
```

---

# &#x20;PASOS SEGUIDOS POR YERAY PARA DESARROLLAR LA BASE DE DATOS POR PRIMERA VEZ

## 1. FastAPI

### 1.1. Instalar `uv`

Copiamos y pegamos el siguiente comando en la terminal para descargar e instalar `uv`:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 1.2. Crear el proyecto e instalar FastAPI

Creamos el proyecto con `uv` y accedemos a su directorio:

```bash
uv init mda-dgp-26/27 --bare
cd mda-dgp-26/27
```

A continuación, añadimos FastAPI con sus dependencias estándar:

```bash
uv add "fastapi[standard]"
```

### 1.3. Instalar las dependencias necesarias

Instalamos las dependencias para trabajar con PostgreSQL, gestionar los modelos de datos y realizar migraciones de la base de datos:

```bash
uv add "fastapi[standard]" sqlalchemy psycopg2-binary alembic pydantic-settings
```

Añadimos las dependencias necesarias para la seguridad y la autenticación:

```bash
uv add "passlib[bcrypt]" pyjwt
```

- **Passlib:** permite gestionar el hashing de contraseñas.
- **PyJWT:** permite trabajar con JSON Web Tokens (JWT) para la autenticación.

Por último, añadimos el controlador moderno de PostgreSQL para Python:

```bash
uv add "psycopg[binary]"
```

> **Nota:** esta última dependencia se añade porque puede ser necesaria para utilizar la versión moderna del controlador de PostgreSQL (`psycopg`), especialmente si el proyecto utiliza SQLAlchemy con este controlador.

---

## 2. PostgreSQL

### 2.1. Seleccionar la versión de PostgreSQL

Vamos a utilizar **PostgreSQL 18**, una versión estable que ofrece las funcionalidades necesarias para el proyecto.

Además, utilizaremos la variante **Alpine**, que ocupa menos espacio que otras imágenes de Docker y permite reducir el tamaño del contenedor.

La imagen elegida es:

```text
postgres:18-alpine
```

### 2.2. Crear el archivo `docker-compose.yml`

En el directorio raíz del proyecto, creamos un archivo llamado `docker-compose.yml` con el siguiente contenido:

```yaml
services:
  db:
    image: postgres:18-alpine
    container_name: autovida_postgres
    restart: always
    environment:
      POSTGRES_USER: autovida_admin
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: autovida_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql

volumes:
  postgres_data:
```

**Descripción de la configuración:**

| Parámetro           | Descripción                                                        |
| ------------------- | ------------------------------------------------------------------ |
| `image`             | Imagen de PostgreSQL 18 basada en Alpine.                          |
| `container_name`    | Nombre del contenedor: `autovida_postgres`.                        |
| `restart`           | Reinicia automáticamente el contenedor cuando corresponde.         |
| `POSTGRES_USER`     | Usuario de la base de datos.                                       |
| `POSTGRES_PASSWORD` | Contraseña del usuario, obtenida de una variable de entorno.       |
| `POSTGRES_DB`       | Nombre de la base de datos que se creará inicialmente.             |
| `ports`             | Expone el puerto 5432 del contenedor en el puerto 5432 del equipo. |
| `volumes`           | Permite conservar los datos de PostgreSQL.                         |

**Importante:** antes de iniciar el contenedor, configura la variable `POSTGRES_PASSWORD` en un archivo `.env` situado en el mismo directorio:

```dotenv
POSTGRES_PASSWORD=tu_contraseña_segura
```

Sustituye `tu_contraseña_segura` por una contraseña propia y no compartas el archivo `.env`.

> **Nota sobre el almacenamiento:** en PostgreSQL 18, la ruta de datos recomendada para la imagen oficial es `/var/lib/postgresql`. Por eso se utiliza esta ruta como punto de montaje del volumen.

### 2.3. Iniciar PostgreSQL

Desde el directorio que contiene `docker-compose.yml`, ejecutamos:

```bash
docker compose up -d
```

Si tu sistema necesita permisos de administrador para ejecutar Docker, puedes utilizar:

```bash
sudo docker compose up -d
```

Este comando crea e inicia el contenedor de PostgreSQL en segundo plano.

Para comprobar que el contenedor está funcionando, ejecutamos:

```bash
docker ps
```

Debería aparecer el contenedor `autovida_postgres` en la lista.

---

## 3. Conectar FastAPI con PostgreSQL

Una vez iniciada la base de datos, vamos a comprobar que FastAPI puede comunicarse correctamente con PostgreSQL.

### 3.1. Crear el archivo `main.py`

En el directorio raíz del proyecto, creamos el archivo `main.py` con el siguiente código:

```python
import os

from fastapi import FastAPI, Depends
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session

# Configuración de la conexión a PostgreSQL
DATABASE_URL = (
    f"postgresql+psycopg://autovida_admin:"
    f"{os.environ['POSTGRES_PASSWORD']}"
    f"@localhost:5432/autovida_db"
)

engine = create_engine(DATABASE_URL)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

app = FastAPI(title="AUTOVIDA API")


# Dependencia para gestionar las sesiones de la base de datos
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# Endpoint para comprobar la conexión con PostgreSQL
@app.get("/")
def comprobar_conexion(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))

    return {
        "estado": "ok",
        "mensaje": "¡FastAPI conectado con éxito a PostgreSQL!",
    }
```

**¿Qué hace este código?**

- Crea la conexión entre FastAPI y PostgreSQL mediante SQLAlchemy.
- Configura las sesiones que se utilizarán para interactuar con la base de datos.
- Define el endpoint `/`, que ejecuta una consulta sencilla para comprobar la conexión.
- Devuelve un mensaje de confirmación si la consulta se ejecuta correctamente.

**Importante:** el ejemplo utiliza el controlador `psycopg` y obtiene la contraseña de una variable de entorno. Antes de ejecutar el servidor, asegúrate de que `POSTGRES_PASSWORD` esté definida en el entorno de Python.

### 3.2. Iniciar FastAPI

Desde el directorio raíz del proyecto, ejecutamos:

```bash
uv run fastapi dev main.py
```

Si todo funciona correctamente, FastAPI iniciará el servidor de desarrollo.

Por defecto, estará disponible en:

```text
http://127.0.0.1:8000
```

### 3.3. Comprobar la conexión

Abrimos la siguiente dirección en el navegador:

```text
http://127.0.0.1:8000/
```

Si la conexión con PostgreSQL funciona, obtendremos una respuesta similar a esta:

```json
{
  "estado": "ok",
  "mensaje": "¡FastAPI conectado con éxito a PostgreSQL!"
}
```

También podemos acceder a la documentación interactiva de la API en:

```text
http://127.0.0.1:8000/docs
```

---

# ✅ RESUMEN DE COMANDOS

Estos son los comandos principales que utilizaremos durante la configuración inicial y el desarrollo del proyecto.

| Acción                          | Comando                                                       |
| ------------------------------- | ------------------------------------------------------------- |
| Instalar `uv`                   | `curl -LsSf https://astral.sh/uv/install.sh \| sh`            |
| Crear el proyecto               | `uv init mda-dgp-26/27 --bare`                                |
| Acceder al proyecto             | `cd mda-dgp-26/27`                                            |
| Instalar FastAPI                | `uv add "fastapi[standard]"`                                  |
| Instalar dependencias           | `uv add sqlalchemy psycopg2-binary alembic pydantic-settings` |
| Instalar autenticación          | `uv add "passlib[bcrypt]" pyjwt`                              |
| Instalar el controlador moderno | `uv add "psycopg[binary]"`                                    |
| Iniciar PostgreSQL              | `docker compose up -d`                                        |
| Comprobar los contenedores      | `docker ps`                                                   |
| Iniciar FastAPI                 | `uv run fastapi dev main.py`                                  |

---

## 🎯 Resultado esperado

Al finalizar estos pasos, tendremos:

- ✅ El entorno Python configurado con `uv`.
- ✅ FastAPI instalado y funcionando.
- ✅ PostgreSQL 18 ejecutándose en Docker.
- ✅ Una base de datos llamada `autovida_db`.
- ✅ Una conexión entre FastAPI y PostgreSQL.
- ✅ Un endpoint para comprobar que la conexión funciona.
- ✅ La documentación interactiva de la API disponible en `/docs`.
