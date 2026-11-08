# Guía del backend AUTOVIDA

Esta guía describe las rutas HTTP que registra actualmente `proyectFastAPI/main.py`, qué usuarios pueden usarlas, qué validan y cómo afectan a los datos. Está escrita a partir del código del backend; no describe pantallas del frontend.

## Convenciones comunes

- La API se conecta a PostgreSQL mediante una sesión SQLAlchemy por petición. La sesión se cierra al terminar la petición.
- Las rutas protegidas esperan `Authorization: Bearer <token>`. El servidor calcula SHA-256 del token recibido y busca ese hash en `users.token`. El token sin hash solo se devuelve al iniciar sesión.
- Cada usuario tiene un solo token activo. Un login correcto reemplaza el token guardado anteriormente; logout lo pone a `NULL`.
- Los roles reconocidos son `admin`, `staff`, `student` y `parent`.
- Las respuestas correctas usan el sobre `{"errorCode": 0, "details": "successful", ...}`. Los errores usan `{"errorCode": <código>, "details": "<mensaje>"}` y un estado HTTP asociado. Los errores de validación de FastAPI se presentan como código `1005` y HTTP 422. Los errores internos se presentan como código `1500` y HTTP 500, sin exponer detalles SQL.
- Salvo donde se indica otro estado, las rutas correctas responden HTTP 200. Las rutas de creación que lo especifican responden HTTP 201.
- La API ejecuta las mutaciones en transacciones y confirma los cambios con `COMMIT`; cuando detecta un error en una operación transaccional revierte con `ROLLBACK`.

## Salud de la API

### `GET /` — Comprobar conexión con la base de datos

No requiere autenticación. Ejecuta `SELECT 1` en PostgreSQL y devuelve `estado: "ok"` y `mensaje: "API conectada a PostgreSQL"` dentro del sobre de éxito. Si no se puede ejecutar la consulta, la respuesta pasa por el manejador de error interno.

**Entrada:** sin cuerpo ni parámetros.

**Respuesta JSON:**
```json
{"errorCode": 0, "details": "successful", "estado": "ok", "mensaje": "API conectada a PostgreSQL"}
```

## Autenticación

### `POST /auth/login` — Iniciar sesión

Recibe JSON con `username`, `password` y `role`. El usuario y contraseña deben estar presentes; el rol debe ser uno de los cuatro roles admitidos.

El servidor busca la cuenta en `users` junto a la tabla hija correspondiente al rol y compara la contraseña recibida con el hash bcrypt almacenado. Si coincide, genera un token aleatorio, guarda su hash SHA-256 en `users.token` y confirma el cambio. El token anterior de ese usuario deja de servir. La respuesta incluye `access_token`, `token_type: "bearer"` y la identidad `{username, role}`.

Una contraseña incorrecta o una combinación de usuario/rol que no corresponde devuelve `INVALID_CREDENTIALS` (HTTP 401). Un rol no admitido devuelve `INVALID_ROLE` (HTTP 400). Un fallo de infraestructura de autenticación devuelve `LOGIN_FAILED` (HTTP 500).

**JSON de entrada:**
```json
{"username": "ana", "password": "contraseña", "role": "parent"}
```

**Respuesta correcta (el token real es aleatorio):**
```json
{"errorCode": 0, "details": "successful", "access_token": "<token>", "token_type": "bearer", "user": {"username": "ana", "role": "parent"}}
```

**Ejemplo de error:**
```json
{"errorCode": 1001, "details": "Usuario o contraseña incorrectos"}
```

### `POST /auth/logout` — Cerrar sesión

Requiere un Bearer válido. La dependencia primero verifica que el token corresponde a una sesión activa. Después, el endpoint guarda `NULL` en `users.token` para ese token y confirma la transacción. La respuesta identifica el usuario y rol cuya sesión se cerró. Si falta el token, no es válido o ya fue revocado, devuelve `INVALID_TOKEN` (HTTP 401).

**Entrada:** sin cuerpo. Cabecera: `Authorization: Bearer <token>`.

**Respuesta JSON:**
```json
{"errorCode": 0, "details": "successful", "username": "ana", "role": "parent"}
```

### Dependencias de autenticación utilizadas por otras rutas

