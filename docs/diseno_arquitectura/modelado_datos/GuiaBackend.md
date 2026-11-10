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

Recibe JSON con `username`, `password` y `role`. Usuario y contraseña deben ser cadenas no vacías; el username no puede contener espacios y no puede superar 50 caracteres. La contraseña no puede superar 72 bytes UTF-8. El rol debe ser uno de los cuatro roles admitidos y no se admiten propiedades JSON adicionales.

El servidor busca la cuenta en `users` junto a la tabla hija correspondiente al rol y compara la contraseña recibida con el hash bcrypt almacenado. Si coincide, genera un token aleatorio, guarda su hash SHA-256 en `users.token` y confirma el cambio. El token anterior de ese usuario deja de servir. La respuesta incluye `access_token`, `token_type: "bearer"` y la identidad `{username, role}`.

Una contraseña incorrecta o una combinación de usuario/rol que no corresponde devuelve `INVALID_CREDENTIALS` (HTTP 401). El endpoint limita `role` a los cuatro valores admitidos; un valor distinto falla la validación de FastAPI y devuelve `INVALID_REQUEST` (HTTP 422). Un fallo de infraestructura de autenticación devuelve `LOGIN_FAILED` (HTTP 500).

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

En este módulo, “avatar” significa la foto de perfil del alumno. Aunque la tabla `Student` la referencia como `avatar_id_fk`, cada alumno debe tener siempre una foto asignada.

### `POST /users` — Crear usuario

Solo administrador. Recibe un objeto JSON discriminado por `role`.

Campos comunes obligatorios: `username`, `full_name` y `password`. El username se recorta y no puede contener espacios; el nombre completo se recorta, debe contener alguna letra y no puede contener números. La contraseña no puede superar 72 bytes UTF-8 (límite de bcrypt). No se aceptan campos no definidos.

Para `role: "student"` también son obligatorios todos los campos de accesibilidad: `stud_access_main_col`, `stud_access_sec_col`, `stud_access_ntasks_visible`, `stud_access_pictograms`, `stud_access_contrast`, `stud_access_fontsize`, `stud_access_filters`, `stud_access_ndays_visible`, `stud_access_prof_mod`, `stud_access_timebar`, `stud_access_talkback`, `stud_access_profile_mod` y `stud_access_task_mod`. Los colores deben ser hexadecimales de 3 o 6 dígitos (por ejemplo, `#abc` o `#aabbcc`). Las cantidades visibles deben ser enteros JSON no negativos y el tamaño de fuente un entero JSON positivo. Los campos booleanos requieren `true` o `false` de JSON.

Para `admin`, `staff` y `parent`, también es obligatorio `email`, que debe tener formato válido y no exceder 254 caracteres.

La operación inserta la fila común en `users` (incluido el hash bcrypt de la contraseña y `full_name`) y después la especialización del rol en `Admn`, `Staff`, `Student` o `Parents`, con los datos de email o accesibilidad que correspondan. Al crear un alumno, también crea y asigna una foto de perfil SVG predeterminada en `Avatar`; el alumno nunca se crea con `avatar_id_fk` nulo. Todas las inserciones se confirman conjuntamente. El username es único en la tabla común, por lo que no puede repetirse entre roles. Según el conflicto, se devuelve `USERNAME_TAKEN` o `EMAIL_TAKEN` (HTTP 409); otros errores de creación usan `USER_CREATE_FAILED` (HTTP 500).

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

El parámetro `role` se valida contra los cuatro roles admitidos; un valor distinto devuelve `INVALID_REQUEST` (HTTP 422). Los fallos de consulta devuelven `USER_LIST_FAILED` (HTTP 500).

**Entrada:** sin cuerpo. Filtro opcional en query, por ejemplo `?role=student`.

**Respuesta JSON (ejemplo abreviado):**
```json
{"errorCode":0,"details":"successful","users":[{"username":"ana","full_name":"Ana López","role":"parent","email":"ana@example.com"},{"username":"luis","full_name":"Luis Pérez","role":"student","stud_access_main_col":"#ffffff","stud_access_sec_col":"#000000","stud_access_ntasks_visible":5,"stud_access_pictograms":true,"stud_access_contrast":false,"stud_access_fontsize":18,"stud_access_filters":true,"stud_access_ndays_visible":7,"stud_access_prof_mod":false,"stud_access_timebar":true,"stud_access_talkback":false,"stud_access_profile_mod":true,"stud_access_task_mod":true}]}
```

