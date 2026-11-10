#!/usr/bin/env bash
# Levanta AUTOVIDA en local: base de datos, API y, si se pide, el frontend.
#
#   ./scripts/levantar_backend.sh            Base de datos + API en el puerto 8000
#   ./scripts/levantar_backend.sh --con-web  Además abre el frontend (escritorio
#                                            Linux si se puede, si no Chrome)
#   ./scripts/levantar_backend.sh --parar    Detiene la base de datos
#
# El backend es el de la rama main y no se toca: este script solo crea .env,
# .venv y los datos de prueba, todo ello ignorado por git.
#
# La configuración de la base sigue la guía del equipo:
#   docs/diseno_arquitectura/arquitectura/guia_configuracion_base_de_datos.md
# De ahí salen el nombre de la base (autovida_db), el usuario y el hecho de
# que la contraseña sea la acordada entre todos, no una generada aquí: si cada
# uno usara la suya, los volúmenes de PostgreSQL serían incompatibles.
#
# Nota sobre CORS: la API de main no lleva middleware de CORS, así que un
# navegador bloquea las llamadas entre el puerto del frontend y el de la API.
# La aplicación de escritorio no tiene ese problema y es la forma preferida de
# ejecutarla; el navegador queda como alternativa de desarrollo.
set -euo pipefail

readonly RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BACKEND="$RAIZ/src/backend"
readonly PAQUETE="$BACKEND/proyectFastAPI"
readonly FRONTEND="$RAIZ/src/frontend"
readonly VENV="$BACKEND/.venv"
readonly PUERTO_API=8000
readonly PUERTO_WEB=5174
readonly PERFIL_CHROME=/tmp/autovida-chrome
readonly GUIA='docs/diseno_arquitectura/arquitectura/guia_configuracion_base_de_datos.md'
readonly BASE_DE_DATOS=autovida_db

DOCKER=docker  # pasa a «sudo docker» si este equipo lo necesita

paso() { printf '\n\033[1;32m==>\033[0m %s\n' "$1"; }
aviso() { printf '\033[1;33m[aviso]\033[0m %s\n' "$1"; }
fallo() { printf '\033[1;31m[error]\033[0m %s\n' "$1" >&2; exit 1; }

comprobar_requisitos() {
  if [[ $EUID -eq 0 ]]; then
    fallo 'No lo ejecutes con sudo: crearía .venv y .env como root y después tu
         usuario normal no podría usarlos. Si ya lo has hecho, limpia así:
           sudo rm -rf src/backend/.venv src/backend/proyectFastAPI/.env
           (cd src/backend/proyectFastAPI && docker compose down -v)
         El segundo comando borra el volumen de la base a propósito: la
         contraseña quedó fijada al crearlo y no coincidiría con el .env nuevo.
         Si usabas sudo porque Docker pide permisos, añádete a su grupo:
           sudo usermod -aG docker $USER   (y vuelve a iniciar sesión)'
  fi
  command -v docker >/dev/null || fallo 'Falta Docker. Instálalo con: sudo apt install docker.io docker-compose-plugin'
  if ! docker info >/dev/null 2>&1; then
    # La guía del equipo usa «sudo docker compose»: si hace falta, se pide.
    sudo -n true 2>/dev/null || aviso 'Docker pide permisos: puede que te pregunte la contraseña.'
    sudo docker info >/dev/null 2>&1 || fallo 'Docker no responde. Arráncalo con: sudo systemctl start docker
         Para no usar sudo cada vez: sudo usermod -aG docker $USER (y vuelve a iniciar sesión)'
    DOCKER='sudo docker'
  fi
  command -v python3 >/dev/null || fallo 'Falta Python 3.12 o superior.'
}