- `get_current_user` valida el Bearer y aporta `username` y `role` a la operación. Un token ausente o inválido impide acceder con HTTP 401.
- `require_admin` además exige el rol `admin`; el resto recibe `ADMIN_REQUIRED` (HTTP 403).
- Un token nuevo invalida el anterior para ese usuario. Cambiar contraseña o username también revoca la sesión al actualizar `users.token`.

## Gestión de usuarios

Todas las rutas de este grupo tienen prefijo `/users`.

### `POST /users` — Crear usuario

Solo administrador. Recibe un objeto JSON discriminado por `role`.

Campos comunes obligatorios: `username`, `full_name` y `password`. El username se recorta y no puede contener espacios; el nombre completo se recorta, debe contener alguna letra y no puede contener números. La contraseña no puede superar 72 bytes UTF-8 (límite de bcrypt). No se aceptan campos no definidos.

Para `role: "student"` también son obligatorios todos los campos de accesibilidad: `stud_access_main_col`, `stud_access_sec_col`, `stud_access_ntasks_visible`, `stud_access_pictograms`, `stud_access_contrast`, `stud_access_fontsize`, `stud_access_filters`, `stud_access_ndays_visible`, `stud_access_prof_mod`, `stud_access_timebar`, `stud_access_talkback`, `stud_access_profile_mod` y `stud_access_task_mod`. Las cantidades visibles no pueden ser negativas y el tamaño de fuente debe ser positivo.

Para `admin`, `staff` y `parent`, también es obligatorio `email`, que debe tener formato válido.

La operación inserta la fila común en `users` (incluido el hash bcrypt de la contraseña y `full_name`) y después la especialización del rol en `Admn`, `Staff`, `Student` o `Parents`, con los datos de email o accesibilidad que correspondan. Se confirman ambas inserciones conjuntamente. El username es único en la tabla común, por lo que no puede repetirse entre roles. Según el conflicto, se devuelve `USERNAME_TAKEN` o `EMAIL_TAKEN` (HTTP 409); otros errores de creación usan `USER_CREATE_FAILED` (HTTP 500).

El rol se fija al crear la cuenta y es inmutable. Ni el propio usuario ni un administrador pueden cambiarlo después; para cambiar el rol hay que crear una cuenta nueva con el rol correcto.

**JSON de entrada para estudiante:**
```json
{"username":"luis","full_name":"Luis Pérez","password":"clave","role":"student","stud_access_main_col":"#ffffff","stud_access_sec_col":"#000000","stud_access_ntasks_visible":5,"stud_access_pictograms":true,"stud_access_contrast":false,"stud_access_fontsize":18,"stud_access_filters":true,"stud_access_ndays_visible":7,"stud_access_prof_mod":false,"stud_access_timebar":true,"stud_access_talkback":false,"stud_access_profile_mod":true,"stud_access_task_mod":true}
```

**JSON de entrada para admin, staff o parent:**
```json
{"username":"ana","full_name":"Ana López","password":"clave","role":"parent","email":"ana@example.com"}
```

**Respuesta correcta:**
```json
{"errorCode": 0, "details": "successful"}
```

### `GET /users` y `GET /users?role=<rol>` — Listar usuarios

Solo administrador. Sin `role`, reúne usuarios de las cuatro tablas hijas; con `role`, filtra a un solo rol. Cada resultado contiene username, full name, rol y email cuando el rol tiene correo. Para estudiantes también incluye sus atributos de accesibilidad. La lista se ordena por username. No devuelve contraseñas ni tokens.

Un rol inválido devuelve `INVALID_ROLE` (HTTP 400); fallos de consulta devuelven `USER_LIST_FAILED` (HTTP 500).

**Entrada:** sin cuerpo. Filtro opcional en query, por ejemplo `?role=student`.

**Respuesta JSON (ejemplo abreviado):**
```json
{"errorCode":0,"details":"successful","users":[{"username":"ana","full_name":"Ana López","role":"parent","email":"ana@example.com"},{"username":"luis","full_name":"Luis Pérez","role":"student","stud_access_main_col":"#ffffff","stud_access_sec_col":"#000000","stud_access_ntasks_visible":5,"stud_access_pictograms":true,"stud_access_contrast":false,"stud_access_fontsize":18,"stud_access_filters":true,"stud_access_ndays_visible":7,"stud_access_prof_mod":false,"stud_access_timebar":true,"stud_access_talkback":false,"stud_access_profile_mod":true,"stud_access_task_mod":true}]}
```