### `GET /users/{role}/{username}` — Consultar una cuenta concreta

Solo administrador. Busca una cuenta por username dentro del rol indicado y devuelve sus datos de perfil: `username`, `full_name`, `role`, email cuando corresponda y preferencias de accesibilidad para estudiantes. No devuelve contraseña ni token. Si la cuenta no existe en ese rol, responde `USER_NOT_FOUND` (HTTP 404); si falla la consulta, `USER_LOOKUP_FAILED` (HTTP 500).

**Entrada:** sin cuerpo. Ejemplo: `GET /users/parent/ana` con Bearer de administrador.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","username":"ana","full_name":"Ana López","email":"ana@example.com","role":"parent"}
```

### `PUT /users/{role}/{username}` — Editar perfil o datos de usuario

Requiere autenticación. Un administrador puede editar cualquier cuenta. Un `parent`, `staff` o `student` solo puede editar su propio perfil y no puede enviar `username`, `full_name` ni `role`. Para estudiantes, además se comprueba que `stud_access_profile_mod` sea verdadero; si es falso, se rechaza la edición propia. Ningún usuario puede cambiar el rol de una cuenta: un administrador que envíe un `role` distinto del actual recibe `ROLE_CHANGE_DENIED` (HTTP 403); un usuario no administrador que envíe `role` recibe `PROFILE_UPDATE_DENIED` (HTTP 403).

El JSON acepta campos opcionales: `username`, `role`, `full_name`, `password`, `email` y campos `stud_access_*`. No se aceptan propiedades extra. Debe haber al menos un campo que modificar. El username y el nombre completo aplican validaciones iguales a las de creación; la contraseña está limitada a 72 bytes. Los valores numéricos y booleanos de accesibilidad deben usar sus tipos JSON correspondientes, y los colores deben seguir el formato hexadecimal indicado en creación.

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

### `PUT /users/students/{student_username}/avatar` — Actualizar foto de perfil de alumno

Solo administrador. Recibe `multipart/form-data` con el archivo en el campo `file` y el username del alumno en la ruta. Admite PNG, JPEG y WebP de hasta 5 MB; el backend comprueba la firma y estructura básica del formato, y rechaza formatos no admitidos o archivos demasiado grandes con `AVATAR_INVALID_IMAGE` (HTTP 422) o `AVATAR_TOO_LARGE` (HTTP 413). Si el alumno no existe, devuelve `USER_NOT_FOUND`. El permiso `stud_access_profile_mod` no limita al administrador. El archivo es obligatorio, así que esta operación siempre reemplaza la foto por otra válida y nunca la deja nula.

La imagen se guarda en `Avatar.avatar_bin` y su clave se vincula a `Student.avatar_id_fk` en una transacción. Al reemplazar una foto anterior, el backend la elimina si ya no está vinculada a ningún alumno. La columna `avatar_id_fk` es obligatoria y la clave foránea impide borrar una imagen mientras un alumno la use. La respuesta JSON incluye `avatar_id`, `media_type` y `avatar_url`.

La ruta devuelta en `avatar_url` permite recargar la imagen; evita caché con `Cache-Control: no-store`.

**Entrada:** `PUT /users/students/luis/avatar`, cabecera `Authorization: Bearer <token>` de administrador y `multipart/form-data`, campo `file` con los bytes de la imagen; no es JSON.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","avatar_id":12,"media_type":"image/png","avatar_url":"/users/students/luis/avatar-image"}
```

### `GET /users/students/me/avatar` — Obtener mi avatar

Requiere token de alumno y devuelve directamente la imagen con su tipo MIME. Si el alumno todavía no tiene una foto válida, devuelve una silueta SVG predeterminada para que el perfil siempre pueda mostrar una imagen. La respuesta usa `Cache-Control: no-store` para que una foto recién actualizada no se quede en caché.

**Entrada:** sin cuerpo. Cabecera: `Authorization: Bearer <token>`.