# La contraseña es la que haya acordado el equipo. Se puede dar una sola vez:
#   DB_PASSWORD='la acordada' ./scripts/levantar_backend.sh
comprobar_env() {
  if [[ ! -f "$PAQUETE/.env" ]]; then
    paso 'Creando configuración local (.env)'
    cat > "$PAQUETE/.env" <<EOF
DB_USER=autovida_admin
DB_PASSWORD=${DB_PASSWORD:-}
DB_HOST=localhost
DB_PORT=5432
DB_NAME=$BASE_DE_DATOS
EOF
    chmod 600 "$PAQUETE/.env"
  fi
  local clave
  clave="$(set -a; . "$PAQUETE/.env"; set +a; printf '%s' "${DB_PASSWORD:-}")"
  if [[ -z "$clave" ]]; then
    fallo "Falta DB_PASSWORD en src/backend/proyectFastAPI/.env
         Pon ahí la contraseña acordada por el equipo, la misma para todos.
         La documenta $GUIA
         También puedes darla de una vez:
           DB_PASSWORD='la acordada' ./scripts/levantar_backend.sh"
  fi
}

# Un entorno a medio instalar es el fallo más común al estrenar el proyecto en
# otra máquina, así que se comprueba que los paquetes se importan de verdad y
# no solo que exista la carpeta .venv.
# Se leen del pyproject.toml del backend para no mantener una copia aparte.
dependencias_del_backend() {
  python3 - "$PAQUETE/pyproject.toml" <<'PY'
import sys, tomllib, pathlib
datos = tomllib.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
print('\n'.join(datos['project']['dependencies']))
PY
}

entorno_completo() {
  [[ -x "$VENV/bin/python" ]] || return 1
  "$VENV/bin/python" -c 'import dotenv, fastapi, passlib, psycopg2, sqlalchemy, uvicorn' \
    >/dev/null 2>&1
}

instalar_dependencias_si_faltan() {
  if entorno_completo; then
    return
  fi
  paso 'Instalando dependencias de Python'
  if [[ ! -x "$VENV/bin/python" ]]; then
    python3 -m venv "$VENV" ||
      fallo 'No se pudo crear el entorno. Instálalo con: sudo apt install python3-venv'
  fi
  "$VENV/bin/python" -m pip install --upgrade --quiet pip ||
    fallo "El entorno está incompleto. Bórralo y repite: rm -rf '$VENV'"
  local dependencias
  mapfile -t dependencias < <(dependencias_del_backend)
  "$VENV/bin/python" -m pip install --quiet "${dependencias[@]}" ||
    fallo 'No se pudieron instalar las dependencias. ¿Hay conexión a internet?'
  entorno_completo ||
    fallo "Las dependencias siguen sin cargarse. Borra '$VENV' y vuelve a intentarlo."
}

# Una conexión de verdad desde el equipo, con las credenciales del .env. Es lo
# que de verdad necesita la aplicación: pg_isready puede decir que todo va bien
# mientras el servidor sigue arrancando, la contraseña no coincide con la que
# quedó grabada en el volumen, o la red del contenedor está cortada.
conexion_real_funciona() {
  "$VENV/bin/python" - <<'PY' 
import os, sys, psycopg2
try:
    psycopg2.connect(host=os.environ.get('DB_HOST', 'localhost'),
                     port=int(os.environ.get('DB_PORT', '5432')),
                     user=os.environ['DB_USER'], password=os.environ['DB_PASSWORD'],
                     dbname='postgres', connect_timeout=4).close()
except Exception as error:
    print(error, file=sys.stderr)
    sys.exit(1)
PY
}

diagnosticar_base_de_datos() {
  local motivo
  motivo="$(set -a; . "$PAQUETE/.env"; set +a; conexion_real_funciona 2>&1 >/dev/null || true)"
  printf '\n--- Últimas líneas del contenedor ---\n' >&2
  $DOCKER logs --tail 25 autovida_postgres 2>&1 | sed 's/^/  /' >&2
  printf -- '--- Error de conexión ---\n  %s\n\n' "$motivo" >&2
  case "$motivo" in
    *'password authentication failed'*)
      fallo 'La contraseña del .env no coincide con la que guarda el volumen.
         La contraseña queda fijada al crear la base. Para empezar de cero:
           (cd src/backend/proyectFastAPI && docker compose down -v)' ;;
    *'closed the connection'*|*'could not connect'*|*'timeout expired'*|*'Connection refused'*)
      fallo 'PostgreSQL no atiende desde este equipo. Lo más habitual:
         - El contenedor se está reiniciando: míralo con docker ps -a
         - El volumen viene de otra versión de PostgreSQL. Para empezar de cero:
             (cd src/backend/proyectFastAPI && docker compose down -v)
         - Una VPN se ha quedado con el rango de red de Docker. Compruébalo con:
             ip route get "$($DOCKER inspect autovida_postgres \
               --format "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}")"
           Si la ruta sale por un túnel (tun0, cscotun0...), desconecta la VPN.' ;;
    *) fallo 'PostgreSQL no acepta conexiones. El motivo está justo encima.' ;;
  esac
}

