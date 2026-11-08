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

### `GET /`

No requiere autenticación. Ejecuta `SELECT 1` en PostgreSQL y devuelve `estado: "ok"` y `mensaje: "API conectada a PostgreSQL"` dentro del sobre de éxito. Si no se puede ejecutar la consulta, la respuesta pasa por el manejador de error interno.

## Autenticación

### `POST /auth/login`

Recibe JSON con `username`, `password` y `role`. El usuario y contraseña deben estar presentes; el rol debe ser uno de los cuatro roles admitidos.

El servidor busca la cuenta en `users` junto a la tabla hija correspondiente al rol y compara la contraseña recibida con el hash bcrypt almacenado. Si coincide, genera un token aleatorio, guarda su hash SHA-256 en `users.token` y confirma el cambio. El token anterior de ese usuario deja de servir. La respuesta incluye `access_token`, `token_type: "bearer"` y la identidad `{username, role}`.

Una contraseña incorrecta o una combinación de usuario/rol que no corresponde devuelve `INVALID_CREDENTIALS` (HTTP 401). Un rol no admitido devuelve `INVALID_ROLE` (HTTP 400). Un fallo de infraestructura de autenticación devuelve `LOGIN_FAILED` (HTTP 500).

### `POST /auth/logout`

Requiere un Bearer válido. La dependencia primero verifica que el token corresponde a una sesión activa. Después, el endpoint guarda `NULL` en `users.token` para ese token y confirma la transacción. La respuesta identifica el usuario y rol cuya sesión se cerró. Si falta el token, no es válido o ya fue revocado, devuelve `INVALID_TOKEN` (HTTP 401).

### Dependencias de autenticación utilizadas por otras rutas

- `get_current_user` valida el Bearer y aporta `username` y `role` a la operación. Un token ausente o inválido impide acceder con HTTP 401.
- `require_admin` además exige el rol `admin`; el resto recibe `ADMIN_REQUIRED` (HTTP 403).
- Un token nuevo invalida el anterior para ese usuario, y cambiar contraseña, username o rol también revoca la sesión al actualizar `users.token`.

## Gestión de usuarios

Todas las rutas de este grupo tienen prefijo `/users`.

### `POST /users`

Solo administrador. Recibe un objeto JSON discriminado por `role`.

Campos comunes obligatorios: `username`, `full_name` y `password`. El username se recorta y no puede contener espacios; el nombre completo se recorta, debe contener alguna letra y no puede contener números. La contraseña no puede superar 72 bytes UTF-8 (límite de bcrypt). No se aceptan campos no definidos.

Para `role: "student"` también son obligatorios todos los campos de accesibilidad: `stud_access_main_col`, `stud_access_sec_col`, `stud_access_ntasks_visible`, `stud_access_pictograms`, `stud_access_contrast`, `stud_access_fontsize`, `stud_access_filters`, `stud_access_ndays_visible`, `stud_access_prof_mod`, `stud_access_timebar`, `stud_access_talkback`, `stud_access_profile_mod` y `stud_access_task_mod`. Las cantidades visibles no pueden ser negativas y el tamaño de fuente debe ser positivo.

Para `admin`, `staff` y `parent`, también es obligatorio `email`, que debe tener formato válido.

La operación inserta la fila común en `users` (incluido el hash bcrypt de la contraseña y `full_name`) y después la especialización del rol en `Admn`, `Staff`, `Student` o `Parents`, con los datos de email o accesibilidad que correspondan. Se confirman ambas inserciones conjuntamente. El username es único en la tabla común, por lo que no puede repetirse entre roles. Según el conflicto, se devuelve `USERNAME_TAKEN` o `EMAIL_TAKEN` (HTTP 409); otros errores de creación usan `USER_CREATE_FAILED` (HTTP 500).

### `GET /users` y `GET /users?role=<rol>`

Solo administrador. Sin `role`, reúne usuarios de las cuatro tablas hijas; con `role`, filtra a un solo rol. Cada resultado contiene username, full name, rol y email cuando el rol tiene correo. Para estudiantes también incluye sus atributos de accesibilidad. La lista se ordena por username. No devuelve contraseñas ni tokens.

Un rol inválido devuelve `INVALID_ROLE` (HTTP 400); fallos de consulta devuelven `USER_LIST_FAILED` (HTTP 500).