### `PUT /users/{role}/{username}` — Editar perfil o datos de usuario

Requiere autenticación. Un administrador puede editar cualquier cuenta. Un `parent`, `staff` o `student` solo puede editar su propio perfil y no puede enviar `username`, `full_name` ni `role`. Para estudiantes, además se comprueba que `stud_access_profile_mod` sea verdadero; si es falso, se rechaza la edición propia. Ningún usuario puede cambiar el rol de una cuenta: un administrador que envíe un `role` distinto del actual recibe `ROLE_CHANGE_DENIED` (HTTP 403); un usuario no administrador que envíe `role` recibe `PROFILE_UPDATE_DENIED` (HTTP 403).

El JSON acepta campos opcionales: `username`, `role`, `full_name`, `password`, `email` y campos `stud_access_*`. No se aceptan propiedades extra. Debe haber al menos un campo que modificar. El username y el nombre completo aplican validaciones iguales a las de creación; la contraseña está limitada a 72 bytes.

Cambiar username actualiza la clave común y las referencias en cascada; también actualiza `Tasks.task_creator` y `Alt_Tasks.alt_task_creator`. Cambiar username o contraseña invalida el token activo. Cambiar solo `full_name`, email o accesibilidad no invalida el token. El rol y su fila de especialización no se modifican mediante esta ruta.

Los roles con email deben conservar o recibir un email válido; estudiantes no admiten email. La respuesta de éxito devuelve el `username` y el rol resultante.

Errores relevantes: `PROFILE_UPDATE_DENIED` (403), `ROLE_CHANGE_DENIED` (403), `USER_NOT_FOUND` (404), `USERNAME_TAKEN`/`EMAIL_TAKEN` (409), `NO_UPDATE_FIELDS`, `INVALID_REQUEST`, `EMAIL_REQUIRED`, `EMAIL_UNAVAILABLE` y `LAST_ADMIN` (400 según catálogo).

**JSON de entrada (ejemplo de cambios parciales; solo se envían los campos que se desean modificar):**
```json
{"full_name":"Nombre actualizado","email":"nuevo@example.com","password":"nueva-clave"}
```

**Respuesta correcta:**
```json
{"errorCode":0,"details":"successful","username":"ana","role":"parent"}
```

### `DELETE /users/{role}/{username}` — Eliminar usuario

Solo administrador. Borra la cuenta de `users` únicamente si existe la especialización indicada en la tabla hija del rol. Las claves foráneas determinan la eliminación de los datos dependientes. Para administradores, bloquea la tabla de administradores y comprueba que no sea el último antes de borrar. Si la cuenta no existe devuelve `USER_NOT_FOUND`; si se intenta borrar el último admin, `LAST_ADMIN`. El token de la cuenta borrada deja de poder validarse al desaparecer el usuario.

**Entrada:** sin cuerpo. Ejemplo: `DELETE /users/parent/ana`.

**Respuesta correcta:**
```json
{"errorCode":0,"details":"successful"}
```

### `PUT /users/students/me/avatar` — Actualizar mi avatar

Requiere token de alumno. Recibe `multipart/form-data` con el archivo en el campo `file`. Admite PNG, JPEG y WebP de hasta 5 MB; el backend comprueba la firma y estructura básica del formato, y rechaza formatos no admitidos o archivos demasiado grandes con `AVATAR_INVALID_IMAGE` (HTTP 422) o `AVATAR_TOO_LARGE` (HTTP 413). La subida también requiere `stud_access_profile_mod = true`.

La imagen se guarda en `Avatar.avatar_bin` y su clave se vincula a `Student.avatar_id_fk` en una transacción. Al reemplazar una foto anterior, el backend la elimina si ya no está vinculada a ningún alumno. La respuesta JSON incluye `avatar_id`, `media_type` y `avatar_url`.

El cliente puede abrir el selector de imágenes del dispositivo (por ejemplo, la galería) y enviar el archivo en `file`. Tras una respuesta correcta debe mostrar la foto nueva inmediatamente, usando la URL devuelta o `GET /users/students/me/avatar`; esta ruta evita caché con `Cache-Control: no-store`. El control para cambiarla debe ser visible, tener un área de pulsación amplia, un icono comprensible y un nombre accesible para lectores de pantalla. Si la subida falla por tamaño o formato, la interfaz debe conservar la foto que ya tenía el perfil y mostrar un mensaje de error sencillo. Estos requisitos describen el contrato esperado del cliente; esta guía documenta el backend y no implica que exista aquí una interfaz frontend implementada.