**Respuesta:** contenido binario de imagen (PNG, JPEG o WebP), o SVG predeterminado; no devuelve JSON. El encabezado `Content-Type` indica el formato y `Cache-Control: no-store` evita caché.

### `GET /users/students/{student_username}/avatar-image` — Obtener avatar de alumno de una clase

Puede consultarse sin token para mostrar la selección de alumno antes del login, siempre que el alumno esté matriculado en alguna clase. El personal solo puede consultar el avatar de alumnos que estén matriculados en alguna de sus clases; el administrador puede consultar el de cualquier alumno. Devuelve la imagen almacenada o el SVG predeterminado si el alumno no tiene avatar. La respuesta usa `Cache-Control: no-store`. Sin autorización para consultar al alumno, devuelve `ASSOCIATION_ACCESS_DENIED` (HTTP 403).

**Entrada:** sin cuerpo; username en la ruta. La cabecera Bearer es opcional para alumnos matriculados.

**Respuesta:** contenido binario de imagen (PNG, JPEG o WebP), o SVG predeterminado; no devuelve JSON.

## Asociaciones alumno–tutor/personal

Todas las rutas usan el prefijo `/student-links`. La relación alumno-tutor se almacena directamente en `par_stud`. La relación de un alumno con el personal se deriva de `class_stud` y `class_staff`: el alumno y los miembros del personal que imparten su clase quedan relacionados sin una tabla de enlace directa. No se crean ni borran cuentas desde este módulo.

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

### `GET /student-links/students/{student_username}` — Consultar tutores y personal de un alumno

Solo administrador. Devuelve dos listas actuales: `parents` y `staff`. Cada entrada incluye username, full name y email. Los padres salen de `par_stud`; el personal se obtiene de la clase a la que pertenece el alumno y sus filas en `class_staff`. Si el alumno aún no tiene clase, `staff` será una lista vacía. Si no existe el alumno, devuelve `ASSOCIATED_ENTITY_NOT_FOUND` (HTTP 404).

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

Staff consulta su propio listado; admin puede consultar cualquier miembro del personal. Devuelve los alumnos inscritos en cualquiera de las clases que imparte ese miembro del personal, con `username` y `full_name`, sin duplicados. Un resultado vacío es `students: []`.

**Entrada:** sin cuerpo; cabecera Bearer y username del miembro del personal en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","staff_username":"marta","students":[{"username":"luis","full_name":"Luis Pérez"}]}
```

Las relaciones vigentes también controlan las tareas individuales. El tutor debe seguir asociado al alumno mediante `par_stud`; el personal debe compartir con el alumno una clase vigente, comprobada mediante `class_staff` y `class_stud`. Al retirar al alumno de la clase o al personal de ella, desaparece ese acceso derivado. El cambio no afecta a relaciones con padres ni a otras clases.

## Tareas individuales de alumnos

Prefijo `/student-tasks`. El personal (`staff`) puede crear tareas para alumnos inscritos en alguna clase que imparte; los tutores (`parent`) pueden hacerlo para alumnos enlazados mediante `par_stud`. El alumno puede crear y eliminar solo sus propias tareas mediante las rutas `/me`, si `stud_access_task_mod` está activado. El administrador no está autorizado por este router. Las rutas de edición de tareas alternativas siguen reservadas a `staff` y `parent`; también validan la relación actual con al menos un alumno asignado a la tarea.

### `GET /student-tasks/students/{student_username}?task_date=AAAA-MM-DD` — Consultar tareas de un alumno por día

Requiere personal asignado a una clase compartida con el alumno o tutor asociado mediante `par_stud`. Devuelve las tareas de la agenda de ese alumno para la fecha indicada, ordenadas según `task_index`; incluye también `class_name_fk` para identificar las asignaciones que proceden de una clase. Si el alumno no existe, devuelve `TASK_STUDENT_NOT_FOUND`; si el usuario autenticado no está asociado a él, devuelve `TASK_STUDENT_NOT_ASSOCIATED`.

**Entrada:** sin cuerpo. Ejemplo: `GET /student-tasks/students/luis?task_date=2026-11-10`.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","stud_usr_fk":"luis","task_date":"2026-11-10","tasks":[{"task_id":41,"task_title":"Leer un cuento","task_start_hour":"10:00:00","task_duration":20,"task_creator":"marta","task_finished":false,"alt_task_id_fk":null,"task_date":"2026-11-10","task_index":0,"class_name_fk":"Primero A"}]}
```

