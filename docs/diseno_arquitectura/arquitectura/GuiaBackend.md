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

El servidor busca la cuenta en `users` junto a la tabla hija correspondiente al rol y compara la contraseña recibida con el hash bcrypt almacenado. Para alumnos con `Student.stud_access_img_pwd = true`, `password` debe concatenar de 4 a 8 IDs distintos, en el orden elegido, sin comas ni separadores. Cada ID se representa con cinco dígitos, completando con ceros a la izquierda: los IDs `12`, `4`, `19` y `7` se envían como `00012000040001900007`. El backend valida los bloques y compara el hash de la cadena en `users.password`; los binarios e IDs no se guardan como credencial del usuario. Para los demás casos se usa la contraseña de texto existente. Si coincide, genera un token aleatorio, guarda su hash SHA-256 en `users.token` y confirma el cambio. El token anterior de ese usuario deja de servir. La respuesta incluye `access_token`, `token_type: "bearer"` y la identidad `{username, role}`.

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

### `GET /auth/password-images` — Consultar el catálogo de imágenes de contraseña

No requiere sesión para que el formulario pueda mostrar imágenes antes de iniciar sesión. Devuelve todas las imágenes ordenadas por `pwd_id`, incluyendo `pwd_active`. `pwd_bin` se entrega en Base64; el cliente debe decodificarlo como bytes de imagen. Las imágenes inactivas pueden seguir apareciendo en el acceso para que las credenciales antiguas sigan siendo utilizables, pero no pueden elegirse al crear o cambiar una contraseña gráfica. Para formar `password`, el cliente completa cada `pwd_id` a cinco dígitos con ceros a la izquierda y concatena los valores en el orden seleccionado.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","images":[{"pwd_id":12,"pwd_bin":"iVBORw0KGgo...","pwd_active":true},{"pwd_id":19,"pwd_bin":"/9j/4AA...","pwd_active":false}]}
```

### `GET /auth/login-mode?username=<usuario>&role=<rol>` — Consultar el método de acceso

No requiere sesión. Permite que el formulario sepa qué control de acceso mostrar antes de autenticar. Para `role=student` responde con el valor de `stud_access_img_pwd`; si el usuario no existe, o el rol es distinto de `student`, devuelve `false`. No devuelve nombres ni otros datos de la cuenta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","stud_access_img_pwd":true}
```

### `POST`, `PUT` y `DELETE /auth/password-images` — Gestionar catálogo de imágenes

Solo administrador. `POST /auth/password-images` añade una imagen con `multipart/form-data` en `file` y devuelve el `pwd_id` generado. `PUT /auth/password-images/{pwd_id}` reemplaza el binario de una imagen activa. `DELETE /auth/password-images/{pwd_id}` la desactiva; la fila y el ID se conservan para no invalidar la secuencia hasheada de una cuenta. Se admiten PNG, JPEG y WebP hasta 5 MB. La operación de baja es lógica; el catálogo incluye las imágenes inactivas para el acceso, aunque el backend las rechaza al crear o cambiar una contraseña gráfica. La tabla nace vacía: el administrador debe cargar las imágenes antes de habilitar este método a un alumno; el script de datos de prueba no incluye binarios de imágenes de contraseña.

**Respuesta de creación:**
```json
{"errorCode":0,"details":"successful","pwd_id":23}
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

En este módulo, cada cuenta tiene una foto de perfil. La tabla común `users` referencia `Avatar` mediante `avatar_id_fk`; las especializaciones `Admn`, `Staff`, `Student` y `Parents` heredan esa foto a través de su relación con `users`. La referencia es obligatoria y las cuentas nuevas reciben una silueta SVG predeterminada.

### `POST /users` — Crear usuario

Solo administrador. Recibe un objeto JSON discriminado por `role`.

Campos comunes obligatorios: `username`, `full_name` y `password`. El username se recorta y no puede contener espacios; el nombre completo se recorta, debe contener alguna letra y no puede contener números. La contraseña no puede superar 72 bytes UTF-8 (límite de bcrypt). No se aceptan campos no definidos.

Para `role: "student"` también son obligatorios todos los campos de accesibilidad: `stud_access_main_col`, `stud_access_sec_col`, `stud_access_ntasks_visible`, `stud_access_pictograms`, `stud_access_contrast`, `stud_access_fontsize`, `stud_access_filters`, `stud_access_ndays_visible`, `stud_access_prof_mod`, `stud_access_timebar`, `stud_access_talkback`, `stud_access_profile_mod`, `stud_access_task_mod` y `stud_access_img_pwd`. Los colores deben ser hexadecimales de 3 o 6 dígitos (por ejemplo, `#abc` o `#aabbcc`). Las cantidades visibles deben ser enteros JSON no negativos y el tamaño de fuente un entero JSON positivo. Los campos booleanos requieren `true` o `false` de JSON. Si `stud_access_img_pwd` es `true`, `password` debe concatenar entre 4 y 8 IDs distintos de imágenes activas, cada uno expresado con cinco dígitos (ceros a la izquierda si hace falta) y sin separadores; el backend almacena su hash bcrypt en `users.password`. Si es `false`, `password` mantiene el formato de texto habitual.

La operación crea una imagen SVG predeterminada en `Avatar` y la asigna a `users.avatar_id_fk`; después inserta la especialización correspondiente en `Admn`, `Staff`, `Student` o `Parents`. La cuenta común nunca queda sin foto. Todas las inserciones se confirman conjuntamente. El username es único en la tabla común, por lo que no puede repetirse entre roles. Si ya existe, se devuelve `USERNAME_TAKEN` (HTTP 409); otros errores de creación usan `USER_CREATE_FAILED` (HTTP 500).