**Entrada:** `multipart/form-data`, campo `file` con los bytes de la imagen; no es JSON.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","avatar_id":12,"media_type":"image/png","avatar_url":"/users/students/me/avatar"}
```

### `GET /users/students/me/avatar` — Obtener mi avatar

Requiere token de alumno y devuelve directamente la imagen con su tipo MIME. Si el alumno todavía no tiene una foto válida, devuelve una silueta SVG predeterminada para que el perfil siempre pueda mostrar una imagen. La respuesta usa `Cache-Control: no-store` para que una foto recién actualizada no se quede en caché.

**Entrada:** sin cuerpo. Cabecera: `Authorization: Bearer <token>`.

**Respuesta:** contenido binario de imagen (PNG, JPEG o WebP), o SVG predeterminado; no devuelve JSON. El encabezado `Content-Type` indica el formato y `Cache-Control: no-store` evita caché.

## Asociaciones alumno–tutor/personal

Todas las rutas usan el prefijo `/student-links`. Las relaciones se almacenan en `par_stud` (tutores, rol `parent`) y `staff_stud` (personal, rol `staff`). No crean ni borran cuentas.

### `POST /student-links/students/{student_username}/parents/{parent_username}` — Asociar tutor a alumno

Solo administrador. Comprueba que existen el alumno y el tutor en `users` y sus tablas de rol. Inserta la relación alumno–tutor. Si ya existe, `ON CONFLICT DO NOTHING` evita duplicarla; la respuesta sigue siendo exitosa e indica `association_created: false`. Si se creó, indica `true`.

**Entrada:** sin cuerpo; usernames en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","association_created":true,"student_username":"luis","parent_username":"ana","relation":"tutor"}
```

### `DELETE /student-links/students/{student_username}/parents/{parent_username}` — Desasociar tutor de alumno

Solo administrador. Elimina únicamente esa relación de `par_stud`. Si no existía, devuelve `ASSOCIATION_NOT_FOUND` (HTTP 404). No borra el alumno, el tutor ni otras relaciones.

**Entrada:** sin cuerpo; usernames en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","student_username":"luis","parent_username":"ana"}
```

### `POST /student-links/students/{student_username}/staff/{staff_username}` — Asociar personal a alumno

Solo administrador. Comprueba que existen el alumno y el miembro del personal, e inserta en `staff_stud`. Evita duplicados de la misma forma que el endpoint de tutores e informa con `association_created`.

**Entrada:** sin cuerpo; usernames en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","association_created":true,"student_username":"luis","staff_username":"marta","relation":"profesor"}
```

### `DELETE /student-links/students/{student_username}/staff/{staff_username}` — Desasociar personal de alumno

Solo administrador. Elimina solamente esa relación de `staff_stud`; una relación inexistente devuelve `ASSOCIATION_NOT_FOUND`.

**Entrada:** sin cuerpo; usernames en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","student_username":"luis","staff_username":"marta"}
```

### `GET /student-links/students/{student_username}` — Consultar tutores y personal de un alumno

Solo administrador. Devuelve dos listas actuales: `parents` y `staff`. Cada entrada incluye username, full name y email del usuario relacionado. Si no existe el alumno, devuelve `ASSOCIATED_ENTITY_NOT_FOUND` (HTTP 404). Las listas reflejan las filas de asociación vigentes en la base de datos.

**Entrada:** sin cuerpo; username en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","student_username":"luis","parents":[{"username":"ana","full_name":"Ana López","email":"ana@example.com"}],"staff":[{"username":"marta","full_name":"Marta Ruiz","email":"marta@example.com"}]}
```

### `GET /student-links/parents/{parent_username}/students` — Consultar alumnos de un tutor

Requiere token. Un tutor consulta su propio listado; un administrador puede consultar cualquier tutor. Otros roles, o un tutor que intente consultar otro username, reciben `ASSOCIATION_ACCESS_DENIED` (HTTP 403). Devuelve `username` y `full_name` de cada alumno asociado, ordenados por username. Sin asociaciones, devuelve `students: []`.