arrancar_base_de_datos() {
  paso 'Arrancando PostgreSQL (contenedor autovida_postgres)'
  (cd "$PAQUETE" && $DOCKER compose up -d)
  local intento
  for intento in {1..30}; do
    if (set -a; . "$PAQUETE/.env"; set +a; conexion_real_funciona >/dev/null 2>&1); then
      return
    fi
    sleep 2
  done
  diagnosticar_base_de_datos
}

preparar_datos() {
  paso 'Creando esquema y cuentas de prueba'
  local salida
  if ! salida="$("$VENV/bin/python" "$RAIZ/scripts/datos_de_prueba.py" 2>&1)"; then
    grep -v 'bcrypt' <<<"$salida" >&2 || true
    fallo 'No se pudieron crear los datos de prueba. El error está justo encima.'
  fi
  grep -v 'bcrypt' <<<"$salida" || true
}

arrancar_api() {
  paso "API en http://127.0.0.1:$PUERTO_API  (documentación en /docs)"
  (cd "$BACKEND" && exec "$VENV/bin/python" -m uvicorn proyectFastAPI.main:app \
    --host 127.0.0.1 --port "$PUERTO_API" --reload)
}

hay_escritorio_linux() {
  command -v ninja >/dev/null &&
    { command -v clang >/dev/null || command -v g++ >/dev/null; } &&
    pkg-config --exists gtk+-3.0
}

# Aplicación de escritorio: no pasa por el navegador, así que no hay CORS.
arrancar_escritorio() {
  paso 'Abriendo la aplicación de escritorio'
  (cd "$FRONTEND" && flutter run -d linux \
    --dart-define=API_BASE_URL="http://127.0.0.1:$PUERTO_API") &
}

# Alternativa en navegador, solo para desarrollo: Chrome con perfil propio y
# sin comprobación de origen, porque la API de main no declara CORS.
arrancar_navegador() {
  paso "Frontend en http://127.0.0.1:$PUERTO_WEB"
  aviso 'Sin escritorio Linux: uso Chrome sin comprobación de origen.'
  aviso 'Para la versión de escritorio: sudo apt install clang ninja-build libgtk-3-dev'
  (cd "$FRONTEND" && flutter run -d chrome --web-port "$PUERTO_WEB" \
    --dart-define=API_BASE_URL="http://127.0.0.1:$PUERTO_API" \
    --web-browser-flag=--disable-web-security \
    --web-browser-flag="--user-data-dir=$PERFIL_CHROME") &
}

arrancar_frontend() {
  command -v flutter >/dev/null || { aviso 'Flutter no está en el PATH; omito el frontend.'; return; }
  if hay_escritorio_linux; then
    arrancar_escritorio
  else
    arrancar_navegador
  fi
}

parar() {
  paso 'Deteniendo PostgreSQL'
  (cd "$PAQUETE" && $DOCKER compose down)
  exit 0
}

main() {
  if [[ "${1:-}" == '--parar' ]]; then
    parar
  fi
  comprobar_requisitos
  comprobar_env
  instalar_dependencias_si_faltan
  arrancar_base_de_datos
  preparar_datos
  if [[ "${1:-}" == '--con-web' ]]; then
    arrancar_frontend
  fi
  cat <<'EOF'

  Cuentas de prueba (contraseña 1234):
    admin    administración
    lucia    personal del centro
    familia  tutor familiar
    pablo    alumno        ana  alumna

  Ctrl+C detiene la API. La base de datos sigue viva: ./scripts/levantar_backend.sh --parar
EOF
  arrancar_api
}

main "$@"
