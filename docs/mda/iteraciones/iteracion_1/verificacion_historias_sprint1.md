# Verificación de las 30 historias del Sprint 1

Rama `iteracion1`. El backend es **exactamente el de `main`**, sin una sola
línea modificada (`git diff main -- src/backend/` sale vacío). Todo lo que
sigue se ha comprobado contra esa API levantada en local.

Leyenda: **OK** operativa de principio a fin · **Parcial** la acción existe en
el servidor pero falta un `GET` para poder usarla desde la interfaz.

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

## Personal del centro

| Historia | Endpoint de `main` | Estado |
|---|---|---|
| SCRUM-21 Consultar mis alumnos | `GET /student-links/staff/{usuario}/students` | OK |
| SCRUM-326 Consultar mis clases | `GET /classes` | OK |
| SCRUM-327 Apuntar alumno a clase | `POST /classes/{aula}/students/{alumno}` | OK |
| SCRUM-328 Eliminar alumno de clase | `DELETE /classes/{aula}/students/{alumno}` | OK |
| SCRUM-33 Crear tarea para un alumno | `POST /student-tasks/students/{alumno}` | OK |
| SCRUM-41 Eliminar tarea de la agenda del alumno | `DELETE /student-tasks/students/{alumno}/{id}` | **Parcial** |
| SCRUM-321 Crear tarea para la clase | `POST /classes/{aula}/tasks` | OK |
| SCRUM-337 Consultar tareas de la clase | `GET /classes/{aula}/tasks` | OK |
| SCRUM-338 Modificar tareas de la clase | `PUT /classes/{aula}/tasks/{id}` | OK |
| SCRUM-336 Eliminar tarea de la clase | `DELETE /classes/{aula}/tasks/{id}` | OK |

## Tutor y familia

| Historia | Endpoint de `main` | Estado |
|---|---|---|
| SCRUM-20 Consultar mis alumnos | `GET /student-links/parents/{tutor}/students` | OK |
| SCRUM-26 Crear tarea para un alumno | `POST /student-tasks/students/{alumno}` | OK |
| SCRUM-31 Eliminar tarea de la agenda del alumno | `DELETE /student-tasks/students/{alumno}/{id}` | **Parcial** |

## Alumno

| Historia | Endpoint de `main` | Estado |
|---|---|---|
| SCRUM-329 Tiene foto de perfil | `GET`/`PUT /users/students/me/avatar` | OK |
| SCRUM-332 Crear mis propias tareas | `POST /student-tasks/me` | OK |
| SCRUM-333 Eliminar mis propias tareas | `DELETE /student-tasks/me/{id}` | **Parcial** |
| SCRUM-325 Pertenezco a una clase | — | **Parcial** |

## Lo que falta en el servidor y por qué

La API de `main` **no tiene ningún `GET` que devuelva las tareas de un
alumno**. Puede crear y borrar, pero no listar. Sin esa lista, la interfaz no
puede ofrecer al usuario qué tarea borrar, así que SCRUM-31, SCRUM-41 y
SCRUM-333 se quedan a mitad de camino: la operación existe y funciona si se
conoce el identificador, pero no hay forma razonable de elegirlo.

SCRUM-325 depende de lo mismo: un alumno no puede consultar `/classes`
(reservado a administración y personal) ni existe un endpoint que le diga a
qué aula pertenece.

**Dos endpoints resolverían las cuatro historias:**

```
GET /student-tasks/me?task_date=AAAA-MM-DD
GET /student-tasks/students/{student_username}?task_date=AAAA-MM-DD
```

Devolviendo lo mismo que ya produce `list_class_tasks` para las aulas. El
frontend los detecta solo: consulta `/openapi.json` al iniciar sesión y
habilita la lista en cuanto aparezcan, sin tocar una línea de pantalla.

Un tercero, opcional, cubriría SCRUM-325: cualquier forma de que un alumno
sepa su aula (por ejemplo incluir `class_name` en la respuesta del login).

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
