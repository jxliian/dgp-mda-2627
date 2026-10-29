-----A INSTALAR-----
Flutter y Android Studio
FastAPI Python
PostgreSQL

----FastAPI----
1. Copiar y pegar este comando: curl -LsSf https://astral.sh/uv/install.sh | sh ---> descarga e instala uv
2. Creamos proyecto con uv y añadimos FastAPI:
	``` uv init mda-dgp-26/27 --bare ```
	``` cd mda-dgp-26/27 ```
	``` uv add "fastapi[standard]" ```
3. Añadimos dependencias para postgreSQL y utilidades estándar:
	``` uv add "fastapi[standard]" sqlalchemy psycopg2-binary alembic pydantic-settings ```
	``` uv add "passlib[bcrypt]" pyjwt --> hashing de contraseñas para seguridad ```
	``` uv add "psycopg[binary]" (da error si no lo añadimos, version nueva) ```
	
----PostgreSQL----
Vamos a utilizar la versión 18 de postgres ya que es la lanzada hace un año y ya está terminada. Existe la 19 pero
sigue en desarrollo y puede tener fallos. Además es la versión alpine, que es mucho más ligera.

1. Creamos archivo docker-compose.yml en el directorio del proyecto: 
```
	services:
	  db:
	    image: postgres:18-alpine
	    container_name: autovida_postgres
	    restart: always
	    environment:
	      POSTGRES_USER: autovida_admin
	      POSTGRES_PASSWORD: Clench1234
	      POSTGRES_DB: autovida_db
	    ports:
	      - "5432:5432"
	    volumes:
	      - postgres_data:/var/lib/postgresql

	volumes:
	  postgres_data:
```
	  
2. ``` docker compose up -d ```

Ahora comprobamos que Postgresql se comunica con fastAPI, creamos el archivo main.py:
```
	from fastapi import FastAPI, Depends
	from sqlalchemy import create_engine, text
	from sqlalchemy.orm import sessionmaker, Session

	# Usamos las credenciales del docker-compose
	DATABASE_URL = "postgresql://autovida_admin:Clench1234@localhost:5432/autovida_db"

	engine = create_engine(DATABASE_URL)
	SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

	app = FastAPI(title="AUTOVIDA API")

	def get_db():
	    db = SessionLocal()
	    try:
		yield db
	    finally:
		db.close()

	@app.get("/")
	def comprobar_conexion(db: Session = Depends(get_db)):
	    db.execute(text("SELECT 1"))
	    return {"estado": "ok", "mensaje": "¡FastAPI conectado con éxito a PostgreSQL!"}
```
	    
3. Para iniciar el framework de FastAPI utilizamos el comando ``` uv run fastapi dev main.py ```