El rol se fija al crear la cuenta y es inmutable. Ni el propio usuario ni un administrador pueden cambiarlo después; para cambiar el rol hay que crear una cuenta nueva con el rol correcto.

**JSON de entrada para estudiante:**
```json
{"username":"luis","full_name":"Luis Pérez","password":"clave","role":"student","stud_access_main_col":"#ffffff","stud_access_sec_col":"#000000","stud_access_ntasks_visible":5,"stud_access_pictograms":true,"stud_access_contrast":false,"stud_access_fontsize":18,"stud_access_filters":true,"stud_access_ndays_visible":7,"stud_access_prof_mod":false,"stud_access_timebar":true,"stud_access_talkback":false,"stud_access_profile_mod":true,"stud_access_task_mod":true,"stud_access_img_pwd":false}
```

Con contraseña gráfica, el campo `password` recibe los IDs en el orden elegido. El ejemplo usa los IDs 12, 4, 19 y 7; deben existir y estar activos en el catálogo:
```json
{"username":"luis","full_name":"Luis Pérez","password":"00012000040001900007","role":"student","stud_access_main_col":"#ffffff","stud_access_sec_col":"#000000","stud_access_ntasks_visible":5,"stud_access_pictograms":true,"stud_access_contrast":false,"stud_access_fontsize":18,"stud_access_filters":true,"stud_access_ndays_visible":7,"stud_access_prof_mod":false,"stud_access_timebar":true,"stud_access_talkback":false,"stud_access_profile_mod":true,"stud_access_task_mod":true,"stud_access_img_pwd":true}
```

**JSON de entrada para admin, staff o parent:**
```json
{"username":"ana","full_name":"Ana López","password":"clave","role":"parent"}
```

```json
{"username":"ana","full_name":"Ana López","password":"clave","role":"parent"}
```

**Respuesta correcta:**
```json
{"errorCode": 0, "details": "successful"}
```

### `GET /users` y `GET /users?role=<rol>` — Listar usuarios

Solo administrador. Sin `role`, reúne usuarios de las cuatro tablas hijas; con `role`, filtra a un solo rol. Cada resultado contiene username, full name, rol y `avatar_url`. Para estudiantes también incluye sus atributos de accesibilidad. La lista se ordena por username. No devuelve contraseñas ni tokens.

El parámetro `role` se valida contra los cuatro roles admitidos; un valor distinto devuelve `INVALID_REQUEST` (HTTP 422). Los fallos de consulta devuelven `USER_LIST_FAILED` (HTTP 500).

**Entrada:** sin cuerpo. Filtro opcional en query, por ejemplo `?role=student`.

**Respuesta JSON (ejemplo abreviado):**
```json
{"errorCode":0,"details":"successful","users":[{"username":"ana","full_name":"Ana López","role":"parent","avatar_url":"/users/parent/ana/avatar-image"},{"username":"luis","full_name":"Luis Pérez","role":"student","avatar_url":"/users/student/luis/avatar-image","stud_access_main_col":"#ffffff","stud_access_sec_col":"#000000","stud_access_ntasks_visible":5,"stud_access_pictograms":true,"stud_access_contrast":false,"stud_access_fontsize":18,"stud_access_filters":true,"stud_access_ndays_visible":7,"stud_access_prof_mod":false,"stud_access_timebar":true,"stud_access_talkback":false,"stud_access_profile_mod":true,"stud_access_task_mod":true,"stud_access_img_pwd":false}]}
```

### `GET /users/{role}/{username}` — Consultar una cuenta concreta

Solo administrador. Busca una cuenta por username dentro del rol indicado y devuelve sus datos de perfil: `username`, `full_name`, `role`, `avatar_url` y preferencias de accesibilidad para estudiantes. No devuelve contraseña ni token. Si la cuenta no existe en ese rol, responde `USER_NOT_FOUND` (HTTP 404); si falla la consulta, `USER_LOOKUP_FAILED` (HTTP 500).