### `GET /student-tasks/me?task_date=AAAA-MM-DD` — Consultar tareas propias por día

Requiere token de alumno. Todos los alumnos pueden consultar su agenda, independientemente del permiso `stud_access_task_mod`, que solo controla la creación o modificación de sus propias tareas. Devuelve las tareas de la agenda propia para esa fecha, en orden de `task_index`. Si no hay tareas para ese día, `tasks` es una lista vacía.

**Entrada:** sin cuerpo. Ejemplo: `GET /student-tasks/me?task_date=2026-11-10`.

**Respuesta JSON:** usa el mismo formato de la consulta de tareas de un alumno.

### `POST /student-tasks/students/{student_username}` — Crear tarea en la agenda de un alumno

Responde HTTP 201. El JSON requiere `task_title`, `task_date` y `task_duration`. La fecha es obligatoria, puede ser futura y no se limita al día actual. El título se recorta y debe contener entre 1 y 100 caracteres; la duración es un entero positivo expresado en minutos. Son opcionales `task_start_hour` (hora local sin zona) y `alt_task_id_fk` (entero positivo). `task_index` no se envía: el backend lo calcula para la agenda del alumno. Si falta la duración, es `null` o no es positiva, FastAPI rechaza la petición con error de validación `1005` (HTTP 422). No admite propiedades adicionales.

El alumno debe existir y el usuario autenticado debe estar asociado a él según su rol. El personal debe indicar `task_start_hour`; el intervalo completo `[hora de inicio, hora de inicio + duración)` debe quedar entre las 09:00 y las 15:00. `parent` puede indicar una hora, pero su intervalo completo no puede solaparse con `[09:00, 15:00)`. La franja escolar se aplica todos los días; por ahora tampoco se admiten tareas de tutor entre las 09:00 y las 15:00 en fin de semana. Los festivos no se distinguen hasta disponer de un calendario del centro. Las tareas de `parent` sin hora se permiten y se colocan después de todas las tareas con hora de esa fecha. En los límites, terminar exactamente a las 09:00 o empezar exactamente a las 15:00 no se considera solapamiento para tutores; el personal sí puede terminar exactamente a las 15:00. Si se indica alternativa, esta debe existir y no estar ya enlazada a otra tarea.

La operación inserta en `Tasks` con `task_creator` igual al username del creador, `task_duration` positiva y `task_finished = false`, añade el subtipo `Generic_Task` y crea la asignación `stud_task` con alumno, tarea, índice calculado y fecha. Las tareas con hora se insertan según su hora respecto a las tareas de esa fecha; las tareas sin hora de `parent` se colocan al final, por lo que su índice queda después de la última tarea de `staff`. Las tareas de `parent` con hora anterior a las 09:00 quedan antes de las de `staff`, y las posteriores a las 15:00 quedan después. Si se inserta una tarea antes de otras, sus índices se desplazan para abrirle sitio. La agenda del alumno se bloquea durante el cálculo para serializar inserciones concurrentes. Todo se confirma en una transacción. La respuesta incluye el índice asignado. El esquema también impone `NOT NULL` y `CHECK (> 0)` en `Tasks.task_duration` y `Alt_Tasks.alt_task_duration`; las alternativas ya almacenadas deben cumplirlo aunque esta API solo las asocie.

`CreacionTablas.sqlscript` recrea el esquema completo: elimina primero las tablas existentes y después vuelve a crearlas. Es destructivo y borra todos los datos de esas tablas; se debe ejecutar solo cuando se quiera reiniciar la base de datos.

La hora de inicio es opcional para `parent` y `student`; si se omite, la tarea se coloca al final de la agenda. `staff` debe indicar la hora de inicio y su tarea debe quedar dentro del horario escolar. Tanto `parent` como `student` pueden indicar una hora fuera del horario escolar, validándose el intervalo completo.