**Entrada:** sin cuerpo; cabecera Bearer y username del tutor en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","parent_username":"ana","students":[{"username":"luis","full_name":"Luis Pérez"}]}
```

### `GET /student-links/staff/{staff_username}/students` — Consultar alumnos de un miembro del personal

Igual que la consulta de tutores, pero para personal. Staff consulta su propio listado; admin puede consultar cualquiera. Devuelve `username` y `full_name`; un resultado vacío es `students: []`.

**Entrada:** sin cuerpo; cabecera Bearer y username del miembro del personal en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","staff_username":"marta","students":[{"username":"luis","full_name":"Luis Pérez"}]}
```

Las asociaciones también son una condición de autorización en las operaciones de tareas individuales: quitar una relación impide a ese tutor o miembro del personal seguir creando, editando alternativa o retirando tareas de ese alumno mediante esas rutas.

## Tareas individuales de alumnos

Prefijo `/student-tasks`. El personal (`staff`) y los tutores (`parent`) pueden crear tareas para alumnos asociados. El alumno puede crear y eliminar solo sus propias tareas mediante las rutas `/me`, si `stud_access_task_mod` está activado. El administrador no está autorizado por este router. Las rutas de edición de tareas alternativas siguen reservadas a `staff` y `parent`.

### `POST /student-tasks/students/{student_username}` — Crear tarea en la agenda de un alumno

Responde HTTP 201. El JSON requiere `task_title`, `task_date`, `task_index` y `task_duration`. El título se recorta y debe contener entre 1 y 100 caracteres; el índice debe ser un entero no negativo y la duración un entero positivo expresado en minutos. Son opcionales `task_start_hour` (hora local sin zona) y `alt_task_id_fk` (entero positivo). Si falta la duración, es `null` o no es positiva, FastAPI rechaza la petición con error de validación `1005` (HTTP 422). No admite propiedades adicionales.

El alumno debe existir y el usuario autenticado debe estar asociado a él según su rol. Cuando se indica `task_start_hour`, el backend comprueba el intervalo completo `[hora de inicio, hora de inicio + duración)`: la tarea de `staff` debe empezar a las 09:00 o después y terminar a las 15:00 o antes; la de `parent` no puede solaparse con el horario escolar `[09:00, 15:00)`. Por ejemplo, una tarea de personal que comienza a las 14:45 y dura 30 minutos se rechaza, igual que una de tutor que empieza a las 08:45 y dura 30 minutos. En los límites, terminar exactamente a las 09:00 o empezar exactamente a las 15:00 no se considera solapamiento para tutores; el personal sí puede terminar exactamente a las 15:00. Si se indica alternativa, esta debe existir y no estar ya enlazada a otra tarea.

La operación inserta en `Tasks` con `task_creator` igual al username del creador, `task_duration` positiva y `task_finished = false`, añade el subtipo `Generic_Task` y crea la asignación `stud_task` con alumno, tarea, índice y fecha. Todo se confirma en una transacción. La respuesta incluye datos de tarea y de asignación. El esquema también impone `NOT NULL` y `CHECK (> 0)` en `Tasks.task_duration` y `Alt_Tasks.alt_task_duration`; las alternativas ya almacenadas deben cumplirlo aunque esta API solo las asocie.

`CreacionTablas.sqlscript` recrea el esquema completo: elimina primero las tablas existentes y después vuelve a crearlas. Es destructivo y borra todos los datos de esas tablas; se debe ejecutar solo cuando se quiera reiniciar la base de datos.

La hora de inicio es opcional, pero la duración siempre es obligatoria. Si se omite `task_start_hour`, no hay un intervalo horario que comprobar y no se aplica esta regla.

### `POST /student-tasks/me` — Crear una tarea propia

Requiere token de alumno. El JSON acepta los campos de creación individual, pero exige también `task_start_hour`, ya que el alumno solo puede crear tareas fuera del horario escolar. La duración es obligatoria y positiva, en minutos. El alumno debe tener `stud_access_task_mod = true`; si no, responde `STUDENT_TASK_MODIFICATION_DENIED` (HTTP 403). Se crea una tarea `Generic_Task` con `task_creator` igual al username del alumno y una asignación en `stud_task` para ese mismo alumno. La hora de inicio más la duración no puede solaparse con `[09:00, 15:00)`; si se solapa, responde `STUDENT_TASK_OUTSIDE_SCHOOL_HOURS` (HTTP 400). Devuelve HTTP 201.