**Entrada:** sin cuerpo. Ejemplo: `GET /users/parent/ana` con Bearer de administrador.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","username":"ana","full_name":"Ana López","avatar_url":"/users/parent/ana/avatar-image","role":"parent"}
```

### `GET /users/me` — Consultar mi propia ficha

Requiere autenticación y devuelve únicamente la ficha del usuario asociado al token. El endpoint obtiene el rol y el username de la sesión; el cliente no puede indicar otra cuenta. Para el alumnado incluye los ajustes de accesibilidad (`stud_access_*`), de modo que pueda cargar su configuración al iniciar sesión. Para los demás roles devuelve los campos propios de su perfil. No devuelve contraseña ni token. Una sesión ausente o inválida recibe `INVALID_TOKEN` (HTTP 401); si no se encuentra la ficha asociada a la sesión, responde `USER_NOT_FOUND` (HTTP 404).

**Entrada:** sin cuerpo ni parámetros. Ejemplo: `GET /users/me` con el Bearer del alumno autenticado.

**Respuesta JSON (ejemplo de alumno):**
```json
{"errorCode":0,"details":"successful","username":"luis","full_name":"Luis Pérez","avatar_url":"/users/student/luis/avatar-image","stud_access_main_col":"#ffffff","stud_access_sec_col":"#000000","stud_access_ntasks_visible":5,"stud_access_pictograms":true,"stud_access_contrast":false,"stud_access_fontsize":18,"stud_access_filters":true,"stud_access_ndays_visible":7,"stud_access_prof_mod":false,"stud_access_timebar":true,"stud_access_talkback":false,"stud_access_profile_mod":true,"stud_access_task_mod":true,"stud_access_img_pwd":false,"role":"student"}
```

### `PUT /users/{role}/{username}` — Editar perfil o datos de usuario

Requiere autenticación. Un administrador puede editar cualquier cuenta. Un `parent` o `staff` solo puede editar su contraseña y no puede enviar `username`, `full_name` ni `role`. Un `student` solo puede editar sus propios ajustes de accesibilidad, y únicamente si `stud_access_profile_mod` está activado; si está desactivado, se rechaza la edición con `PROFILE_UPDATE_DENIED` (HTTP 403). El alumno no puede cambiar `username`, `full_name`, contraseña ni `role`, ni modificar los indicadores reservados al administrador `stud_access_prof_mod`, `stud_access_profile_mod`, `stud_access_task_mod` y `stud_access_img_pwd`. Ningún usuario puede cambiar el rol de una cuenta: un administrador que envíe un `role` distinto del actual recibe `ROLE_CHANGE_DENIED` (HTTP 403); un usuario no administrador que envíe `role` recibe `PROFILE_UPDATE_DENIED` (HTTP 403).

El JSON acepta campos opcionales: `username`, `role`, `full_name`, `password` y campos `stud_access_*`. No se aceptan propiedades extra. Debe haber al menos un campo que modificar. El username y el nombre completo aplican validaciones iguales a las de creación; la contraseña está limitada a 72 bytes. Los valores numéricos y booleanos de accesibilidad deben usar sus tipos JSON correspondientes, y los colores deben seguir el formato hexadecimal indicado en creación.

Cambiar username actualiza la clave común y las referencias en cascada; también actualiza `Tasks.task_creator` y `Alt_Tasks.alt_task_creator`. Cambiar username o contraseña invalida el token activo. Cambiar solo `full_name` o accesibilidad no invalida el token. Si el administrador activa o desactiva `stud_access_img_pwd`, debe enviar una contraseña nueva en la misma operación para que el usuario no pierda acceso. En modo gráfico, esa contraseña debe ser una secuencia válida de IDs activos; en modo texto se valida como contraseña ordinaria. El rol y su fila de especialización no se modifican mediante esta ruta.

La respuesta de éxito devuelve el `username` y el rol resultante.

Errores relevantes: `PROFILE_UPDATE_DENIED` (403), `ROLE_CHANGE_DENIED` (403), `USER_NOT_FOUND` (404), `USERNAME_TAKEN` (409), `NO_UPDATE_FIELDS`, `INVALID_REQUEST` y `LAST_ADMIN` (400 según catálogo).

**JSON de entrada (ejemplo de cambios parciales; solo se envían los campos que se desean modificar):**
```json
{"full_name":"Nombre actualizado","password":"nueva-clave"}
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

### `PUT /users/{role}/{username}/avatar` — Actualizar la foto de cualquier cuenta

Solo administrador. Recibe `multipart/form-data` con el archivo en `file`, en PNG, JPEG o WebP y hasta 5 MB. El backend valida firma y estructura básica; devuelve `AVATAR_INVALID_IMAGE` (HTTP 422) o `AVATAR_TOO_LARGE` (HTTP 413) si no cumple los límites, y `USER_NOT_FOUND` si no existe el usuario en ese rol.

La imagen se guarda en `Avatar.avatar_bin` y `users.avatar_id_fk` se actualiza en la misma transacción. La foto anterior se elimina cuando ya no está referenciada. La cuenta conserva siempre una imagen asignada. La respuesta incluye `avatar_id`, `media_type` y un `avatar_url` con la forma `/users/{role}/{username}/avatar-image`.

**Entrada:** `PUT /users/parent/ana/avatar`, token Bearer de administrador y `multipart/form-data`; no es JSON.

### `PUT /users/me/avatar` — Actualizar mi propia foto

Requiere token. `admin`, `staff` y `parent` pueden cambiar su propia imagen. `student` puede hacerlo solo si `stud_access_profile_mod` está activado. Recibe el mismo archivo y aplica las mismas validaciones que la ruta de administración.

### `GET /users/me/avatar` — Obtener mi foto

Requiere token de cualquier rol y devuelve directamente la imagen con su tipo MIME. Si el archivo guardado no es un PNG, JPEG o WebP reconocido, devuelve la silueta SVG predeterminada. La respuesta usa `Cache-Control: no-store`.

### `GET /users/{role}/{username}/avatar-image` — Obtener la foto de una cuenta

El administrador puede consultar cualquier cuenta y cada usuario autenticado puede consultar su propia foto. Un alumno puede consultar fotos de compañeros de sus clases, de sus tutores asociados y del personal asignado a esas clases. Un tutor puede consultar las fotos de sus alumnos asociados y del personal que enseña en las clases de esos alumnos. El personal puede consultar fotos del alumnado de las clases que imparte. Sin token, solo se sirven fotos del alumnado matriculado, para el acceso visual previo al login; no se exponen fotos de otros roles ni de alumnos sin clase. Las denegaciones autenticadas devuelven `ASSOCIATION_ACCESS_DENIED` (HTTP 403); las solicitudes anónimas tampoco reciben fotos fuera del directorio permitido. La respuesta usa `Cache-Control: no-store`.

Las rutas anteriores `/users/students/me/avatar`, `/users/students/{student_username}/avatar` y `/users/students/{student_username}/avatar-image` se conservan como compatibilidad para clientes existentes.

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

Solo administrador. Devuelve dos listas actuales: `parents` y `staff`. Cada entrada incluye username, full name y `avatar_url`. Los padres salen de `par_stud`; el personal se obtiene de la clase a la que pertenece el alumno y sus filas en `class_staff`. Si el alumno aún no tiene clase, `staff` será una lista vacía. Si no existe el alumno, devuelve `ASSOCIATED_ENTITY_NOT_FOUND` (HTTP 404).