### `PUT /users/{role}/{username}`

Requiere autenticación. Un administrador puede editar cualquier cuenta. Un `parent`, `staff` o `student` solo puede editar su propio perfil y no puede enviar `username`, `full_name` ni `role`. Para estudiantes, además se comprueba que `stud_access_profile_mod` sea verdadero; si es falso, se rechaza la edición propia. Un admin puede editar todos los campos autorizados y cualquier usuario.

El JSON acepta campos opcionales: `username`, `role`, `full_name`, `password`, `email` y campos `stud_access_*`. No se aceptan propiedades extra. Debe haber al menos un campo que modificar. El username y el nombre completo aplican validaciones iguales a las de creación; la contraseña está limitada a 72 bytes.

Cambiar username o rol convierte la identidad/especialización: actualiza username común cuando corresponda, crea la nueva fila hija y elimina la especialización anterior. El username debe seguir siendo globalmente único. Cambiar username también actualiza `Tasks.task_creator` y `Alt_Tasks.alt_task_creator`. Cambiar rol o username invalida el token activo. Cambiar contraseña también lo invalida. Cambiar solo `full_name`, email o accesibilidad no lo invalida.

Al pasar un usuario a `student`, deben suministrarse todos los campos de accesibilidad. Los roles con email deben conservar o recibir un email válido; estudiantes no admiten email. No se puede degradar al único administrador ni eliminar el único administrador mediante cambio de rol. La respuesta de éxito devuelve el nuevo `username` y `role`.

Errores relevantes: `PROFILE_UPDATE_DENIED` (403), `USER_NOT_FOUND` (404), `USERNAME_TAKEN`/`EMAIL_TAKEN` (409), `NO_UPDATE_FIELDS`, `INVALID_REQUEST`, `EMAIL_REQUIRED`, `EMAIL_UNAVAILABLE` y `LAST_ADMIN` (400 según catálogo).

### `DELETE /users/{role}/{username}`

Solo administrador. Borra la cuenta de `users` únicamente si existe la especialización indicada en la tabla hija del rol. Las claves foráneas determinan la eliminación de los datos dependientes. Para administradores, bloquea la tabla de administradores y comprueba que no sea el último antes de borrar. Si la cuenta no existe devuelve `USER_NOT_FOUND`; si se intenta borrar el último admin, `LAST_ADMIN`. El token de la cuenta borrada deja de poder validarse al desaparecer el usuario.

## Asociaciones alumno–tutor/personal

Todas las rutas usan el prefijo `/student-links`. Las relaciones se almacenan en `par_stud` (tutores, rol `parent`) y `staff_stud` (personal, rol `staff`). No crean ni borran cuentas.

### `POST /student-links/students/{student_username}/parents/{parent_username}`

Solo administrador. Comprueba que existen el alumno y el tutor en `users` y sus tablas de rol. Inserta la relación alumno–tutor. Si ya existe, `ON CONFLICT DO NOTHING` evita duplicarla; la respuesta sigue siendo exitosa e indica `association_created: false`. Si se creó, indica `true`.

### `DELETE /student-links/students/{student_username}/parents/{parent_username}`

Solo administrador. Elimina únicamente esa relación de `par_stud`. Si no existía, devuelve `ASSOCIATION_NOT_FOUND` (HTTP 404). No borra el alumno, el tutor ni otras relaciones.

### `POST /student-links/students/{student_username}/staff/{staff_username}`

Solo administrador. Comprueba que existen el alumno y el miembro del personal, e inserta en `staff_stud`. Evita duplicados de la misma forma que el endpoint de tutores e informa con `association_created`.

### `DELETE /student-links/students/{student_username}/staff/{staff_username}`

Solo administrador. Elimina solamente esa relación de `staff_stud`; una relación inexistente devuelve `ASSOCIATION_NOT_FOUND`.

### `GET /student-links/students/{student_username}`

Solo administrador. Devuelve dos listas actuales: `parents` y `staff`. Cada entrada incluye username, full name y email del usuario relacionado. Si no existe el alumno, devuelve `ASSOCIATED_ENTITY_NOT_FOUND` (HTTP 404). Las listas reflejan las filas de asociación vigentes en la base de datos.

### `GET /student-links/parents/{parent_username}/students`