**JSON de entrada:**
```json
{"task_title":"Leer un cuento","task_date":"2026-11-10","task_duration":20,"task_start_hour":"16:30:00","alt_task_id_fk":3}
```

**Respuesta JSON (valores de ejemplo):**
```json
{"errorCode":0,"details":"successful","task_id":41,"task_title":"Leer un cuento","task_start_hour":"16:30:00","task_duration":20,"task_creator":"ana","task_finished":false,"alt_task_id_fk":3,"stud_usr_fk":"luis","task_index":0,"task_date":"2026-11-10"}
```

### `POST /student-tasks/me` — Crear una tarea propia

Requiere token de alumno. El JSON acepta título, fecha, duración positiva en minutos y, opcionalmente, hora de inicio y alternativa. Si se indica hora, el intervalo completo no puede solaparse con `[09:00, 15:00)`; si no se indica, la tarea se trata como tarea solo de duración y se coloca al final de la agenda, después de las tareas de `staff`. Una tarea con hora antes de las 09:00 queda antes de las tareas de `staff`; una tarea posterior a las 15:00 queda después. El alumno debe tener `stud_access_task_mod = true`; si no, responde `STUDENT_TASK_MODIFICATION_DENIED` (HTTP 403). Se crea una tarea `Generic_Task` con `task_creator` igual al username del alumno y una asignación `stud_task` para ese mismo alumno. Devuelve HTTP 201.

**JSON de entrada:**
```json
{"task_title":"Dibujar","task_date":"2026-11-10","task_start_hour":"16:30:00","task_duration":20}
```

**Respuesta JSON (valores de ejemplo):**
```json
{"errorCode":0,"details":"successful","task_id":42,"task_title":"Dibujar","task_start_hour":"16:30:00","task_duration":20,"task_creator":"luis","task_finished":false,"alt_task_id_fk":null,"stud_usr_fk":"luis","task_index":0,"task_date":"2026-11-10"}
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

### `DELETE /student-tasks/students/{student_username}/{task_id}?task_date=AAAA-MM-DD` — Quitar tarea de la agenda del alumno

El `task_date` de la query identifica la fecha de la asignación. El índice ya no se envía, porque puede cambiar al insertar tareas anteriores en la agenda. El backend localiza el índice vigente por alumno, tarea y fecha. Comprueba que el alumno exista, que siga asociado al usuario y que exista una fila `stud_task` correspondiente.

Si se conoce la hora de inicio, un tutor no puede quitar una tarea dentro del horario escolar y el personal no puede quitarla fuera del horario escolar (09:00 inclusive, 15:00 exclusive). Si la hora es `NULL`, se omite esa regla. La operación elimina únicamente la fila `stud_task`, por lo que deja de estar asignada a ese alumno, pero no borra la tarea de `Tasks` ni el registro genérico. Devuelve los identificadores de la asignación quitada.

**Entrada:** sin cuerpo. Ejemplo de ruta y query: `DELETE /student-tasks/students/luis/41?task_date=2026-11-10`.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","task_id":41,"stud_usr_fk":"luis","task_date":"2026-11-10","task_index":0}
```

### `DELETE /student-tasks/me/{task_id}?task_date=AAAA-MM-DD` — Eliminar una tarea propia

Requiere token de alumno y `stud_access_task_mod = true`. Comprueba que la asignación corresponda al alumno autenticado y que `Tasks.task_creator` también sea su username, para impedir que borre tareas de personal o tutores. Si la tarea tiene hora, su intervalo completo debe quedar fuera de `[09:00, 15:00)`; una tarea solo de duración sin hora también se puede eliminar. Si el intervalo se solapa con el horario escolar, responde `STUDENT_TASK_OUTSIDE_SCHOOL_HOURS` (HTTP 400). Sin permiso de modificación responde `STUDENT_TASK_MODIFICATION_DENIED` (HTTP 403). Elimina la asignación indicada y, si la tarea propia ya no tiene ninguna otra asignación, elimina también su fila de `Tasks` y el `Generic_Task` asociado. Devuelve los identificadores de la asignación eliminada.