**Entrada:** sin cuerpo; username en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","student_username":"luis","parents":[{"username":"ana","full_name":"Ana López","avatar_url":"/users/parent/ana/avatar-image"}],"staff":[{"username":"marta","full_name":"Marta Ruiz","avatar_url":"/users/staff/marta/avatar-image"}]}
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

El estado de finalización se llama `task_finished` en la base de datos y en las respuestas (no `task_completed`). Se almacena por alumno en `stud_task`. Aunque la aplicación cliente declara usar `PATCH /student-tasks/me/{task_id}/progress` para registrar el progreso, esa ruta no está implementada en este backend: aquí no hay una operación HTTP para actualizar `stud_task.task_finished` ni `Steps.step_finished`. Por tanto, el esquema y las consultas ya representan progreso individual, pero el flujo de completar desde el cliente no puede persistir en este backend hasta añadir esa operación.

### `GET /student-tasks/students/{student_username}?task_date=AAAA-MM-DD` — Consultar tareas y pasos de un alumno por día

Requiere personal asignado a una clase compartida con el alumno o tutor asociado mediante `par_stud`. Devuelve las tareas de la agenda de ese alumno para la fecha indicada, ordenadas según `task_index`; incluye también `class_name_fk` para identificar las asignaciones que proceden de una clase. Cada tarea incluye `steps`, ordenados por `step_index` y `step_id`, con descripción, estado e índice. Una tarea sin pasos devuelve `steps: []`. Si el alumno no existe, devuelve `TASK_STUDENT_NOT_FOUND`; si el usuario autenticado no está asociado a él, devuelve `TASK_STUDENT_NOT_ASSOCIATED`.

**Entrada:** sin cuerpo. Ejemplo: `GET /student-tasks/students/luis?task_date=2026-11-10`.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","stud_usr_fk":"luis","task_date":"2026-11-10","tasks":[{"task_id":41,"task_title":"Leer un cuento","task_start_hour":"10:00:00","task_duration":20,"task_creator":"marta","task_finished":false,"alt_task_id_fk":null,"task_date":"2026-11-10","task_index":0,"class_name_fk":"Primero A","steps":[{"step_id":7,"step_description":"Leer el enunciado","step_finished":false,"step_index":0}] }]}
```

### `GET /student-tasks/me?task_date=AAAA-MM-DD` — Consultar tareas y pasos propios por día

Requiere token de alumno. Todos los alumnos pueden consultar su agenda, independientemente del permiso `stud_access_task_mod`, que solo controla la creación o modificación de sus propias tareas. Devuelve las tareas de la agenda propia para esa fecha, en orden de `task_index`. Si no hay tareas para ese día, `tasks` es una lista vacía.

**Entrada:** sin cuerpo. Ejemplo: `GET /student-tasks/me?task_date=2026-11-10`.

**Respuesta JSON:** usa el mismo formato de la consulta de tareas de un alumno.

### `POST /student-tasks/students/{student_username}` — Crear tarea en la agenda de un alumno

Responde HTTP 201. El JSON requiere `task_title`, `task_date` y `task_duration`. La fecha es obligatoria, puede ser futura y no se limita al día actual. El título se recorta y debe contener entre 1 y 100 caracteres; la duración es un entero positivo expresado en minutos. Son opcionales `task_start_hour` (hora local sin zona) y `alt_task_id_fk` (entero positivo). `task_index` no se envía: el backend lo calcula para la agenda del alumno. Si falta la duración, es `null` o no es positiva, FastAPI rechaza la petición con error de validación `1005` (HTTP 422). No admite propiedades adicionales.

El alumno debe existir y el usuario autenticado debe estar asociado a él según su rol. El personal debe indicar `task_start_hour`; el intervalo completo `[hora de inicio, hora de inicio + duración)` debe quedar entre las 09:00 y las 15:00. `parent` puede indicar una hora, pero su intervalo completo no puede solaparse con `[09:00, 15:00)`. La franja escolar se aplica todos los días; por ahora tampoco se admiten tareas de tutor entre las 09:00 y las 15:00 en fin de semana. Los festivos no se distinguen hasta disponer de un calendario del centro. Las tareas de `parent` sin hora se permiten y se colocan después de todas las tareas con hora de esa fecha. En los límites, terminar exactamente a las 09:00 o empezar exactamente a las 15:00 no se considera solapamiento para tutores; el personal sí puede terminar exactamente a las 15:00. Si se indica alternativa, esta debe existir y no estar ya enlazada a otra tarea.

La operación inserta los datos comunes en `Tasks` (sin estado de finalización), añade el subtipo `Generic_Task` y crea la asignación `stud_task` con alumno, tarea, índice calculado y fecha. `stud_task.task_finished` es el estado individual de esa asignación y nace en `false`. Completar una tarea en la agenda de un alumno no altera el estado de sus compañeros. Las tareas con hora se insertan según su hora respecto a las tareas de esa fecha; las tareas sin hora de `parent` se colocan al final, por lo que su índice queda después de la última tarea de `staff`. Las tareas de `parent` con hora anterior a las 09:00 quedan antes de las de `staff`, y las posteriores a las 15:00 quedan después. Si se inserta una tarea antes de otras, sus índices se desplazan para abrirle sitio. La agenda del alumno se bloquea durante el cálculo para serializar inserciones concurrentes. Todo se confirma en una transacción. La respuesta incluye el índice asignado. El esquema también impone `NOT NULL` y `CHECK (> 0)` en `Tasks.task_duration` y `Alt_Tasks.alt_task_duration`; las alternativas ya almacenadas deben cumplirlo aunque esta API solo las asocie.

`CreacionTablas.sqlscript` contiene las instrucciones para crear las tablas y no las elimina. Para reiniciar el esquema se ejecuta primero `EliminacionTablas.sqlscript` y después `CreacionTablas.sqlscript`.

El script `scripts/levantar_backend.sh` levanta PostgreSQL y llama a `scripts/datos_de_prueba.py`. Si no encuentra la tabla `users`, este último crea el esquema desde `CreacionTablas.sqlscript` y después inserta las cuentas, aulas y tareas de prueba. Si se ejecuta `datos_de_prueba.py --borrar`, elimina las tablas con `EliminacionTablas.sqlscript`, las vuelve a crear con `CreacionTablas.sqlscript` y repuebla los datos de prueba.

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

### `POST /student-tasks/{task_id}/steps` — Añadir un paso a una tarea individual

Requiere sesión de `parent`, `staff` o `student`. Recibe `step_description` como texto no vacío; `""` y texto compuesto solo de espacios se rechazan con `INVALID_REQUEST` (HTTP 422). El tutor solo puede añadir pasos a una tarea propia que siga asignada a un alumno enlazado a su cuenta y la tarea debe estar completamente fuera del horario escolar (09:00–15:00). El personal puede añadir pasos a una tarea individual propia que siga asignada directamente a un alumno con quien comparte clase; debe estar completamente dentro del horario escolar. Las tareas de clase usan la ruta de pasos de clase. El alumno solo puede añadir pasos a tareas propias y necesita `stud_access_task_mod = true`. La tarea debe ser de tipo `Generic_Task`; las tareas inexistentes o no accesibles devuelven `TASK_NOT_FOUND` (HTTP 404). El paso se crea pendiente (`step_finished: false`) y se añade al final de la secuencia.

Antes de añadirlo, el backend bloquea la fila de la tarea y normaliza los índices existentes en orden ascendente de `step_index` (los índices nulos van al final; los empates se resuelven por `step_id`), dejándolos consecutivos desde cero. El nuevo paso recibe el siguiente índice. El bloqueo serializa creaciones y eliminaciones concurrentes para esa tarea. Responde HTTP 201.

**JSON de entrada:**
```json
{"step_description":"Leer el enunciado"}
```

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","step_id":7,"step_description":"Leer el enunciado","step_finished":false,"step_index":0,"generic_task_id_fk":42}
```

