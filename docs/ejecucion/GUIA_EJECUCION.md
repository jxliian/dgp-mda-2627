# AUTOVIDA: guía de ejecución y resolución de errores

**Entorno:** Linux · **Rama:** `iteracion1` · **Revisión:** 11/11/2026

Esta guía explica cómo preparar el equipo, lanzar la aplicación con `scripts/levantar_backend.sh`, ejecutar Flutter durante el desarrollo y resolver los fallos habituales. Los comandos parten de la raíz del repositorio salvo que se indique otra ubicación.

La estructura y el funcionamiento del código Flutter se documentan en la [guía técnica del frontend](../explicacion%20frontend/GUIA_FRONTEND.md).

## Índice

1. [Preparación y ejecución](#1-preparación-y-ejecución)
   - [Requisitos y dependencias](#11-requisitos-y-dependencias)
   - [Configuración del lanzador](#12-configuración-necesaria-para-el-lanzador)
   - [Lanzar el entorno completo](#13-lanzar-el-entorno-completo)
   - [Desarrollo en dos terminales](#14-ejecución-recomendada-para-desarrollar-flutter)
   - [Demostración y cuentas de prueba](#15-demostración-y-cuentas-de-prueba)
   - [Web y Android](#16-destinos-web-y-android)
   - [Parada](#17-parada)
2. [Diagnóstico de errores](#2-diagnóstico-de-errores)
   - [Arranque y herramientas](#21-arranque-y-herramientas)
   - [Conexión HTTP](#22-conexión-http)
   - [Respuestas rechazadas](#23-respuestas-rechazadas)
   - [Información antigua o acciones ausentes](#24-información-antigua-o-acciones-ausentes)

## 1. Preparación y ejecución

### 1.1. Requisitos y dependencias

El lanzador está preparado para Bash en Linux. Para trabajar sobre este checkout se necesita:

| Requisito | Comprobación |
| --- | --- |
| Git y rama `iteracion1` | `git status --short --branch` |
| Flutter compatible con el lock | `flutter --version` |
| Python 3.12 o superior y `venv` | `python3 --version` |
| Docker y plugin Compose | `docker info` y `docker compose version` |
| Entorno Linux gráfico y dependencias nativas | `flutter doctor -v` |
| Chrome para el destino web | `flutter devices` |

El lock actual requiere Dart `>=3.13.0` y Flutter `>=3.47.0`, aunque el YAML declare un mínimo de Dart inferior. El entorno de referencia utiliza Flutter 3.47.1 y Dart 3.13.1.

En un Ubuntu/Debian compatible, las dependencias de escritorio habituales son:

```bash
sudo apt install python3-venv python3-pip clang cmake ninja-build pkg-config libgtk-3-dev
```

Docker, Compose y Flutter deben estar instalados y accesibles para el usuario de desarrollo. El proyecto se ejecuta sin `sudo`; los permisos que pueda pedir Docker se resuelven por separado.

Desde la raíz:

```bash
git switch iteracion1
git status --short --branch
cd src/frontend
flutter pub get
flutter doctor -v
flutter devices
cd ../..
```

Antes de cambiar de rama deben revisarse los cambios locales. El desarrollo descrito no requiere modificar `main`.

### 1.2. Configuración necesaria para el lanzador

La configuración local del servicio se guarda en `src/backend/proyectFastAPI/.env` y no se versiona. Para una instalación nueva:

```dotenv
DB_USER=autovida_admin
DB_PASSWORD='SUSTITUIR_POR_LA_CLAVE_ACORDADA'
DB_HOST=localhost
DB_PORT=5432
DB_NAME=autovida_db
```

Si existe una configuración y datos previos, deben mantenerse valores compatibles con ese entorno. El script lee el archivo también como shell: sin espacios alrededor de `=` y con valores entrecomillados cuando corresponda.

El lanzador carga y exporta automáticamente las variables del `.env` antes de iniciar los servicios. La API y su proceso de recarga heredan esa configuración; no es necesario ejecutar `source` ni exportar variables manualmente en la terminal.

El lanzador crea el archivo si falta, pero se detiene si no contiene contraseña. Cuando el archivo ya existe con la clave vacía, hay que editarlo; el script no lo completa a partir de una variable antepuesta al comando.

### 1.3. Lanzar el entorno completo

El archivo real es [scripts/levantar_backend.sh](../../scripts/levantar_backend.sh). Desde la raíz:

```bash
bash ./scripts/levantar_backend.sh --con-web
```

| Opción | Resultado |
| --- | --- |
| Sin argumentos | Prepara el servicio y deja la API en primer plano. |
| `--con-web` | Añade Flutter en segundo plano; prefiere escritorio Linux y usa Chrome como alternativa. |
| `--parar` | Detiene el contenedor de PostgreSQL conservando su volumen. |

El nombre informal `./levantar_backend` corresponde a ese archivo. El script solo comprueba el primer argumento y no implementa selector de dispositivo ni de puerto.

Sus fases son comprobación de herramientas, configuración local, preparación de `src/backend/.venv`, arranque del contenedor, preparación de datos de prueba y ejecución de la API. Con `--con-web` lanza Flutter antes de dejar la API en primer plano.

Puertos utilizados: servicio HTTP `8000`, frontend web `5174` y contenedor de datos `5432`. La comprobación inicial de escritorio es parcial; `flutter doctor` y la compilación pueden detectar requisitos adicionales.

El script no instala Flutter. Si no lo encuentra, avisa y continúa levantando el servicio. La creación de datos de prueba se omite cuando ya existen cuentas, por lo que volver a ejecutar el script no restablece contraseñas ni genera de nuevo tareas para hoy.

El arranque está completo cuando la terminal confirma que la API ha terminado de inicializarse y Flutter muestra la portada. Como ambos procesos arrancan por separado, la ventana puede abrirse antes de que la API esté lista. Si la primera consulta falla, esperar a la confirmación del servicio y utilizar «Volver a intentar».

Desde otra terminal se puede comprobar la conexión:

```bash
curl --fail http://127.0.0.1:8000/
```

La respuesta debe ser JSON con `errorCode: 0`. Esta comprobación valida el acceso HTTP; el login con una cuenta de prueba permite comprobar además la sesión y la carga de su pantalla inicial. El modo real no muestra la banda de demostración.

### 1.4. Ejecución recomendada para desarrollar Flutter

Terminal 1, desde la raíz:

```bash
bash ./scripts/levantar_backend.sh
```

Terminal 2, desde la raíz:

```bash
cd src/frontend
flutter run -d linux --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

En la terminal de Flutter, `r` ejecuta hot reload, `R` reinicia el estado Dart y `q` termina la ejecución. Los cambios de dependencias, configuración nativa o `--dart-define` requieren volver a ejecutar el comando.

La URL procede de `AppState.serverUrl`. Los métodos `setServer()` y `setDemo()` permiten reemplazar el repositorio desde código, pero la portada actual no contiene una pantalla de configuración de conexión.

### 1.5. Demostración y cuentas de prueba

```bash
cd src/frontend
flutter run -d linux --dart-define=DEMO=true
```

La portada actual no ofrece un botón para activar demo. La activación se hace con ese parámetro o inyectando el repositorio en una prueba.

| Cuenta de prueba | Rol | Contraseña |
| --- | --- | --- |
| `admin` | Administrador | `1234` |
| `lucia` | Personal | `1234` |
| `familia` | Tutor familiar | `1234` |
| `pablo`, `ana` | Alumno | `1234` |

Estas credenciales corresponden a la demostración y a las cuentas creadas por la semilla del lanzador, mientras no se hayan cambiado. El acceso de alumno con `1234` es Corazón → Estrella → Animal → Flor. Las tareas sembradas corresponden a la fecha de su creación.

### 1.6. Destinos web y Android

El script utiliza un Chrome de pruebas con perfil separado cuando no puede ejecutar escritorio. La API de referencia no declara CORS, por lo que un navegador normal puede bloquear sus peticiones aunque dibuje correctamente la interfaz.

La alternativa local del script equivale a:

```bash
cd src/frontend
flutter run -d chrome --web-port=5174 \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000 \
  --web-browser-flag=--disable-web-security \
  --web-browser-flag=--user-data-dir=/tmp/autovida-chrome
```

Este navegador se reserva para el desarrollo local. Para revisar solo la interfaz en un navegador normal se puede utilizar `DEMO=true`.

En el emulador Android habitual:

```bash
cd src/frontend
flutter run -d IDENTIFICADOR_DEL_EMULADOR \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

En un dispositivo físico, la URL debe ser accesible desde su red. El lanzador escucha en `127.0.0.1`, por lo que esa ejecución local no queda expuesta automáticamente a otros dispositivos. HTTP se permite en debug/profile; la configuración release requiere revisión de red y firma.

### 1.7. Parada

`Ctrl+C` en la terminal del servicio detiene la API. Flutter se cierra desde su terminal o ventana. Para detener el contenedor:

```bash
bash ./scripts/levantar_backend.sh --parar
```

La opción no localiza procesos de Flutter o API abiertos en otras terminales. Si el acceso a Docker requiere privilegios, la parada puede necesitar el comando Compose correspondiente con `sudo`. El volumen se conserva; `down -v` no es una parada normal porque elimina datos.

## 2. Diagnóstico de errores

### 2.1. Arranque y herramientas

| Síntoma | Comprobación y resolución |
| --- | --- |
| No se encuentra `./levantar_backend` | Ejecutar `bash ./scripts/levantar_backend.sh` desde la raíz. |
| El script rechaza ejecutarse | Utilizar el usuario de desarrollo; no ejecutar todo con `sudo`. |
| Docker no responde o no hay Compose | Revisar `docker info`, `docker compose version` y el servicio Docker del equipo. |
| Falta configuración local | Completar el `.env` que utiliza el lanzador. Un archivo existente vacío no se rellena automáticamente. |
| Fallan las dependencias Python | Revisar la terminal del script y el entorno `src/backend/.venv`. No confundirlo con una carpeta dentro del paquete. |
| Flutter no abre | Revisar `flutter doctor -v`, `flutter devices`, entorno gráfico y errores de la terminal. |
| El script elige Linux pero falla al compilar | Completar CMake, compilador, Ninja, GTK y requisitos de plugins; la detección del lanzador no cubre toda la compilación. |
| `No pubspec.yaml file found` | Ejecutar Flutter dentro de `src/frontend`. |
| Resolución de paquetes incompatible | Revisar los mínimos del lock antes de modificar dependencias. |
| Puerto ocupado | Localizar la ejecución anterior con `ss -ltnp` y detener el proceso identificado o ajustar la ejecución manual. |

La ejecución en dos terminales permite separar los errores de Flutter de los del servicio. Las operaciones destructivas sobre datos no son una solución para errores de interfaz o compilación.

#### Docker y contenedor de datos

Si Docker está instalado pero no responde, comprobar el servicio y arrancarlo si está detenido:

```bash
sudo systemctl status docker
sudo systemctl start docker
docker info
docker compose version
```

Si `docker info` falla por permisos, el lanzador intenta utilizar `sudo docker`. No debe ejecutarse todo el script con `sudo`. La opción `--parar` no realiza esa detección de permisos; en ese caso, desde la raíz se puede detener el contenedor con:

```bash
cd src/backend/proyectFastAPI
sudo docker compose down
```

Cuando falla la conexión del lanzador, revisar el contenedor y sus últimas líneas. Si Docker requiere privilegios, anteponer `sudo` también a estas consultas:

```bash
docker ps -a
docker logs --tail 50 autovida_postgres
```

| Mensaje o situación | Resolución |
| --- | --- |
| `password authentication failed` | Comprobar que el `.env` utiliza las credenciales del volumen existente. Cambiar solo ese archivo no cambia la contraseña ya almacenada. |
| La base indicada no existe | Confirmar la configuración y que se está usando el volumen previsto; coordinar la recuperación con el equipo. |
| Contenedor reiniciándose | Revisar el error de sus logs antes de volver a ejecutar el lanzador. |
| Conexión rechazada o timeout | Comprobar contenedor, puerto `5432` y posibles conflictos de red/VPN. |
| Error de versión del volumen | Utilizar la versión compatible con sus datos o acordar su migración con el equipo. |

El lanzador puede sugerir `docker compose down -v` en algunos de estos casos. Esa orden elimina los datos del volumen; no debe utilizarse para intentar reparar la conexión conservando la información existente. Para la parada habitual se usa `--parar` o `docker compose down`.

#### Configuración y dependencias

Si aparece `Falta DB_PASSWORD`, editar `src/backend/proyectFastAPI/.env` y completar la clave acordada. Pasarla como variable al comando solo rellena el archivo cuando todavía no existe. Un error de sintaxis al leerlo se resuelve revisando las asignaciones y sus comillas.

Si la API muestra `Define DB_PASSWORD en el entorno antes de iniciar la API`, comprobar que se está usando la versión actual de `scripts/levantar_backend.sh`. Las versiones anteriores validaban el archivo en subprocesos, pero no exportaban sus variables al arrancar Uvicorn. Con el lanzador actual basta con completar el `.env` y ejecutar `bash scripts/levantar_backend.sh`.

Si falla la creación del entorno Python, instalar `python3-venv` para el intérprete utilizado y comprobar su versión. Si falla la instalación de paquetes, revisar el primer error de `pip`, la conexión y los permisos de `src/backend/.venv`. Un entorno incompleto puede apartarse y recrearse con el lanzador; deben conservarse el `.env` y los datos. No se necesita activar manualmente el entorno: el script invoca su intérprete directamente.

Si `flutter` no se encuentra, añadir el directorio `bin` del SDK al `PATH` de la terminal y comprobar `flutter --version`. Si falla `flutter pub get` por versión de Dart o Flutter, utilizar un SDK compatible con `pubspec.lock`; borrar el lock no corrige la incompatibilidad del entorno.

Para errores de compilación Linux, revisar primero `flutter doctor -v` y los paquetes de la sección de requisitos. Después, desde `src/frontend`, ejecutar `flutter pub get` y repetir `flutter run -d linux`. Si el equipo no tiene sesión gráfica, se necesita un destino disponible en `flutter devices`.

Para un puerto ocupado, `ss -ltnp` permite identificar qué proceso escucha en `8000`, `5174` o `5432`. Cerrar la ejecución anterior desde su terminal. El lanzador tiene puertos fijos; no acepta un argumento para cambiarlos. Una segunda ejecución simultánea puede entrar en conflicto con la primera.

### 2.2. Conexión HTTP

Comprobación básica desde la terminal:

```bash
curl --fail http://127.0.0.1:8000/
```

Si responde desde terminal pero falla en Chrome por origen, se trata de CORS. Puede utilizarse escritorio o el navegador aislado de desarrollo del lanzador. Abrir la URL en otro navegador no hereda sus opciones.

En un móvil, `127.0.0.1` apunta al dispositivo. Hay que verificar la URL compilada, la accesibilidad de red y la dirección donde escucha el servicio.

Una API en `500` o inaccesible se diagnostica en su terminal y en los mensajes del lanzador. No se corrige activando demo como respuesta automática al fallo. La inicialización de datos y credenciales del servicio debe conservar la configuración existente; volver a lanzar el script no restablece cuentas ya creadas.

### 2.3. Respuestas rechazadas

| Respuesta | Revisión desde el cliente |
| --- | --- |
| Credenciales incorrectas | Comprobar usuario, contraseña y rol elegido. |
| Código 1002 | Volver a autenticar; el cliente limpia la sesión al recibirlo. |
| HTTP 403 | Comprobar el perfil y las asociaciones de la operación consumida. |
| HTTP 409 | Revisar duplicados o conflicto de matrícula antes de repetir la acción. |
| HTTP 422 | Comparar nombres, tipos y campos del cuerpo con el contrato utilizado. |
| HTTP 413 o error de imagen | Revisar tamaño y formato del archivo seleccionado. |
| HTTP 500 | Consultar el error del servicio; el cliente presenta un mensaje general. |

Los rechazos de permisos se mantienen como errores. No se sustituyen por datos almacenados ni por respuestas de demostración.

### 2.4. Información antigua o acciones ausentes

| Situación | Punto de revisión |
| --- | --- |
| Total de alumnos antiguo | Confirmación de la operación, `classroomsChanged()` y clave de `LoadPanel`. |
| Foto antigua | Resultado de la subida y `photoChanged()`. |
| Búsqueda muestra una página incorrecta | Filtrar antes de paginar y reiniciar la clave/índice al cambiar el criterio. |
| Preferencias no aplicadas | `profile()`, copia de ajustes, guardado de diferencias y `refreshProfile()`. |
| Agenda vacía | Fecha seleccionada, filtro y destinatario. Las tareas de prueba conservan la fecha de creación. |
| Falta el acceso a ajustes del alumno | Permiso `profile_mod`. |
| Falta creación de tarea propia | Permiso `task_mod`. |
| Falta el botón de completar | Capacidad `canTrackProgress` de la conexión. |
| No aparecen controles de alta para personal | Comportamiento previsto: solo gestiona alumnos existentes. |
| Personal de aula incompleto | `staffComplete` y aviso de información confirmada durante la sesión, especialmente en aulas vacías. |

Hot reload conserva estado. Si se modifican inicializaciones, debe utilizarse hot restart y autenticar de nuevo. Después de cambiar dependencias o configuración nativa se debe detener y volver a ejecutar Flutter; `flutter clean` se reserva para artefactos de compilación que necesiten regenerarse.
