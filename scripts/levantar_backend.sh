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

paso() { printf '\n\033[1;32m==>\033[0m %s\n' "$1"; }
aviso() { printf '\033[1;33m[aviso]\033[0m %s\n' "$1"; }
fallo() { printf '\033[1;31m[error]\033[0m %s\n' "$1" >&2; exit 1; }

comprobar_requisitos() {
  command -v docker >/dev/null || fallo 'Falta Docker. Instálalo con: sudo apt install docker.io docker-compose-plugin'
  docker info >/dev/null 2>&1 || fallo 'El demonio de Docker no responde. Prueba: sudo systemctl start docker'
  command -v python3 >/dev/null || fallo 'Falta Python 3.12 o superior.'
}

crear_env_si_falta() {
  [[ -f "$PAQUETE/.env" ]] && return
  paso 'Creando configuración local (.env)'
  local clave
  clave="$(python3 -c 'import secrets; print(secrets.token_urlsafe(18))')"
  cat > "$PAQUETE/.env" <<EOF
DB_USER=autovida_admin
DB_PASSWORD=$clave
DB_HOST=localhost
DB_PORT=5432
DB_NAME=autovida_demo
EOF
  chmod 600 "$PAQUETE/.env"
}

instalar_dependencias_si_faltan() {
  [[ -x "$VENV/bin/python" ]] && return
  paso 'Instalando dependencias de Python'
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --upgrade --quiet pip
  "$VENV/bin/pip" install --quiet \
    'alembic>=1.20.1' 'bcrypt>=4.1.1,<5' 'fastapi[standard]>=0.162.0' \
    'passlib[bcrypt]>=1.7.4' 'python-dotenv>=1.0.0' 'psycopg2-binary>=2.9.13' \
    'psycopg[binary]>=3.3.6' 'pydantic-settings>=2.16.2' 'pyjwt>=2.15.1' \
    'sqlalchemy>=2.1.6'
}

arrancar_base_de_datos() {
  paso 'Arrancando PostgreSQL (contenedor autovida_postgres)'
  (cd "$PAQUETE" && docker compose up -d)
  local intento
  for intento in {1..30}; do
    if docker exec autovida_postgres pg_isready -U autovida_admin >/dev/null 2>&1; then
      return
    fi
    sleep 1
  done
  fallo 'PostgreSQL no llegó a aceptar conexiones.'
}

preparar_datos() {
  paso 'Creando esquema y cuentas de prueba'
  "$VENV/bin/python" "$RAIZ/scripts/datos_de_prueba.py" 2>&1 | grep -v 'bcrypt' || true
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
  (cd "$PAQUETE" && docker compose down)
  exit 0
}

main() {
  if [[ "${1:-}" == '--parar' ]]; then
    parar
  fi
  comprobar_requisitos
  crear_env_si_falta
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