### `PUT /student-tasks/{task_id}/steps/order` — Reordenar pasos de una tarea individual

Solo personal (`staff`) puede cambiar el orden. La tarea debe ser individual, haber sido creada por el miembro del personal autenticado, seguir asignada directamente a un alumno con quien comparte clase y quedar dentro del horario escolar. El cuerpo contiene `step_ids` en el orden nuevo. Debe incluir exactamente una vez cada paso de la tarea; no se permiten IDs repetidos, ajenos ni omitidos. Una lista vacía es válida solo cuando la tarea no tiene pasos. Las entradas inválidas devuelven `INVALID_REQUEST` (HTTP 422); una tarea no accesible o no creada por el usuario devuelve `TASK_NOT_FOUND` (HTTP 404). El cambio de índices se guarda en una transacción y se hace visible en la siguiente consulta de agenda del alumno. Responde con la lista de pasos ya ordenada.

**JSON de entrada:**
```json
{"step_ids":[9,7,8]}
```

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","task_id":42,"steps":[{"step_id":9,"step_description":"Preparar el material","step_finished":false,"step_index":0},{"step_id":7,"step_description":"Leer el enunciado","step_finished":false,"step_index":1},{"step_id":8,"step_description":"Resolverlo","step_finished":false,"step_index":2}]}
```

### `PUT /student-tasks/{task_id}/steps/{step_id}` — Modificar un paso individual

Admite `step_description` (texto no vacío) y/o `step_index` (entero desde cero); no acepta campos extra y debe indicarse al menos uno. Si se omiten ambos campos o se envían como `null`, devuelve `NO_UPDATE_FIELDS` (HTTP 400); una descripción vacía o un índice negativo se rechazan con `INVALID_REQUEST` (HTTP 422). El tutor puede editar pasos de una tarea propia solo mientras siga asociado al alumno destinatario y si la actividad queda fuera del horario escolar. El personal puede editar una tarea individual propia, asignada a un alumno con quien comparte clase, si queda dentro del horario escolar. El alumno puede editar pasos de tareas propias si `stud_access_task_mod = true`. Estos permisos siguen las reglas de propiedad, asociación y horario aplicadas a las tareas individuales. No permite cambiar `step_finished`. Si la tarea o el paso no existen o no son accesibles, devuelve `TASK_NOT_FOUND`; los rechazos por horario usan `PARENT_TASK_DURING_SCHOOL_HOURS` o `STAFF_TASK_OUTSIDE_SCHOOL_HOURS`.

La actualización se realiza dentro de una transacción y conserva el estado del paso. Al indicar `step_index`, los índices son desde cero y se mantienen consecutivos: si el destino está ocupado, los pasos intermedios se desplazan para hacerle sitio; si el valor solicitado supera el índice máximo actual, el paso se coloca en ese índice máximo. Por ejemplo, con índices `0, 1, 2`, solicitar `7` coloca el paso en `2`; no deja huecos. El paso se mueve dentro del mismo listado y los demás conservan su orden relativo. El backend bloquea la tarea mientras actualiza, de modo que la descripción y el orden se guardan juntos sin colisiones con otras operaciones de pasos. Los cambios aparecen en la siguiente consulta de agenda del alumno. Responde con el paso actualizado.

**JSON de entrada:**
```json
{"step_description":"Leer el enunciado y subrayar las ideas clave"}
```

Para mover el paso `7` al índice `2`:
```json
{"step_index":2}
```

Se pueden cambiar contenido e índice en la misma petición:
```json
{"step_description":"Resolver y revisar el ejercicio","step_index":1}
```

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","step_id":7,"step_description":"Leer el enunciado y subrayar las ideas clave","step_finished":false,"step_index":1,"generic_task_id_fk":42}
```