Requiere token. Un tutor consulta su propio listado; un administrador puede consultar cualquier tutor. Otros roles, o un tutor que intente consultar otro username, reciben `ASSOCIATION_ACCESS_DENIED` (HTTP 403). Devuelve `username` y `full_name` de cada alumno asociado, ordenados por username. Sin asociaciones, devuelve `students: []`.

### `GET /student-links/staff/{staff_username}/students`

Igual que la consulta de tutores, pero para personal. Staff consulta su propio listado; admin puede consultar cualquiera. Devuelve `username` y `full_name`; un resultado vacío es `students: []`.

Las asociaciones también son una condición de autorización en las operaciones de tareas individuales: quitar una relación impide a ese tutor o miembro del personal seguir creando, editando alternativa o retirando tareas de ese alumno mediante esas rutas.

## Tareas individuales de alumnos

Prefijo `/student-tasks`. En estas rutas solo pueden actuar usuarios autenticados con rol `parent` o `staff`. El administrador y el estudiante no están autorizados por este router.

### `POST /student-tasks/students/{student_username}`

Responde HTTP 201. El JSON requiere `task_title`, `task_date` y `task_index`. El título se recorta y debe contener entre 1 y 100 caracteres; el índice debe ser un entero no negativo. Son opcionales `task_start_hour` (hora local sin zona), `task_duration` (entero positivo) y `alt_task_id_fk` (entero positivo). No admite propiedades adicionales.

El alumno debe existir y el usuario autenticado debe estar asociado a él según su rol. Si se indica hora, las tareas de `staff` deben comenzar desde las 09:00 hasta antes de las 15:00; las de `parent` deben quedar fuera de ese intervalo. Si se indica alternativa, esta debe existir y no estar ya enlazada a otra tarea.

La operación inserta en `Tasks` con `task_creator` igual al username del creador y `task_finished = false`, añade el subtipo `Generic_Task` y crea la asignación `stud_task` con alumno, tarea, índice y fecha. Todo se confirma en una transacción. La respuesta incluye datos de tarea y de asignación.

La hora y duración son opcionales y el backend actual no exige que se elija exactamente una modalidad. La regla horaria solo puede comprobarse si se envía `task_start_hour`; si se omite, no se aplica.

### `PUT /student-tasks/{task_id}/alternative`

Requiere JSON con `alt_task_id_fk`: un entero positivo para asociar una alternativa o `null` para quitarla. Solo permite modificar una tarea que haya creado el usuario autenticado y que esté asignada al menos a un alumno que siga asociado a él. La alternativa debe existir y no estar asignada a otra tarea. Devuelve los datos actualizados de la tarea. Si la alternativa está ocupada, devuelve `ALTERNATIVE_TASK_ALREADY_ASSIGNED` (HTTP 409); si la tarea principal no es accesible o no existe, devuelve `TASK_NOT_FOUND`.

### `DELETE /student-tasks/students/{student_username}/{task_id}?task_date=AAAA-MM-DD&task_index=N`

El `task_date` y `task_index` de la query identifican una asignación concreta de la tarea en la agenda del alumno. Comprueba que el alumno exista, que siga asociado al usuario y que exista una fila `stud_task` con la combinación completa de alumno, tarea, fecha e índice.

Si se conoce la hora de inicio, un tutor no puede quitar una tarea dentro del horario escolar y el personal no puede quitarla fuera del horario escolar (09:00 inclusive, 15:00 exclusive). Si la hora es `NULL`, se omite esa regla. La operación elimina únicamente la fila `stud_task`, por lo que deja de estar asignada a ese alumno, pero no borra la tarea de `Tasks` ni el registro genérico. Devuelve los identificadores de la asignación quitada.

## Clases

Prefijo `/classes`. Las clases se guardan en `Class`; `class_staff` asocia personal a clases y `class_stud` inscribe alumnos. El personal solo puede consultar o administrar una clase si está asignado a ella. Solo el administrador gestiona el catálogo de clases y asigna personal.

### `POST /classes`

Solo administrador. JSON `{ "class_name": "..." }`. El nombre se recorta, debe quedar no vacío y no superar 50 caracteres. Crea la clase; si ya existe, devuelve `CLASS_NAME_TAKEN` (HTTP 409). Responde HTTP 201.

