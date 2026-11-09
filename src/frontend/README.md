# AUTOVIDA · Flutter / Dart

Frontend basado en `docs/Pantallas/flujo-pantallas.png`, los bocetos de Figma y los bocetos a mano. La documentación original se conserva sin cambios.

Para Ubuntu, consulta la [guía completa de instalación y arranque](../../README_UBUNTU.md), que integra la base de datos, el backend y el frontend con comandos de consola desde cero.

## Ejecutar

Con Flutter estable instalado y disponible en el PATH:

```powershell
cd src/frontend
flutter pub get
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

La dirección se configura con `API_BASE_URL`. La portada muestra únicamente los accesos por perfil. La API debe estar arrancada y la base de datos debe tener aplicadas las migraciones de esta implementación.

Para revisar todas las pantallas sin servidor, ejecuta:

```powershell
flutter run -d chrome --web-port=5173 --dart-define=DEMO=true
```

La demostración está separada de los datos reales, muestra un aviso permanente y nunca se activa como respuesta a un fallo de red. Sus cambios se reinician al abandonar ese modo o recargar la aplicación.

| Perfil | Usuario de demostración | Contraseña |
| --- | --- | --- |
| Administrador | `admin` | `1234` |
| Personal | `lucia` | `1234` |
| Tutor familiar | `familia` | `1234` |
| Alumno | `pablo`, `ana`, etc. | `1234` |

## Backend y migración

Las ampliaciones del backend fueron autorizadas para completar el flujo. Se mantienen FastAPI, PostgreSQL, los endpoints existentes y sus permisos. En el archivo no versionado `src/backend/proyectFastAPI/.env`, configura `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT` y `DB_NAME`, como en la guía original.

Desde `src/backend`, con el esquema base ya creado:

```powershell
uv run --project proyectFastAPI python -m proyectFastAPI.migrate
uv run --project proyectFastAPI python -m uvicorn proyectFastAPI.main:app --host 0.0.0.0 --port 8000
```

El comando aplica en orden las migraciones pendientes de `proyectFastAPI/migrations/`, en una transacción y registrando su versión. No se ejecutan al importar la API ni modifican archivos de `docs`:

- `001_frontend.sql`: contenido de tareas y pasos y progreso independiente por alumno, tarea y fecha. Al retirar una asignación se limpia su progreso; completar una actividad grupal no completa la de otro alumno.
- `002_class_images.sql`: fotografías personalizables de las aulas, conservadas al renombrarlas.
- `003_optional_account_email.sql`: permite crear cuentas sin correo, conservando los correos existentes y su unicidad.

Variables adicionales:

```dotenv
CORS_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
ENABLE_STUDENT_DIRECTORY=true
```

El directorio anterior al login muestra aulas, nombres de pila, identificadores de acceso y fotos de alumnos matriculados. No expone tareas, preferencias, correos ni contraseñas. Puede desactivarse con `ENABLE_STUDENT_DIRECTORY=false`; permanece el acceso con usuario y contraseña.

Para crear una **base separada de datos ficticios**, configura `DB_NAME=autovida_demo` y ejecuta desde `src/backend`:

```powershell
uv run --project proyectFastAPI python -m proyectFastAPI.seed_demo
```

El script crea la base si no existe, lee el esquema original, aplica la migración y carga las cuentas anteriores y una tarea con pasos. Solo admite nombres de base terminados en `_demo`; si ya contienen cuentas no las modifica. El usuario PostgreSQL necesita permiso para crear esa base. No altera la base de desarrollo ni carga datos reales.

## Pantallas del flujo

Se conservan tarjetas grandes, paginación con flechas, fotografía del alumno, controles inferiores y separación por perfiles. La portada utiliza V2; en móvil se apila como V1.

| Boceto | Implementación |
| --- | --- |
| Portadas V1 / V2 | `WelcomeScreen` |
| Elección de aulas del alumno | `StudentClassesScreen` |
| Buscarse por foto | `StudentSelectionScreen` |
| Login del alumno | `LoginScreen`, dibujos para dígitos y alternativa de teclado |
| Selección de días | `DaysScreen` |
| Pantalla inicial del alumno | `AgendaScreen`, fecha, filtros y paginación |
| Vista de tarea | `TaskDetailScreen` |
| Pantalla de paso | `TaskRunScreen`, temporizador, pausa y confirmación |
| Login personal / tutor | `LoginScreen`, selección de rol |
| Aulas del personal | `StaffClassesScreen` |
| Alumnos del aula | `ClassStudentsScreen` |
| Alumnos del tutor | `FamilyStudentsScreen` |
| Tareas del alumno para personal / tutor | `AgendaScreen` con gestión autorizada |
| Crear / modificar tarea | `TaskEditorScreen` |
| Crear / modificar paso | `StepEditorScreen` |
| Gestión de usuarios | `AdminScreen` |
| Crear / modificar usuario | `UserEditorScreen` |
| Crear / modificar aula | `ClassEditorScreen` |
| Asociaciones | `AssociationsScreen` |
| Ajustes y foto | `SettingsScreen` |

El teclado visual representa los dígitos `0–9` mediante símbolos estables; envía la contraseña numérica habitual, compatible con bcrypt. Las contraseñas alfanuméricas utilizan el teclado convencional.

Personal: tareas dentro de **09:00–15:00**. Familias y alumnado: fuera de ese intervalo o sin hora fija. Se valida la duración completa también en el servidor y se conserva la regla original de horario escolar en fines de semana.

La selección de varios días crea una tarea independiente por fecha de la semana. Si una petición falla, se indican los días ya guardados y el reintento omite esas fechas. Los datos y los pasos de cada tarea se guardan en una transacción. Sustituir instrucciones reinicia su progreso anterior.

La administración dispone de rutas adicionales para gestionar matrículas desde el editor de aulas; las rutas originales del personal mantienen sus restricciones. Solo administración concede permisos de modificar perfiles o crear tareas.

Los formularios de usuarios piden nombre de usuario, nombre, primer apellido, segundo apellido, rol y contraseña; no solicitan correo. El nombre y los apellidos se guardan en el campo existente `full_name`. Administración puede subir la foto de un alumno al crear o modificar su cuenta y no puede eliminar su propia cuenta. El alumno puede cambiar su foto si tiene permiso para modificar su perfil, pero no puede cambiar su contraseña; administración puede restablecerla.

Al abrir una tarea pendiente con pasos desde la agenda del alumno, aparece automáticamente el primero. **He terminado · Siguiente paso** confirma el paso actual y avanza; la última confirmación termina la tarea y vuelve a **Mis tareas**. Las fotos de aulas, alumnos, tareas y pasos tienen un tamaño ampliado.

## API ampliada

| Función | Ruta |
| --- | --- |
| Perfil propio | `GET /users/me` |
| Directorio visual | `GET /auth/student-directory` |
| Foto del directorio | `GET /auth/student-directory/{student_username}/avatar` |
| Agenda propia | `GET /student-tasks/me?task_date=AAAA-MM-DD` |
| Agenda de alumno asociado | `GET /student-tasks/students/{student_username}?task_date=AAAA-MM-DD` |
| Editar tarea propia | `PUT /student-tasks/me/{task_id}?task_date=FECHA_ORIGINAL` |
| Editar tarea individual asociada | `PUT /student-tasks/students/{student_username}/{task_id}?task_date=FECHA_ORIGINAL` |
| Progreso propio | `PATCH /student-tasks/me/{task_id}/progress?task_date=AAAA-MM-DD` |
| Retirar personal | `DELETE /classes/{class_name}/staff/{staff_username}` |
| Matrículas administrativas | `POST` / `DELETE /admin/classes/{class_name}/students/{student_username}` |
| Foto de alumno desde administración | `PUT /admin/students/{student_username}/avatar` |

Creación y edición de tareas aceptan `steps` y `task_image`. Las imágenes se codifican en base64: PNG, JPEG o WebP de hasta 5 MB por imagen. Cada paso contiene `step_title`, `step_description`, `step_duration`, `step_required` y `step_image`; el array determina el orden. El alumno no puede terminar con pasos obligatorios pendientes.

Las rutas de creación y edición de aulas aceptan `class_image` con los mismos formatos y límite. Omitir el campo conserva la foto y enviar `null` la elimina. La foto del alumno se sube como fichero multipart.

El cliente reconoce las ampliaciones mediante OpenAPI y avisa al conectarse a un servidor anterior. El token Bearer permanece en memoria y se elimina al salir o caducar. Cambiar usuario o contraseña revoca la sesión. Se corrigieron además la validación de PNG y la referencia incorrecta a los campos de accesibilidad en creación/edición de usuarios.

## Sin conexión

Durante una sesión de alumno se pueden consultar agendas ya cargadas y confirmar pasos y tareas sin conexión. La caché y la cola se guardan localmente, separadas por servidor y usuario. El aviso de sincronización identifica los cambios pendientes. Se reintenta cada 15 segundos, al consultar la agenda y al pulsar **Sincronizar**. Las confirmaciones son idempotentes.

La planificación nueva requiere conexión. Los errores de permisos no se sustituyen por caché. Si una instrucción cambia mientras hay confirmaciones pendientes, se conserva la cola y se muestra el error para revisión; no se descarta progreso automáticamente. No se cierra voluntariamente la sesión con cambios pendientes de enviar.

La autenticación requiere conexión y el token no se persiste. Después de reiniciar hay que autenticarse otra vez para recuperar la cola del mismo usuario. La caché se elimina al cerrar sesión correctamente; permite recuperar confirmaciones tras un cierre inesperado una vez autenticado de nuevo.

## Accesibilidad y límites

Interfaz en español, controles amplios, etiquetas de acciones, teclado, texto escalable, estados con texto e iconos, colores configurables, contraste alto y lectura en voz cuando esté habilitada. Las fotos se cargan según los permisos y el alumno puede actualizar la suya desde Ajustes.

Los colores de fondo y botones se eligen mediante muestras grandes con nombre, marca de selección y vista previa, sin escribir códigos de color. Las opciones combinan fondos claros con botones oscuros y texto contrastado; el modo de alto contraste sigue disponible.

Los apoyos predeterminados son iconos Material y fotos subidas, no pictogramas ARASAAC. Se pueden adjuntar los materiales específicos del centro a tareas y pasos con su atribución y permisos. La voz depende de las voces españolas del dispositivo; no sustituye una grabación familiar. Queda pendiente la validación con TalkBack, ayudas motrices y alumnado real.

Comedor, menús, visitas, rutinas, notificaciones y chat corresponden a funcionalidades futuras y no tienen pantallas en este flujo. No se han añadido a esta entrega.

## Android y comprobaciones

```powershell
flutter run -d <dispositivo> --dart-define=API_BASE_URL=http://10.0.2.2:8000
flutter build web
flutter build apk --dart-define=API_BASE_URL=https://api.del-centro.example
flutter analyze
flutter test
```

En un emulador Android, `10.0.2.2` apunta al anfitrión; en una tablet física usa la dirección del servidor en su red. HTTP se permite en debug/profile; release requiere HTTPS. El proyecto Android está preparado, pero en este entorno se ha validado Flutter web y no se ha compilado un APK.

Desde `src/backend/proyectFastAPI`, ejecutar las pruebas de integración:

```powershell
uv run --with pytest python -m pytest ../../../tests/integration -q
```

Estas pruebas crean exclusivamente `autovida_test` con el esquema y la migración. Comprueban permisos, horarios, transacciones, imágenes, perfiles, matrículas y progreso por alumno y fecha. Las pruebas Flutter cubren contratos HTTP, sesiones, temporizador, cola sin conexión y recorridos en tablet y móvil con texto ampliado.

## Estructura

`lib/models`: datos, validación y temporizador. `lib/services`: HTTP, repositorio real y demostración aislada. `lib/state`: sesión y sincronización. `lib/screens`: pantallas por flujo. `lib/ui`: tema, controles y navegación. `test`: pruebas. `web` y `android`: plataformas.

## Evidencias de revisión

Capturas de Chrome con datos ficticios: [portada](previews/portada.png), [administración](previews/administracion.png), [editor de tareas](previews/crear_tarea.png) y [ejecución de un paso](previews/paso.png).

Validación realizada: `flutter analyze` sin incidencias; 18 pruebas Flutter superadas; compilación web completada; 167 pruebas PostgreSQL superadas y cuatro fallos esperados anteriores. Las pruebas cubren también las cuentas sin correo, las fotos de aulas y alumnos, la prohibición de cambiar contraseña para alumnos, el bloqueo del autoborrado administrativo y la finalización automática de tareas. No se ha validado Android ni el uso con alumnado real.