### `DELETE /student-tasks/{task_id}/steps/{step_id}` — Eliminar un paso de una tarea individual

Requiere sesión de `parent`, `staff` o `student` y aplica los mismos permisos de tarea individual que la creación del paso: el tutor debe ser autor y mantener enlazado al alumno destinatario; el alumno debe ser autor y tener `stud_access_task_mod = true`; el personal debe ser autor y seguir compartiendo clase con algún alumno al que la tarea esté asignada directamente. El tutor solo puede borrar pasos de tareas fuera del horario escolar y el personal solo de tareas dentro del horario escolar. El `step_id` debe pertenecer al `task_id` indicado. Una tarea o paso inexistente, ajeno o no accesible devuelve `TASK_NOT_FOUND` (HTTP 404); los rechazos por horario devuelven `PARENT_DELETE_DURING_SCHOOL_HOURS` o `STAFF_DELETE_OUTSIDE_SCHOOL_HOURS` (HTTP 400). No requiere cuerpo. La interfaz cliente debe pedir confirmación antes de enviar esta operación DELETE.

La operación bloquea la tarea, elimina solo el paso indicado y reindexa los pasos restantes por el orden previo (`step_index`, con `step_id` como desempate) a `0..N-1`. Así no quedan huecos ni índices duplicados. La eliminación y la reordenación se confirman en la misma transacción. Devuelve `task_id`, `deleted_step_id`, el índice que tenía el paso eliminado y el total de pasos restantes.

**Ejemplo:** `DELETE /student-tasks/42/steps/7`.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","task_id":42,"deleted_step_id":7,"deleted_step_index":0,"remaining_steps":2}
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

Requiere token de alumno y `stud_access_task_mod = true`. Comprueba que la asignación corresponda al alumno autenticado y que `Tasks.task_creator` también sea su username, para impedir que borre tareas de personal o tutores. Si la tarea tiene hora, su intervalo completo debe quedar fuera de `[09:00, 15:00)`; una tarea solo de duración sin hora también se puede eliminar. Si el intervalo se solapa con el horario escolar, responde `STUDENT_TASK_OUTSIDE_SCHOOL_HOURS` (HTTP 400). Sin permiso de modificación responde `STUDENT_TASK_MODIFICATION_DENIED` (HTTP 403). Elimina la asignación indicada y, si la tarea propia ya no tiene ninguna otra asignación, elimina también su fila de `Tasks` y el `Generic_Task` asociado; la cascada elimina sus pasos. Devuelve los identificadores de la asignación eliminada.

**Entrada:** sin cuerpo. Ejemplo: `DELETE /student-tasks/me/42?task_date=2026-11-10`.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","task_id":42,"stud_usr_fk":"luis","task_date":"2026-11-10","task_index":0}
```

## Clases

Prefijo `/classes`. Las clases se guardan en `Class`; `class_staff` asocia personal a clases, `class_stud` inscribe alumnos y `class_task` vincula tareas grupales a una clase. `stud_task.class_name_fk` marca las asignaciones a alumnos que proceden de una clase; las tareas individuales dejan ese campo nulo. El personal solo puede consultar o administrar una clase si está asignado a ella. El administrador puede consultar todas las clases y sus detalles, gestionar el catálogo y las asignaciones de personal, e inscribir o retirar alumnos de cualquier clase.

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

La consulta es pública para permitir la selección de clase antes del login. Sin token, devuelve únicamente el campo `class_name` para cada clase, sin otros datos. Con token, el administrador recibe todas las clases y el personal únicamente las clases que tiene asignadas; otros roles reciben `CLASS_ACCESS_DENIED` (HTTP 403). Cada clase autenticada incluye `class_name`, `student_count` y `students`; cada alumno incluye `username`, `full_name` y `avatar_url` con la ruta común de perfiles. El endpoint permite acceso anónimo solo a fotos de alumnos matriculados en alguna clase. Si el usuario autenticado no tiene clases visibles, `classes` es una lista vacía; si una clase no tiene alumnos, `students` es una lista vacía y `student_count` vale 0.

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
{"errorCode":0,"details":"successful","class_name":"Primero A","students":[{"username":"luis","full_name":"Luis Pérez","avatar_url":"/users/student/luis/avatar-image"}]}
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

Requiere token de administrador o de personal. El administrador puede inscribir en cualquier clase; el personal solo en una clase a la que esté asignado. Inscribe al alumno en `class_stud`. Comprueba que sea un alumno existente y que no esté inscrito en otra clase. Al matricularlo, también le asigna las tareas que ya estén vinculadas a esa clase en `class_task`, calculando el índice de cada una en su agenda. Repetir la asignación a la misma clase no duplica la matrícula ni las tareas. Responde HTTP 201. Otros roles reciben `CLASS_ACCESS_DENIED` (HTTP 403). Si ya está en otra clase, `STUDENT_ALREADY_IN_CLASS` (HTTP 409); si no existe como alumno, `TASK_STUDENT_NOT_FOUND`.

**Entrada:** sin cuerpo; clase y username en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A","student_username":"luis","class_tasks_assigned":2}
```