**Entrada:** sin cuerpo. Ejemplo: `DELETE /student-tasks/me/42?task_date=2026-11-10`.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","task_id":42,"stud_usr_fk":"luis","task_date":"2026-11-10","task_index":0}
```

## Clases

Prefijo `/classes`. Las clases se guardan en `Class`; `class_staff` asocia personal a clases, `class_stud` inscribe alumnos y `class_task` vincula tareas grupales a una clase. `stud_task.class_name_fk` marca las asignaciones a alumnos que proceden de una clase; las tareas individuales dejan ese campo nulo. El personal solo puede consultar o administrar una clase si está asignado a ella. El administrador puede consultar todas las clases y sus detalles, y gestiona el catálogo y la asignación de personal.

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

### `GET /classes` — Listar clases

La consulta es pública para permitir la selección de clase antes del login. Sin token, devuelve únicamente el campo `class_name` para cada clase, sin otros datos. Con token, el administrador recibe todas las clases y el personal únicamente las clases que tiene asignadas; otros roles reciben `CLASS_ACCESS_DENIED` (HTTP 403). Cada clase autenticada incluye `class_name`, `student_count` y `students`; cada alumno incluye `username`, `full_name` y `avatar_url`. El endpoint de avatar permite acceso anónimo solo a alumnos matriculados en alguna clase. Si el usuario autenticado no tiene clases visibles, `classes` es una lista vacía; si una clase no tiene alumnos, `students` es una lista vacía y `student_count` vale 0.

**Entrada:** sin cuerpo; cabecera Bearer opcional.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","classes":[{"class_name":"Primero A"},{"class_name":"Segundo B"}]}
```

### `GET /classes/{class_name}` — Consultar detalle de clase

Puede consultarse sin token para mostrar los alumnos de la clase elegida antes del login. El administrador y las solicitudes anónimas pueden consultar cualquier clase; el personal autenticado solo puede consultar una clase a la que esté asignado. Devuelve el nombre y los alumnos inscritos (`username`, `full_name`, `avatar_url`); no devuelve el personal asignado. Una clase inexistente da `CLASS_NOT_FOUND`; una clase existente a la que ese staff no está asignado da `CLASS_ACCESS_DENIED`. `students` puede estar vacía.

**Entrada:** sin cuerpo; cabecera Bearer opcional y nombre de clase en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A","students":[{"username":"luis","full_name":"Luis Pérez","avatar_url":"/users/students/luis/avatar-image"}]}
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

Solo administrador. Elimina la clase, sus matrículas y asignaciones de tareas grupales. Las tareas vinculadas únicamente a esa clase se eliminan; si una tarea también conserva asignaciones directas a alumnos, esas asignaciones y la tarea se mantienen. No elimina las cuentas de alumnos ni de personal. Si no existe, devuelve `CLASS_NOT_FOUND`.

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

### `DELETE /classes/{class_name}/staff/{staff_username}` — Retirar personal de clase

Solo administrador. Elimina la asignación correspondiente en `class_staff`; no elimina la cuenta del personal, la clase, sus alumnos ni sus tareas. Al retirar la asignación, esa persona deja de acceder a la clase y a los alumnos que se le asociaban por compartirla. Si la clase no existe, devuelve `CLASS_NOT_FOUND`; si el personal no está asignado a ella, devuelve `CLASS_STAFF_NOT_FOUND` (HTTP 404).

**Entrada:** sin cuerpo; clase y username en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A","staff_username":"marta"}
```

### `POST /classes/{class_name}/students/{student_username}` — Inscribir alumno en clase

Requiere staff autenticado y asignado a la clase. Inscribe al alumno en `class_stud`. Comprueba que sea un alumno existente y que no esté inscrito en otra clase. Al matricularlo, también le asigna las tareas que ya estén vinculadas a esa clase en `class_task`, calculando el índice de cada una en su agenda. Repetir la asignación a la misma clase no duplica la matrícula ni las tareas. Responde HTTP 201. Si ya está en otra clase, `STUDENT_ALREADY_IN_CLASS` (HTTP 409); si no existe como alumno, `TASK_STUDENT_NOT_FOUND`.

**Entrada:** sin cuerpo; clase y username en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A","student_username":"luis","class_tasks_assigned":2}
```

### `DELETE /classes/{class_name}/students/{student_username}` — Retirar alumno de clase