**JSON de entrada:**
```json
{"task_title":"Dibujar","task_date":"2026-11-10","task_index":0,"task_start_hour":"16:30:00","task_duration":20}
```

**Respuesta JSON (valores de ejemplo):**
```json
{"errorCode":0,"details":"successful","task_id":42,"task_title":"Dibujar","task_start_hour":"16:30:00","task_duration":20,"task_creator":"luis","task_finished":false,"alt_task_id_fk":null,"stud_usr_fk":"luis","task_index":0,"task_date":"2026-11-10"}
```

**JSON de entrada:**
```json
{"task_title":"Leer un cuento","task_date":"2026-11-10","task_index":0,"task_duration":20,"task_start_hour":"16:30:00","alt_task_id_fk":3}
```

**Respuesta JSON (valores de ejemplo):**
```json
{"errorCode":0,"details":"successful","task_id":41,"task_title":"Leer un cuento","task_start_hour":"16:30:00","task_duration":20,"task_creator":"ana","task_finished":false,"alt_task_id_fk":3,"stud_usr_fk":"luis","task_index":0,"task_date":"2026-11-10"}
```

### `PUT /student-tasks/{task_id}/alternative` — Cambiar tarea alternativa

Requiere JSON con `alt_task_id_fk`: un entero positivo para asociar una alternativa o `null` para quitarla. Solo permite modificar una tarea que haya creado el usuario autenticado y que esté asignada al menos a un alumno que siga asociado a él. La alternativa debe existir y no estar asignada a otra tarea. Devuelve los datos actualizados de la tarea. Si la alternativa está ocupada, devuelve `ALTERNATIVE_TASK_ALREADY_ASSIGNED` (HTTP 409); si la tarea principal no es accesible o no existe, devuelve `TASK_NOT_FOUND`.

**JSON de entrada:**
```json
{"alt_task_id_fk":3}
```

Para quitar la alternativa: `{"alt_task_id_fk": null}`.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","task_id":41,"task_title":"Leer un cuento","task_start_hour":"16:30:00","task_duration":20,"task_creator":"ana","task_finished":false,"alt_task_id_fk":3}
```

### `DELETE /student-tasks/students/{student_username}/{task_id}?task_date=AAAA-MM-DD&task_index=N` — Quitar tarea de la agenda del alumno

El `task_date` y `task_index` de la query identifican una asignación concreta de la tarea en la agenda del alumno. Comprueba que el alumno exista, que siga asociado al usuario y que exista una fila `stud_task` con la combinación completa de alumno, tarea, fecha e índice.

Si se conoce la hora de inicio, un tutor no puede quitar una tarea dentro del horario escolar y el personal no puede quitarla fuera del horario escolar (09:00 inclusive, 15:00 exclusive). Si la hora es `NULL`, se omite esa regla. La operación elimina únicamente la fila `stud_task`, por lo que deja de estar asignada a ese alumno, pero no borra la tarea de `Tasks` ni el registro genérico. Devuelve los identificadores de la asignación quitada.

**Entrada:** sin cuerpo. Ejemplo de ruta y query: `DELETE /student-tasks/students/luis/41?task_date=2026-11-10&task_index=0`.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","task_id":41,"stud_usr_fk":"luis","task_date":"2026-11-10","task_index":0}
```

### `DELETE /student-tasks/me/{task_id}?task_date=AAAA-MM-DD&task_index=N` — Eliminar una tarea propia

Requiere token de alumno y `stud_access_task_mod = true`. Comprueba que la asignación corresponda al alumno autenticado y que `Tasks.task_creator` también sea su username, para impedir que borre tareas de personal o tutores. La tarea debe tener una hora de inicio y su intervalo completo (hora más duración) debe quedar fuera de `[09:00, 15:00)`; si invade ese tramo o carece de hora, responde `STUDENT_TASK_OUTSIDE_SCHOOL_HOURS` (HTTP 400). Sin permiso de modificación responde `STUDENT_TASK_MODIFICATION_DENIED` (HTTP 403). Elimina la asignación indicada y, si la tarea propia ya no tiene ninguna otra asignación, elimina también su fila de `Tasks` y el `Generic_Task` asociado. Devuelve los identificadores de la asignación eliminada.

**Entrada:** sin cuerpo. Ejemplo: `DELETE /student-tasks/me/42?task_date=2026-11-10&task_index=0`.