### `DELETE /classes/{class_name}/students/{student_username}` — Retirar alumno de clase

Requiere token de administrador o de personal. El administrador puede retirar alumnos de cualquier clase; el personal solo de una clase a la que esté asignado. En una transacción, elimina las asignaciones `stud_task` marcadas como procedentes de esa clase y luego la inscripción `class_stud`. Las tareas individuales del alumno, incluidas las creadas por el mismo profesor, se conservan. La tarea grupal sigue vinculada a la clase y seguirá disponible para los demás alumnos matriculados. Otros roles reciben `CLASS_ACCESS_DENIED` (HTTP 403). Si la relación no existe, devuelve `ASSOCIATION_NOT_FOUND`.

**Entrada:** sin cuerpo; clase y username en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A","student_username":"luis","class_task_assignments_removed":2}
```

### `POST /classes/{class_name}/tasks` — Crear tarea para toda la clase

Requiere staff asignado a la clase. Recibe título, fecha, hora de inicio y duración positiva en minutos; la alternativa es opcional. La fecha es obligatoria y puede ser futura. Si falta la duración o la hora, o la tarea no queda íntegramente entre las 09:00 y las 15:00, se rechaza; también valida el título y que la alternativa exista y no esté ya asignada. `task_index` no se envía: se calcula por separado para cada alumno según sus tareas de esa fecha. La respuesta incluye `task_indexes`, un mapa de username a índice asignado.

La clase debe tener al menos un alumno inscrito; de lo contrario devuelve `CLASS_HAS_NO_STUDENTS`. Crea los datos comunes de la tarea, un registro `Generic_Task`, una fila `class_task` que la vincula a la clase y una fila `stud_task` por cada alumno inscrito. Cada fila `stud_task` guarda también el origen en `class_name_fk` y su `task_finished` individual, inicialmente `false`. Calcula un índice individual para cada agenda y fecha. La operación es transaccional y responde HTTP 201 con la lista de alumnos incluidos y sus índices. La tarea existe como tarea de clase aunque más adelante se retire a todos los alumnos.

**JSON de entrada:**
```json
{"task_title":"Lectura","task_date":"2026-11-10","task_duration":20,"task_start_hour":"10:00:00","alt_task_id_fk":3}
```

**Respuesta JSON (alumnos y valores de ejemplo):**
```json
{"errorCode":0,"details":"successful","task_id":41,"task_title":"Lectura","task_start_hour":"10:00:00","task_duration":20,"task_creator":"marta","task_finished":false,"alt_task_id_fk":3,"class_name":"Primero A","students":["luis","sofia"],"task_indexes":{"luis":2,"sofia":0},"task_date":"2026-11-10"}
```

### `GET /classes/{class_name}/tasks` — Consultar tareas y pasos de una clase

Requiere staff autenticado y asignado a la clase. Devuelve las tareas enlazadas mediante `class_task`, su fecha, los alumnos que aún tienen una asignación de esa tarea originada en la clase y la lista `steps`, ordenada por `step_index` y `step_id`. `task_finished` vale `true` solo cuando todas las asignaciones vigentes de alumnos de esa clase tienen `stud_task.task_finished = true`; si queda al menos una pendiente, vale `false`. `students_finished` enumera a los alumnos que ya han completado la tarea (si ninguno lo ha hecho, es una lista vacía). `students` contiene todos los alumnos con asignación vigente. No incluye tareas individuales creadas por el personal para alumnos concretos.

**Entrada:** sin cuerpo; nombre de clase en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A","tasks":[{"task_id":41,"task_title":"Lectura","task_start_hour":"10:00:00","task_duration":20,"task_creator":"marta","task_finished":false,"alt_task_id_fk":3,"task_date":"2026-11-10","students":["luis","sofia"],"students_finished":["luis"],"steps":[{"step_id":8,"step_description":"Leer el enunciado","step_finished":false,"step_index":0}]}]}
```

### `POST /classes/{class_name}/tasks/{task_id}/steps` — Añadir un paso a una tarea de clase

Requiere token de personal asignado a `{class_name}`. La tarea debe estar vinculada a esa clase, ser de tipo `Generic_Task` y tener un intervalo completamente incluido entre las 09:00 y las 15:00. No exige que el miembro del personal que añade el paso sea quien creó la tarea: cualquier miembro asignado a la clase puede añadir pasos. Si no está asignado a la clase, devuelve `CLASS_ACCESS_DENIED` (HTTP 403); si la tarea no pertenece a la clase, devuelve `TASK_NOT_FOUND` (HTTP 404); si queda fuera del horario, devuelve `STAFF_TASK_OUTSIDE_SCHOOL_HOURS` (HTTP 400). Recibe una descripción no vacía, crea el paso pendiente y lo coloca al final de la secuencia. Antes de insertar, bloquea la tarea y normaliza los índices existentes a una secuencia consecutiva desde cero; el nuevo paso recibe el siguiente índice. Las operaciones concurrentes de pasos para la misma tarea se serializan con el mismo bloqueo. Responde HTTP 201.