Requiere staff asignado a la clase. En una transacción, elimina las asignaciones `stud_task` marcadas como procedentes de esa clase y luego la inscripción `class_stud`. Las tareas individuales del alumno, incluidas las creadas por el mismo profesor, se conservan. La tarea grupal sigue vinculada a la clase y seguirá disponible para los demás alumnos matriculados. Si la relación no existe, devuelve `ASSOCIATION_NOT_FOUND`.

**Entrada:** sin cuerpo; clase y username en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A","student_username":"luis","class_task_assignments_removed":2}
```

### `POST /classes/{class_name}/tasks` — Crear tarea para toda la clase

Requiere staff asignado a la clase. Recibe título, fecha, hora de inicio y duración positiva en minutos; la alternativa es opcional. La fecha es obligatoria y puede ser futura. Si falta la duración o la hora, o la tarea no queda íntegramente entre las 09:00 y las 15:00, se rechaza; también valida el título y que la alternativa exista y no esté ya asignada. `task_index` no se envía: se calcula por separado para cada alumno según sus tareas de esa fecha. La respuesta incluye `task_indexes`, un mapa de username a índice asignado.

La clase debe tener al menos un alumno inscrito; de lo contrario devuelve `CLASS_HAS_NO_STUDENTS`. Crea una tarea con `task_creator` igual al username del miembro del personal, un registro `Generic_Task`, una fila `class_task` que la vincula a la clase y una fila `stud_task` por cada alumno inscrito. Cada fila `stud_task` guarda también el origen en `class_name_fk`. Calcula un índice individual para cada agenda y fecha. La operación es transaccional y responde HTTP 201 con la lista de alumnos incluidos y sus índices. La tarea existe como tarea de clase aunque más adelante se retire a todos los alumnos.

**JSON de entrada:**
```json
{"task_title":"Lectura","task_date":"2026-11-10","task_duration":20,"task_start_hour":"10:00:00","alt_task_id_fk":3}
```

**Respuesta JSON (alumnos y valores de ejemplo):**
```json
{"errorCode":0,"details":"successful","task_id":41,"task_title":"Lectura","task_start_hour":"10:00:00","task_duration":20,"task_creator":"marta","task_finished":false,"alt_task_id_fk":3,"class_name":"Primero A","students":["luis","sofia"],"task_indexes":{"luis":2,"sofia":0},"task_date":"2026-11-10"}
```

### `GET /classes/{class_name}/tasks` — Consultar tareas de una clase

Requiere staff autenticado y asignado a la clase. Devuelve las tareas enlazadas mediante `class_task`, su fecha y los alumnos que aún tienen una asignación de esa tarea originada en la clase. No incluye tareas individuales creadas por el personal para alumnos concretos.

**Entrada:** sin cuerpo; nombre de clase en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A","tasks":[{"task_id":41,"task_title":"Lectura","task_start_hour":"10:00:00","task_duration":20,"task_creator":"marta","task_finished":false,"alt_task_id_fk":3,"task_date":"2026-11-10","students":["luis","sofia"]}]}
```

### `PUT /classes/{class_name}/tasks/{task_id}` — Editar tarea de clase

Requiere staff asignado a la clase y que la tarea esté vinculada a ella. Recibe el mismo JSON que la creación de tarea grupal. Actualiza los datos comunes de `Tasks` y la fecha de `class_task`, retira las asignaciones originadas por esa clase y las vuelve a crear para los alumnos actualmente matriculados, con índices calculados para sus agendas. Si la misma tarea conserva asignaciones individuales, estas no se borran, aunque sus datos comunes sí reflejan la edición. Usa los errores `TASK_NOT_FOUND`, `ALTERNATIVE_TASK_NOT_FOUND`, `ALTERNATIVE_TASK_ALREADY_ASSIGNED` y `STAFF_TASK_OUTSIDE_SCHOOL_HOURS` cuando corresponda.