## Clases

Prefijo `/classes`. Las clases se guardan en `Class`; `class_staff` asocia personal a clases y `class_stud` inscribe alumnos. El personal solo puede consultar o administrar una clase si está asignado a ella. Solo el administrador gestiona el catálogo de clases y asigna personal.

### `POST /classes` — Crear clase

Solo administrador. JSON `{ "class_name": "..." }`. El nombre se recorta, debe quedar no vacío y no superar 50 caracteres. Crea la clase; si ya existe, devuelve `CLASS_NAME_TAKEN` (HTTP 409). Responde HTTP 201.

**JSON de entrada:**
```json
{"class_name":"Primero A"}
```

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A"}
```

### `GET /classes` — Listar mis clases

Requiere token de staff. Devuelve las clases asignadas a ese miembro del personal y el número de alumnos inscritos en cada una. Otros roles reciben `CLASS_ACCESS_DENIED` (HTTP 403). Puede devolver una lista vacía.

**Entrada:** sin cuerpo. Cabecera Bearer.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","classes":[{"class_name":"Primero A","student_count":18}]}
```

### `GET /classes/{class_name}` — Consultar detalle de clase

Requiere token de staff asignado a esa clase. Devuelve el nombre, los alumnos inscritos (`username`, `full_name`) y el personal asignado (`username`, `full_name`). Una clase inexistente da `CLASS_NOT_FOUND`; una clase existente a la que ese staff no está asignado da `CLASS_ACCESS_DENIED`.

**Entrada:** sin cuerpo; cabecera Bearer y nombre de clase en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A","students":[{"username":"luis","full_name":"Luis Pérez"}],"staff":[{"username":"marta","full_name":"Marta Ruiz"}]}
```

### `PUT /classes/{current_class_name}` — Renombrar clase

Solo administrador. Recibe el nuevo nombre en `{ "class_name": "..." }`. Renombra la clase; las relaciones conservan el vínculo mediante la clave foránea. Si la clase original no existe, devuelve `CLASS_NOT_FOUND`; si el nombre nuevo ya existe, `CLASS_NAME_TAKEN`.

**JSON de entrada:**
```json
{"class_name":"Primero B"}
```

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero B"}
```

### `DELETE /classes/{class_name}` — Eliminar clase

Solo administrador. Elimina la clase y sus asociaciones de alumnos y personal (según las claves foráneas). No elimina las cuentas de alumnos ni de personal. Si no existe, devuelve `CLASS_NOT_FOUND`.

**Entrada:** sin cuerpo; nombre de clase en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A"}
```

### `POST /classes/{class_name}/staff/{staff_username}` — Asignar personal a clase

Solo administrador. Comprueba la clase y que la cuenta exista como miembro de `Staff`, y la añade a `class_staff`. La inserción repetida no crea duplicado y responde correctamente. Errores: `CLASS_NOT_FOUND` o `CLASS_STAFF_NOT_FOUND`.

**Entrada:** sin cuerpo; clase y username en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A","staff_username":"marta"}
```

### `POST /classes/{class_name}/students/{student_username}` — Inscribir alumno en clase

Requiere staff autenticado y asignado a la clase. Inscribe al alumno en `class_stud`. Comprueba que sea un alumno existente y que no esté inscrito en otra clase. Repetir la asignación a la misma clase no genera otra fila. Responde HTTP 201. Si ya está en otra clase, `STUDENT_ALREADY_IN_CLASS` (HTTP 409); si no existe como alumno, `TASK_STUDENT_NOT_FOUND`.

**Entrada:** sin cuerpo; clase y username en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A","student_username":"luis"}
```

### `DELETE /classes/{class_name}/students/{student_username}` — Retirar alumno de clase

Requiere staff asignado a la clase. Elimina solo la inscripción indicada. Si la relación no existe, devuelve `ASSOCIATION_NOT_FOUND`. No elimina al alumno ni sus tareas.

**Entrada:** sin cuerpo; clase y username en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A","student_username":"luis"}
```

### `POST /classes/{class_name}/tasks` — Crear tarea para toda la clase

