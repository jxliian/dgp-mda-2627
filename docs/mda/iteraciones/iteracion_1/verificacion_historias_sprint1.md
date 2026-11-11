# Verificación de las 32 historias del Sprint 1

Rama `iteracion1`. El backend es **exactamente el de `main`**, sin una sola
línea modificada (`git diff main -- src/backend/` sale vacío). Todo lo que
sigue se ha comprobado contra esa API levantada en local.

Verificado el 10/11/2026 ejecutando contra la API las mismas llamadas que hace
la aplicación. **Las 32 historias están cubiertas por el frontend.**

El alcance del sprint cambió ese día: pasó de 30 a 32 actividades. Se retiró
SCRUM-325 («Alumno pertenece a clase») y se añadieron SCRUM-27, SCRUM-36 y
SCRUM-43.

## Autenticación

| Historia | Dónde está | Estado |
|---|---|---|
| SCRUM-12 Iniciar sesión con credenciales | Portada → `login_screen.dart`; `POST /auth/login` | OK |
| SCRUM-13 Cerrar sesión | Pie de página, botón «Salir»; `POST /auth/logout` | OK |

## Administración

| Historia | Endpoint de `main` | Estado |
|---|---|---|
| SCRUM-8 Crear usuarios | `POST /users` | OK |
| SCRUM-9 Modificar datos y credenciales | `PUT /users/{role}/{username}` | OK |
| SCRUM-10 Eliminar usuarios | `DELETE /users/{role}/{username}` | OK |
| SCRUM-11 Consultar cuentas y roles | `GET /users` | OK |
| SCRUM-14 Asociar alumno con tutor | `POST /student-links/students/{a}/parents/{t}` | OK |
| SCRUM-23 Desasociar | `DELETE /student-links/students/{a}/parents/{t}` | OK |
| SCRUM-16 Consultar alumnos de un tutor | `GET /student-links/students/{a}` | OK |
| SCRUM-322 Crear clase | `POST /classes` | OK |
| SCRUM-323 Borrar clase | `DELETE /classes/{aula}` | OK |
| SCRUM-324 Editar clase | `PUT /classes/{aula}` | OK |
| SCRUM-331 Asignar profesor a clase | `POST /classes/{aula}/staff/{usuario}` | OK |
| SCRUM-329 Cambiar la foto de perfil de los usuarios | `PUT /users/students/{alumno}/avatar` | OK |

## Personal del centro

| Historia | Endpoint de `main` | Estado |
|---|---|---|
| SCRUM-21 Consultar mis alumnos | `GET /student-links/staff/{usuario}/students` | OK |
| SCRUM-326 Consultar mis clases | `GET /classes` | OK |
| SCRUM-327 Apuntar alumno a clase | `POST /classes/{aula}/students/{alumno}` | OK |
| SCRUM-328 Eliminar alumno de clase | `DELETE /classes/{aula}/students/{alumno}` | OK |
| SCRUM-33 Crear tarea para un alumno | `POST /student-tasks/students/{alumno}` | OK |
| SCRUM-36 Consultar la agenda de un alumno por fecha | `GET /student-tasks/students/{alumno}?task_date=` | OK |
| SCRUM-41 Eliminar tarea de la agenda del alumno | `GET` + `DELETE /student-tasks/students/{alumno}` | OK |
| SCRUM-321 Crear tarea para la clase | `POST /classes/{aula}/tasks` | OK |
| SCRUM-337 Consultar tareas de la clase | `GET /classes/{aula}/tasks` | OK |
| SCRUM-338 Modificar tareas de la clase | `PUT /classes/{aula}/tasks/{id}` | OK |
| SCRUM-336 Eliminar tarea de la clase | `DELETE /classes/{aula}/tasks/{id}` | OK |

## Tutor y familia

| Historia | Endpoint de `main` | Estado |
|---|---|---|
| SCRUM-20 Consultar mis alumnos | `GET /student-links/parents/{tutor}/students` | OK |
| SCRUM-26 Crear tarea para un alumno | `POST /student-tasks/students/{alumno}` | OK |
| SCRUM-27 Consultar la agenda de un alumno por fecha | `GET /student-tasks/students/{alumno}?task_date=` | OK |
| SCRUM-31 Eliminar tarea de la agenda del alumno | `GET` + `DELETE /student-tasks/students/{alumno}` | OK |

## Alumno

| Historia | Endpoint de `main` | Estado |
|---|---|---|
| SCRUM-332 Crear mis propias tareas | `POST /student-tasks/me` | OK |
| SCRUM-43 Crear mis tareas en mi agenda personal | `POST /student-tasks/me` | OK |
| SCRUM-333 Eliminar mis propias tareas | `GET` + `DELETE /student-tasks/me` | OK |

SCRUM-43 y SCRUM-332 describen la misma acción con distintas palabras; las
cubre el botón «Añadir mi tarea» de la agenda.

> **Las 32 historias operativas.** Verificado el 10/11/2026 contra la API.

## Pendiente de mover en el tablero

SCRUM-27 y SCRUM-36 figuran en Jira como **Por hacer**, pero están
implementadas y verificadas: son la agenda de un alumno para una fecha, con
selector de día y navegación entre semanas, accesible desde la ficha del
alumno tanto para el tutor como para el personal. Se crearon al añadir los
`GET` y nadie las movió. Conviene revisar sus criterios de aceptación antes de
pasarlas a revisión.

## Lo que el equipo de backend resolvió

Todo lo que pedía `peticion_backend.md` está entregado:

| Fecha | Qué llegó | Qué desbloquea |
|---|---|---|
| 10/11 | `DELETE /classes/{aula}/staff/{usuario}` | Retirar profesorado del aula |
| 10/11 | `GET /student-tasks/me` y `GET /student-tasks/students/{alumno}` | SCRUM-31, 41 y 333 |
| 10/11 | `/classes` y `/classes/{aula}` admiten peticiones sin sesión; el avatar también, si el alumno está matriculado | El acceso del alumno por foto (clase, alumno y PIN) |

La última llegó por un camino distinto al que pedimos: en vez de un endpoint
nuevo de directorio, hicieron opcional la autenticación en los que ya existían
(`get_optional_current_user`). Sin sesión, `/classes` devuelve solo los nombres
y `/classes/{aula}` el alumnado con su `avatar_url`. El cliente construye el
directorio con esas dos llamadas.

Con ellos quedaron además cubiertas SCRUM-27 y SCRUM-36, que entraron en el
sprint ese mismo día.

Comprobado con el código real del cliente contra la API en marcha:

```
AULA "Aula de la autonomía" -> 2 alumnos
   Ana García     foto: /users/students/ana/avatar-image
   Pablo García   foto: /users/students/pablo/avatar-image
FOTO de ana: 283 bytes
```

Y la subida de la foto del alumno (SCRUM-329), que la nueva redacción
subraya:

```
PUT /users/students/me/avatar  -> errorCode 0, avatar_url: /users/students/pablo/avatar-image
GET /users/students/me/avatar  -> HTTP 200, image/png
```

## SCRUM-329: la foto la cambia administración

La historia pasó de «el alumno añade su foto» a «como administrador quiero
cambiar la foto de perfil de los usuarios», y el backend la siguió el
10/11/2026: `PUT /users/students/{alumno}/avatar` reservado a administración,
la subida propia del alumno retirada, y una foto predeterminada al crear la
cuenta.

El frontend va en consecuencia: el botón «Cambiar la foto» está en el editor
de usuario de administración, y los ajustes del alumno explican que su foto la
cambia el centro. Comprobado contra la API:

```
admin sube la foto de pablo -> errorCode 0, media_type image/png
se recupera                 -> HTTP 200, image/png
un alumno intenta subirla   -> HTTP 403
```

## Lo que el backend resolvió el 10/11/2026

Comprobado contra la API: un alumno ya lee su ficha en `GET /users/me` (llegan
las 13 claves `stud_access_*`), administración ya matricula alumnos y ya
asigna personal a un aula. El frontend se ha adaptado a las tres cosas.

Al adaptarlo aparecieron dos fallos propios que habrían roto la aplicación:

- `profile()` leía la ficha en `data['user']`, pero el servidor devuelve los
  campos en la raíz. Como `/users/me` no existía antes, nunca se había
  ejecutado; al aparecer la ruta, **habría roto el inicio de sesión de todos
  los perfiles**.
- Para administración se consultaba una ruta `/admin/classes/...` que no
  existe, así que la matrícula seguía apareciendo como no disponible.

## Lo que todavía falta en el backend

**`GET /classes/{aula}` no devuelve el personal del aula**, solo `students`.
La asignación funciona y se guarda —en la base de datos, `class_staff` tiene
las filas— pero no hay forma de leerla, así que la pantalla parece no haber
hecho nada. Mientras tanto, el editor muestra el personal asignado durante la
sesión y lo advierte.

Hace falta que la ficha del aula incluya su personal, por ejemplo:

```json
{ "class_name": "...", "students": [...], "staff": [...] }
```

**`GET /users` sigue respondiendo 403 al personal**, así que el buscador de
matrículas del personal solo ve a sus alumnos vinculados.

## Dos cosas que conviene vigilar## Dos cosas que conviene vigilar

1. **El directorio anónimo devuelve el nombre completo** (`full_name`), no solo
   el nombre de pila. Expone apellidos de menores sin autenticación. Merece
   quedar anotado como riesgo aceptado, o pedir que se recorte al nombre de
   pila.
2. **Un tutor autenticado no puede ver la foto de su alumno.** El permiso del
   avatar contempla anónimo, administración y personal, pero no a las familias:
   con su token recibe 403. La aplicación lo tolera y dibuja la silueta, pero
   es un descuido que merece la pena señalarles.

## Cómo se comporta la interfaz mientras tanto

No se enseñan botones que acaben en error. El cliente pregunta al servidor qué
sabe hacer y adapta la pantalla:

| Si el servidor no… | La aplicación… |
|---|---|
| lista agendas | explica que ese servidor todavía no lo permite y mantiene «Crear tarea» |
| guarda el progreso | oculta «He terminado la tarea» |
| guarda la descripción | no pide descripción en el editor |
| tiene directorio de fotos | ofrece al alumno entrar con su usuario y su PIN |
| permite matricular desde administración | indica que las matrículas las lleva el personal del aula |
| permite retirar personal de un aula | no muestra esa acción |

Está cubierto por `test/limited_server_test.dart`, que ejecuta la aplicación
contra un servidor simulado con el alcance exacto de `main`.

## Puesta en marcha

```bash
./scripts/levantar_backend.sh --con-web
```

Levanta PostgreSQL en Docker, crea el esquema desde
`docs/diseno_arquitectura/modelado_datos/CreacionTablas.sqlscript`, siembra las
cuentas de prueba con `scripts/datos_de_prueba.py` y arranca la API y el
frontend. Nada de eso vive dentro de `src/backend`.

La API de `main` no declara CORS, así que durante el desarrollo el frontend se
abre en un Chrome aparte, con perfil propio y sin esa comprobación. Para una
entrega real hay dos salidas limpias: servir frontend y API en el mismo
origen, o que el backend declare los orígenes permitidos.
