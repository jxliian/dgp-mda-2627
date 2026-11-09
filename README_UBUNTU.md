# Lanzar AUTOVIDA en Ubuntu desde cero

Esta guía arranca la aplicación completa en tu ordenador: PostgreSQL guarda los datos, el backend FastAPI los gestiona y el frontend Flutter muestra las pantallas en el navegador. Los cambios realizados en la aplicación quedan guardados en la base de datos.

Está dirigida a Ubuntu Desktop 22.04, 24.04 o 26.04 de 64 bits, con conexión a Internet y una cuenta con permisos `sudo`. Utilizaremos Docker para PostgreSQL 18, `uv` para Python y Flutter 3.47.9, la versión con la que se ha comprobado el frontend. Necesitarás varios GB libres para las herramientas y sus descargas.

Abre una terminal con **Ctrl + Alt + T**. Copia los bloques en orden, sin añadir `$` al principio. Cuando `sudo` pida contraseña, escribe la de tu sesión de Ubuntu y pulsa Intro; es normal que no aparezcan caracteres. Si un comando falla, resuelve ese error antes de continuar.

La instalación inicial se hace una vez. Después, usa directamente [Volver a arrancar otro día](#8-volver-a-arrancar-otro-día).

## 1. Instalar las herramientas

### Paquetes básicos

```bash
sudo apt update
sudo apt install -y ca-certificates curl git unzip xz-utils zip libglu1-mesa python3
```

### Docker y Docker Compose

Si ya tienes Docker y `sudo docker compose version` funciona, pasa a la instalación de `uv`. Para una instalación nueva, añade el repositorio oficial de Docker:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker run --rm hello-world
sudo docker compose version
```

`hello-world` debe mostrar un mensaje de instalación correcta. Esta guía usa `sudo` para Docker, por lo que no necesitas configurar grupos ni cerrar tu sesión. Si ya tenías otra distribución de Docker y aparecen conflictos de paquetes, consulta la [instalación oficial de Docker en Ubuntu](https://docs.docker.com/engine/install/ubuntu/) antes de cambiar esa instalación.

### Python mediante uv

`uv` descarga Python y crea el entorno de dependencias del backend automáticamente:

```bash
curl -LsSf https://astral.sh/uv/install.sh -o /tmp/autovida-install-uv.sh
sh /tmp/autovida-install-uv.sh
export PATH="$HOME/.local/bin:$PATH"
uv --version
uv python install 3.12
```

No necesitas instalar paquetes Python con `sudo pip` ni activar un entorno virtual manualmente. El instalador y la descarga de Python están descritos en la [documentación oficial de uv](https://docs.astral.sh/uv/).

### Flutter y Dart

Dart viene incluido en Flutter. Si ya tienes Flutter 3.47.9 instalado, comprueba `flutter --version` y omite la descarga. Para una instalación nueva:

```bash
mkdir -p "$HOME/develop"
git clone --branch 3.47.9 --depth 1 https://github.com/flutter/flutter.git "$HOME/develop/flutter"
echo 'export PATH="$HOME/.local/bin:$HOME/develop/flutter/bin:$PATH"' >> "$HOME/.bashrc"
export PATH="$HOME/.local/bin:$HOME/develop/flutter/bin:$PATH"
flutter --version
flutter config --enable-web
flutter precache --web
flutter doctor
```

La primera ejecución puede tardar varios minutos. Si `flutter doctor` avisa de que falta Android Studio o herramientas para aplicaciones Linux, puedes continuar: esta guía ejecuta la versión web. La configuración del SDK se explica en la [instalación oficial de Flutter](https://docs.flutter.dev/install/manual).

Usaremos el navegador que ya tengas, por ejemplo Firefox. El modo `web-server` permite abrir la dirección manualmente, como indica la [guía oficial de Flutter para web](https://docs.flutter.dev/platform-integration/web/setup).

## 2. Descargar el proyecto

Para una copia nueva, ejecuta:

```bash
mkdir -p "$HOME/proyectos"
git clone --branch frontend/autovida-flutter https://github.com/jxliian/dgp-mda-2627.git "$HOME/proyectos/dgp-mda-2627"
cd "$HOME/proyectos/dgp-mda-2627"
git branch --show-current
```

Debe aparecer `frontend/autovida-flutter`, la rama que contiene el frontend. Si GitHub solicita acceso y el repositorio es privado, necesitas que el equipo te conceda acceso.

Si ya tienes el proyecto descargado, utiliza esa carpeta y la rama `frontend/autovida-flutter`, sin volver a clonarlo encima. Los siguientes comandos usan la ruta `~/proyectos/dgp-mda-2627`; sustitúyela por la de tu copia cuando corresponda.

## 3. Preparar el backend y su configuración

```bash
cd "$HOME/proyectos/dgp-mda-2627/src/backend/proyectFastAPI"
uv sync --locked --python 3.12
```

Esto instala las dependencias que ya están definidas en `pyproject.toml` y `uv.lock`.

El siguiente bloque crea `.env`, el archivo de configuración local. Genera una contraseña aleatoria para PostgreSQL y configura una base llamada `autovida_demo`. Si el archivo ya existe, lo conserva: en ese caso comprueba con `nano .env` que tenga los valores indicados debajo, y no sustituyas la contraseña de una base que ya utilices.

```bash
umask 077
uv run --locked --python 3.12 python - <<'PY'
from pathlib import Path
import secrets

path = Path('.env')
if path.exists():
    print('.env ya existe; se ha conservado. Revisa su configuración antes de continuar.')
else:
    path.write_text(
        'DB_USER=autovida_admin\n'
        f'DB_PASSWORD={secrets.token_hex(24)}\n'
        'DB_HOST=127.0.0.1\n'
        'DB_PORT=5432\n'
        'DB_NAME=autovida_demo\n'
        'CORS_ORIGINS=http://127.0.0.1:5173,http://localhost:5173\n'
        'ENABLE_STUDENT_DIRECTORY=true\n',
        encoding='utf-8',
    )
    print('.env creado con una contraseña aleatoria para PostgreSQL.')
PY
```

Los valores esperados son:

| Variable | Valor |
| --- | --- |
| `DB_USER` | `autovida_admin` |
| `DB_PASSWORD` | La contraseña generada, que debe conservarse entre arranques |
| `DB_HOST` | `127.0.0.1` |
| `DB_PORT` | `5432` |
| `DB_NAME` | `autovida_demo` |
| `CORS_ORIGINS` | `http://127.0.0.1:5173,http://localhost:5173` |
| `ENABLE_STUDENT_DIRECTORY` | `true` |

El archivo está excluido de Git y contiene la contraseña de la base; no lo compartas. La contraseña de PostgreSQL es independiente de las contraseñas para entrar en la aplicación.

## 4. Arrancar PostgreSQL y preparar los datos

En la misma terminal:

```bash
cd "$HOME/proyectos/dgp-mda-2627/src/backend/proyectFastAPI"
sudo docker compose up -d db
sudo docker compose ps
sudo docker compose exec -T db sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
```

El último comando debe indicar `accepting connections`. Si indica que todavía no acepta conexiones, espera unos segundos y repite ese último comando. La primera descarga de PostgreSQL puede tardar.

Ahora crea las tablas, aplica las migraciones y carga usuarios y tareas ficticios:

```bash
cd "$HOME/proyectos/dgp-mda-2627/src/backend"
uv run --project proyectFastAPI --locked --python 3.12 python -m proyectFastAPI.seed_demo
```

Debe aparecer `Fictional accounts created: admin, lucia, familia, pablo, ana. Password: 1234.`. El script lee el esquema SQL de `docs`, sin modificarlo, y aplica todas las migraciones de `src/backend/proyectFastAPI/migrations/`, incluidas las fotos de aulas y las cuentas sin correo. No tienes que ejecutar SQL manualmente.

Si aparece `Demo database already contains accounts; nothing was changed.`, la base ya estaba preparada. El script conserva esas cuentas y sus cambios. Solo permite bases cuyo nombre termina en `_demo`.

Los datos permanecen en un volumen Docker aunque detengas el contenedor. Cambiar `DB_PASSWORD` en `.env` después de crear el volumen no cambia la contraseña que PostgreSQL ya tiene guardada.

## 5. Arrancar el backend — terminal 1

```bash
cd "$HOME/proyectos/dgp-mda-2627/src/backend"
uv run --project proyectFastAPI --locked --python 3.12 python -m uvicorn proyectFastAPI.main:app --env-file proyectFastAPI/.env --host 127.0.0.1 --port 8000
```

Cuando aparezca `Uvicorn running on http://127.0.0.1:8000`, deja esta terminal abierta. Es normal que no vuelva a aparecer el indicador para escribir: el servidor está funcionando.

## 6. Arrancar el frontend — terminal 2

Abre **otra terminal** con Ctrl + Alt + T. Comprueba primero la conexión de la API con PostgreSQL:

```bash
curl --fail http://127.0.0.1:8000/
```

Debe responder con `"errorCode":0` y `"estado":"ok"` (puede variar el espaciado). La API también se puede consultar desde [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs).

Arranca las pantallas Flutter:

```bash
cd "$HOME/proyectos/dgp-mda-2627/src/frontend"
flutter pub get --enforce-lockfile
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=5173 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Espera a que Flutter indique que sirve la aplicación. Deja también esta terminal abierta y abre **http://127.0.0.1:5173** en Firefox o Chrome. Aquí está la aplicación; el puerto 8000 corresponde al backend.

Este arranque conecta las pantallas con PostgreSQL a través de FastAPI. No añadas `--dart-define=DEMO=true`: esa opción activa una demostración independiente que no guarda cambios en el servidor.

## 7. Entrar y probar las pantallas

Las cuentas iniciales comparten la contraseña `1234` y son únicamente datos de prueba:

| Perfil | Usuario | Acceso desde la portada |
| --- | --- | --- |
| Administrador | `admin` | Administración |
| Personal del centro | `lucia` | Personal o tutor → Personal del centro |
| Tutor familiar | `familia` | Personal o tutor → Tutor familiar |
| Alumno | `pablo` o `ana` | Soy alumno → Aula de la autonomía → su nombre/foto |

Para el teclado de dibujos del alumno, pulsa **Corazón · 1**, **Estrella · 2**, **Animal · 3** y **Flor · 4**, y después **Entrar**. También puedes elegir escribir la contraseña con el teclado.

La tarea inicial se crea para el día de la primera preparación de la base. Si entras otro día, usa **Elegir día** para verla o crea una tarea para hoy desde la cuenta `lucia` o `familia`.

Para comprobar el recorrido completo: entra como alumno, abre una tarea pendiente y confirma cada paso. La última confirmación termina la tarea y vuelve a **Mis tareas**. Desde **Ajustes** puedes elegir colores por su nombre y muestra; los alumnos no tienen cambio de contraseña. Desde administración puedes crear usuarios sin correo, subir fotos de alumnos y personalizar las fotos de las aulas.

## 8. Volver a arrancar otro día

No reinstales las herramientas, no regeneres `.env` y no vuelvas a cargar el esquema SQL. Basta con estos dos bloques, cada uno en una terminal distinta.

**Terminal 1 — base de datos, migraciones pendientes y backend:**

```bash
cd "$HOME/proyectos/dgp-mda-2627/src/backend/proyectFastAPI"
sudo docker compose up -d db
sudo docker compose exec -T db sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
cd ..
uv run --project proyectFastAPI --locked --python 3.12 python -m proyectFastAPI.migrate
uv run --project proyectFastAPI --locked --python 3.12 python -m uvicorn proyectFastAPI.main:app --env-file proyectFastAPI/.env --host 127.0.0.1 --port 8000
```

Si PostgreSQL todavía no acepta conexiones, repite la comprobación antes de ejecutar las migraciones. La migración solo aplica versiones pendientes y conserva los datos existentes.

**Terminal 2 — frontend:**

```bash
cd "$HOME/proyectos/dgp-mda-2627/src/frontend"
flutter pub get --enforce-lockfile
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=5173 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Abre de nuevo **http://127.0.0.1:5173**. Debes iniciar sesión otra vez, pero las cuentas, fotos y tareas guardadas siguen en PostgreSQL.

## 9. Apagar la aplicación

1. En la terminal de Flutter, pulsa **Ctrl + C**.
2. En la terminal del backend, pulsa **Ctrl + C**.
3. Para detener también PostgreSQL, ejecuta:

```bash
cd "$HOME/proyectos/dgp-mda-2627/src/backend/proyectFastAPI"
sudo docker compose stop db
```

Este comando conserva los datos para el próximo arranque.

## 10. Solución de problemas frecuentes

| Problema | Qué hacer |
| --- | --- |
| `uv: command not found` o `flutter: command not found` | Ejecuta `export PATH="$HOME/.local/bin:$HOME/develop/flutter/bin:$PATH"` y vuelve a probar. |
| `No such file or directory` al hacer `cd` | Sustituye la ruta de esta guía por la carpeta donde descargaste el repositorio. |
| Git dice que la carpeta de destino ya existe | Utiliza tu copia existente; no vuelvas a clonar encima. |
| `Cannot connect to the Docker daemon` | Ejecuta `sudo systemctl start docker` y vuelve a arrancar PostgreSQL. |
| Docker responde `permission denied` | Usa `sudo docker compose ...`, como en esta guía. |
| El contenedor tarda en arrancar | Comprueba `sudo docker compose logs --tail=50 db` desde la carpeta `src/backend/proyectFastAPI`. |
| El puerto 5432 está ocupado | Ya hay otro PostgreSQL o contenedor. Identifícalo con los comandos de abajo antes de detener ningún servicio. |
| `password authentication failed` | Comprueba que `.env` conserva el usuario y contraseña con los que se creó el volumen. Cambiar solo `.env` no cambia la contraseña de una base existente. |
| `DB_NAME must end in _demo` | Para seguir esta guía de prueba, usa `DB_NAME=autovida_demo` antes de preparar una base nueva. |
| `ModuleNotFoundError: proyectFastAPI` | Ejecuta el comando del backend desde `src/backend`, exactamente como en los pasos 4 y 5. |
| Falta una tabla como `class_content` | Con la base arrancada, ejecuta el comando `proyectFastAPI.migrate` del paso 8. |
| El frontend dice que no puede conectar | Comprueba `curl --fail http://127.0.0.1:8000/`, mantén abierta la terminal del backend y revisa `API_BASE_URL`. |
| Error de CORS | Usa el puerto 5173 y las direcciones de esta guía; comprueba `CORS_ORIGINS` y reinicia el backend si cambias `.env`. |
| Flutter no encuentra Chrome | Este recorrido usa `-d web-server`; abre manualmente la URL en Firefox o Chrome. |
| Flutter muestra avisos sobre Android o Linux desktop | Puedes continuar si compila y sirve la aplicación web. |
| La agenda está vacía | Comprueba la fecha seleccionada y las tareas asignadas a ese alumno; la semilla solo crea la tarea inicial una vez. |
| La sesión caduca al entrar desde otra ventana | Cada cuenta tiene una única sesión activa; usa otra cuenta o inicia sesión de nuevo. |

Para identificar qué ocupa los puertos sin cambiar nada:

```bash
sudo ss -ltnp '( sport = :5432 or sport = :8000 or sport = :5173 )'
sudo docker ps
```

Esta guía es para ejecutar el proyecto localmente con datos ficticios. En este entorno se han comprobado la compilación web, el recorrido de pantallas y la API con PostgreSQL desde Windows; la instalación completa de Ubuntu no se ha ejecutado aquí. No requiere modificar ningún archivo de `docs`.