Requiere staff asignado a la clase. Recibe los mismos campos de tarea que la creación individual: título, fecha, índice y duración positiva en minutos obligatorios; hora y alternativa opcionales. Si falta la duración o no es positiva, devuelve el error de validación `1005` (HTTP 422). Si se proporciona la hora, la suma de hora de inicio y duración debe dejar la tarea completa dentro del horario escolar: desde las 09:00 inclusive hasta las 15:00 inclusive como hora de fin. También valida título y alternativa como el endpoint individual.

La clase debe tener al menos un alumno inscrito; de lo contrario devuelve `CLASS_HAS_NO_STUDENTS`. Crea una sola tarea con `task_creator` igual al username del miembro del personal, la duración obligatoria, un registro `Generic_Task` y una fila `stud_task` por cada alumno inscrito, con la fecha e índice solicitados. La operación es transaccional y responde HTTP 201 con la lista de alumnos incluidos.

**JSON de entrada:**
```json
{"task_title":"Lectura","task_date":"2026-11-10","task_index":0,"task_duration":20,"task_start_hour":"10:00:00","alt_task_id_fk":3}
```

**Respuesta JSON (alumnos y valores de ejemplo):**
```json
{"errorCode":0,"details":"successful","task_id":41,"task_title":"Lectura","task_start_hour":"10:00:00","task_duration":20,"task_creator":"marta","task_finished":false,"alt_task_id_fk":3,"class_name":"Primero A","students":["luis","sofia"],"task_index":0,"task_date":"2026-11-10"}
```

## Errores y lectura del estado

Los códigos y textos públicos se mantienen en `proyectFastAPI/errors.py`. En general, un código 4xx representa credenciales/permisos/entidades/datos no válidos; un 5xx representa fallo interno. No se deben interpretar errores de PostgreSQL directamente desde el frontend: la API traduce errores conocidos al catálogo y oculta los detalles internos.

Las listas y consultas de asociaciones, clases y tareas se generan desde las relaciones actuales de la base de datos. Las rutas de asociación y de clase no incluyen confirmaciones de interfaz; cualquier diálogo de confirmación antes de una operación destructiva debe implementarse en el cliente antes de enviar la petición.

## Interacciones entre módulos

1. **Identidad y especialización:** `users` contiene los campos comunes (`username`, `full_name`, contraseña y token); `Admn`, `Staff`, `Student` y `Parents` determinan el rol y mantienen campos propios. Login y autorización unen la cuenta común con la especialización del rol.
2. **Sesiones y cambios de usuario:** las rutas protegidas consultan el token guardado en `users`. Editar contraseña o username revoca ese token. Los roles son inmutables después de crear la cuenta; el login siguiente genera un token nuevo.
3. **Permisos y asociaciones:** `par_stud` y `staff_stud` son la fuente efectiva para las rutas de tareas individuales. Las consultas de alumnos asociados y las autorizaciones usan estas relaciones actuales.
4. **Agenda:** `Tasks` contiene los datos comunes de tarea, `Generic_Task` su especialización actual y `stud_task` enlaza tarea, alumno, fecha e índice. Eliminar una asignación individual solo borra `stud_task`; una tarea de clase crea varias asignaciones a partir de `class_stud`.
5. **Clases y asociaciones alumno-persona:** la pertenencia a clase (`class_stud`) es independiente de la relación tutor/alumno (`par_stud`) y personal/alumno (`staff_stud`). Añadir o quitar a un alumno de una clase no crea ni elimina sus asociaciones personales; borrar una clase tampoco borra cuentas.
6. **Tareas alternativas:** `alt_task_id_fk` referencia `Alt_Tasks`; el backend impide usar la misma alternativa en más de una tarea. Cambiar username de un usuario actualiza la autoría guardada en `Tasks` y `Alt_Tasks`.

## Archivos de implementación

- Registro de rutas y manejadores globales: `src/backend/proyectFastAPI/main.py`.
- Sesiones: `auth/auth_backend.py`, `auth/auth_db.py`.
- Usuarios: `gestion_usuarios/users_mng_backend.py`, `gestion_usuarios/users_mng_db.py`.
- Asociaciones de alumnos: `asociaciones_alumnos/studs_links_backend.py`, `asociaciones_alumnos/studs_links_db.py`.
- Tareas individuales: `tareas alumnos/studs_tasks_backend.py`, `tareas alumnos/studs_tasks_db.py`.
- Clases y tareas de clase: `clases/clases_backend.py`, `clases/clases_db.py`.
- Errores públicos: `errors.py`.