**JSON de entrada:**
```json
{"task_title":"Lectura comprensiva","task_date":"2026-11-11","task_duration":25,"task_start_hour":"10:00:00","alt_task_id_fk":3}
```

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","task_id":41,"task_title":"Lectura comprensiva","task_start_hour":"10:00:00","task_duration":25,"task_creator":"marta","task_finished":false,"alt_task_id_fk":3,"class_name":"Primero A","task_date":"2026-11-11","task_indexes":{"luis":2,"sofia":0}}
```

### `DELETE /classes/{class_name}/tasks/{task_id}` — Desasignar tarea de una clase

Requiere staff asignado a la clase. Elimina la relación `class_task` y las asignaciones `stud_task` cuyo origen sea esa clase. Si la tarea no tiene ya asignaciones directas ni otros vínculos de clase, también elimina la tarea común y su subtipo. Una asignación directa del mismo `task_id` a un alumno se conserva. Si la relación clase-tarea no existe, devuelve `TASK_NOT_FOUND`.

**Entrada:** sin cuerpo; clase y `task_id` en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A","task_id":41,"student_assignments_removed":2}
```

## Errores y lectura del estado

Los códigos y textos públicos se mantienen en `proyectFastAPI/errors.py`. En general, un código 4xx representa credenciales/permisos/entidades/datos no válidos; un 5xx representa fallo interno. No se deben interpretar errores de PostgreSQL directamente desde el frontend: la API traduce errores conocidos al catálogo y oculta los detalles internos.

Las listas y consultas de asociaciones, clases y tareas se generan desde las relaciones actuales de la base de datos. Las rutas de asociación y de clase no incluyen confirmaciones de interfaz; cualquier diálogo de confirmación antes de una operación destructiva debe implementarse en el cliente antes de enviar la petición.

## Interacciones entre módulos

1. **Identidad y especialización:** `users` contiene los campos comunes (`username`, `full_name`, contraseña y token); `Admn`, `Staff`, `Student` y `Parents` determinan el rol y mantienen campos propios. Login y autorización unen la cuenta común con la especialización del rol.
2. **Sesiones y cambios de usuario:** las rutas protegidas consultan el token guardado en `users`. Editar contraseña o username revoca ese token. Los roles son inmutables después de crear la cuenta; el login siguiente genera un token nuevo.
3. **Permisos y asociaciones:** `par_stud` es la fuente de la relación directa tutor-alumno. El acceso del personal a los alumnos se deriva por la cadena `class_staff` → `class_stud`. Las consultas de asociaciones y las autorizaciones de tareas usan esas relaciones vigentes.
4. **Agenda:** `Tasks` contiene los datos comunes, `Generic_Task` su especialización y `class_task` vincula la tarea a una clase y fecha. `stud_task` enlaza tareas con alumnos, fecha e índice; `class_name_fk` identifica las filas que proceden de una clase y queda nulo para asignaciones individuales. Retirar a un alumno de una clase elimina solo sus filas de agenda originadas en esa clase. Si se borra una tarea grupal, se conservan sus filas de asignación individual; las tareas sin ningún vínculo se eliminan junto a su subtipo.
5. **Clases y asociaciones alumno-persona:** cada alumno puede estar en una clase como máximo; un profesor puede impartir varias clases y cada clase puede tener varios profesores. Por eso todo el personal de una clase comparte acceso derivado a sus alumnos. La relación tutor-alumno permanece separada en `par_stud`. Cambiar las asignaciones de clase modifica el acceso derivado del personal, pero no las cuentas ni las relaciones con padres.
6. **Tareas alternativas:** `alt_task_id_fk` referencia `Alt_Tasks`; el backend impide usar la misma alternativa en más de una tarea. Cambiar username de un usuario actualiza la autoría guardada en `Tasks` y `Alt_Tasks`.

## Archivos de implementación

- Registro de rutas y manejadores globales: `src/backend/proyectFastAPI/main.py`.
- Sesiones: `auth/auth_backend.py`, `auth/auth_db.py`.
- Usuarios: `gestion_usuarios/users_mng_backend.py`, `gestion_usuarios/users_mng_db.py`.
- Asociaciones de alumnos: `asociaciones_alumnos/studs_links_backend.py`, `asociaciones_alumnos/studs_links_db.py`.
- Tareas individuales: `tareas alumnos/studs_tasks_backend.py`, `tareas alumnos/studs_tasks_db.py`.
- Clases y tareas de clase: `clases/clases_backend.py`, `clases/clases_db.py`.
- Errores públicos: `errors.py`.