**JSON de entrada:**
```json
{"step_description":"Leer el enunciado"}
```

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","step_id":8,"step_description":"Leer el enunciado","step_finished":false,"step_index":1,"generic_task_id_fk":41,"class_name":"Primero A"}
```

### `PUT /classes/{class_name}/tasks/{task_id}/steps/order` — Reordenar pasos de una tarea de clase

Solo puede reordenar el miembro del personal asignado a la clase que también creó la tarea. Debe tratarse de una tarea vinculada a `{class_name}` y dentro del horario escolar. El cuerpo `step_ids` debe incluir exactamente una vez todos los pasos de la tarea, en el orden deseado; si la tarea no tiene pasos, se puede enviar una lista vacía. No se puede reordenar la tarea de otro miembro del personal aunque se tenga acceso de consulta a la clase. Las listas incompletas, repetidas o con IDs ajenos devuelven `INVALID_REQUEST` (HTTP 422); si la tarea no pertenece a la clase o no la creó el usuario, `TASK_NOT_FOUND` (HTTP 404). El backend bloquea la tarea, actualiza los índices en una transacción y responde con la lista ordenada. El alumno verá el contenido y el orden nuevos en su siguiente consulta de agenda.

**JSON de entrada:**
```json
{"step_ids":[8,7]}
```

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","task_id":41,"steps":[{"step_id":8,"step_description":"Leer el enunciado","step_finished":false,"step_index":0},{"step_id":7,"step_description":"Preparar el material","step_finished":false,"step_index":1}],"class_name":"Primero A"}
```

### `PUT /classes/{class_name}/tasks/{task_id}/steps/{step_id}` — Modificar un paso de una tarea de clase

Solo el miembro del personal que creó la tarea y que sigue asignado a `{class_name}` puede modificar el paso. La tarea debe pertenecer a esa clase y estar dentro del horario escolar. Admite `step_description` no vacía y/o `step_index` entero desde cero; debe enviarse al menos uno. No permite editar el estado del paso. Al cambiar el índice, desplaza los pasos ocupantes conservando su orden relativo y limita cualquier valor superior al índice máximo actual a ese máximo, sin dejar huecos. Si el personal no creó la tarea, no está asignado a la clase, el paso no pertenece a la tarea o la tarea queda fuera del horario, se devuelve el error catalogado correspondiente (`TASK_NOT_FOUND`, `CLASS_ACCESS_DENIED` o `STAFF_TASK_OUTSIDE_SCHOOL_HOURS`). La descripción y el nuevo orden se guardan en una transacción y quedan disponibles para el alumno en la siguiente consulta de agenda.

**JSON de entrada:**
```json
{"step_description":"Leer el enunciado y subrayar las ideas clave"}
```

Para colocar el paso en el último índice existente, se puede enviar un índice superior al máximo, por ejemplo `{"step_index": 999}`; el servidor lo limita al índice máximo actual.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","step_id":8,"step_description":"Leer el enunciado y subrayar las ideas clave","step_finished":false,"step_index":0,"generic_task_id_fk":41,"class_name":"Primero A"}
```

### `DELETE /classes/{class_name}/tasks/{task_id}/steps/{step_id}` — Eliminar un paso de una tarea de clase

Requiere personal asignado a `{class_name}`; no necesita que ese miembro haya creado la tarea ni el paso. La tarea debe estar vinculada a la clase indicada, el paso al `task_id` y el intervalo de la tarea debe quedar dentro de 09:00–15:00. Si no está asignado a la clase, devuelve `CLASS_ACCESS_DENIED` (HTTP 403); si la tarea o el paso no corresponden a esa clase y tarea, devuelve `TASK_NOT_FOUND` (HTTP 404); si la tarea está fuera del horario, devuelve `STAFF_DELETE_OUTSIDE_SCHOOL_HOURS` (HTTP 400). No requiere cuerpo. La interfaz cliente debe pedir confirmación antes de enviar esta operación DELETE.

Elimina únicamente el paso indicado. En la misma transacción reordena los pasos restantes según su orden previo y los renumera consecutivamente desde cero. El bloqueo de la tarea evita que una creación o eliminación concurrente deje huecos o índices repetidos.

**Ejemplo:** `DELETE /classes/Primero%20A/tasks/41/steps/8`.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","task_id":41,"deleted_step_id":8,"deleted_step_index":1,"remaining_steps":1,"class_name":"Primero A"}
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

Requiere staff asignado a la clase. Elimina la relación `class_task` y las asignaciones `stud_task` cuyo origen sea esa clase. Si la tarea no tiene ya asignaciones directas ni otros vínculos de clase, también elimina la tarea común y su subtipo; la cascada elimina entonces sus pasos. Una asignación directa del mismo `task_id` a un alumno se conserva junto con la tarea y sus pasos. Si la relación clase-tarea no existe, devuelve `TASK_NOT_FOUND`.

**Entrada:** sin cuerpo; clase y `task_id` en la ruta.

**Respuesta JSON:**
```json
{"errorCode":0,"details":"successful","class_name":"Primero A","task_id":41,"student_assignments_removed":2}
```

## Errores y lectura del estado

Los códigos y textos públicos se mantienen en `proyectFastAPI/errors.py`. En general, un código 4xx representa credenciales/permisos/entidades/datos no válidos; un 5xx representa fallo interno. No se deben interpretar errores de PostgreSQL directamente desde el frontend: la API traduce errores conocidos al catálogo y oculta los detalles internos.

Las listas y consultas de asociaciones, clases y tareas se generan desde las relaciones actuales de la base de datos. Las rutas de asociación y de clase no incluyen confirmaciones de interfaz; cualquier diálogo de confirmación antes de una operación destructiva debe implementarse en el cliente antes de enviar la petición.

## Interacciones entre módulos

1. **Identidad y especialización:** `users` contiene los campos comunes (`username`, `full_name`, contraseña y token); `Admn`, `Staff`, `Student` y `Parents` determinan el rol y mantienen campos propios. Login y autorización unen la cuenta común con la especialización del rol. `Student.stud_access_img_pwd` selecciona el método de acceso solo para alumnos. `passwords` es un catálogo global sin FK a usuarios; el ID y binario se envían al cliente y el hash de la secuencia elegida se conserva en `users.password`.
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