### `GET /classes`

Requiere token de staff. Devuelve las clases asignadas a ese miembro del personal y el número de alumnos inscritos en cada una. Otros roles reciben `CLASS_ACCESS_DENIED` (HTTP 403). Puede devolver una lista vacía.

### `GET /classes/{class_name}`

Requiere token de staff asignado a esa clase. Devuelve el nombre, los alumnos inscritos (`username`, `full_name`) y el personal asignado (`username`, `full_name`). Una clase inexistente da `CLASS_NOT_FOUND`; una clase existente a la que ese staff no está asignado da `CLASS_ACCESS_DENIED`.

### `PUT /classes/{current_class_name}`

Solo administrador. Recibe el nuevo nombre en `{ "class_name": "..." }`. Renombra la clase; las relaciones conservan el vínculo mediante la clave foránea. Si la clase original no existe, devuelve `CLASS_NOT_FOUND`; si el nombre nuevo ya existe, `CLASS_NAME_TAKEN`.

### `DELETE /classes/{class_name}`

Solo administrador. Elimina la clase y sus asociaciones de alumnos y personal (según las claves foráneas). No elimina las cuentas de alumnos ni de personal. Si no existe, devuelve `CLASS_NOT_FOUND`.

### `POST /classes/{class_name}/staff/{staff_username}`

Solo administrador. Comprueba la clase y que la cuenta exista como miembro de `Staff`, y la añade a `class_staff`. La inserción repetida no crea duplicado y responde correctamente. Errores: `CLASS_NOT_FOUND` o `CLASS_STAFF_NOT_FOUND`.

### `POST /classes/{class_name}/students/{student_username}`

Requiere staff autenticado y asignado a la clase. Inscribe al alumno en `class_stud`. Comprueba que sea un alumno existente y que no esté inscrito en otra clase. Repetir la asignación a la misma clase no genera otra fila. Responde HTTP 201. Si ya está en otra clase, `STUDENT_ALREADY_IN_CLASS` (HTTP 409); si no existe como alumno, `TASK_STUDENT_NOT_FOUND`.

### `DELETE /classes/{class_name}/students/{student_username}`

Requiere staff asignado a la clase. Elimina solo la inscripción indicada. Si la relación no existe, devuelve `ASSOCIATION_NOT_FOUND`. No elimina al alumno ni sus tareas.

### `POST /classes/{class_name}/tasks`

Requiere staff asignado a la clase. Recibe los mismos campos de tarea que la creación individual: título, fecha e índice obligatorios; hora, duración y alternativa opcionales. Valida título/hora y alternativa como el endpoint individual. El personal solo puede indicar una hora entre 09:00 y antes de las 15:00.

La clase debe tener al menos un alumno inscrito; de lo contrario devuelve `CLASS_HAS_NO_STUDENTS`. Crea una sola tarea con `task_creator` igual al username del miembro del personal, un registro `Generic_Task` y una fila `stud_task` por cada alumno inscrito, con la fecha e índice solicitados. La operación es transaccional y responde HTTP 201 con la lista de alumnos incluidos. El backend actual tampoco exige escoger entre hora y duración.

## Errores y lectura del estado

Los códigos y textos públicos se mantienen en `proyectFastAPI/errors.py`. En general, un código 4xx representa credenciales/permisos/entidades/datos no válidos; un 5xx representa fallo interno. No se deben interpretar errores de PostgreSQL directamente desde el frontend: la API traduce errores conocidos al catálogo y oculta los detalles internos.

Las listas y consultas de asociaciones, clases y tareas se generan desde las relaciones actuales de la base de datos. Las rutas de asociación y de clase no incluyen confirmaciones de interfaz; cualquier diálogo de confirmación antes de una operación destructiva debe implementarse en el cliente antes de enviar la petición.

## Interacciones entre módulos

1. **Identidad y especialización:** `users` contiene los campos comunes (`username`, `full_name`, contraseña y token); `Admn`, `Staff`, `Student` y `Parents` determinan el rol y mantienen campos propios. Login y autorización unen la cuenta común con la especialización del rol.
2. **Sesiones y cambios de usuario:** las rutas protegidas consultan el token guardado en `users`. Editar contraseña, username o rol revoca ese token. El login siguiente genera uno nuevo.
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
