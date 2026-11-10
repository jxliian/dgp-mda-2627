# Petición al equipo de backend — Iteración 1

> **Estado: resuelta casi por completo (10/11/2026).** El equipo añadió los dos
> `GET` que se piden aquí, además de `DELETE /classes/{aula}/staff/{usuario}`.
> Verificado contra la API: SCRUM-31, SCRUM-41 y SCRUM-333 funcionan de
> principio a fin. **Queda solo el punto 3**, el aula del alumno (SCRUM-325).
> El resto del documento se conserva como registro de lo que se pidió y por qué.

---

# Petición al equipo de backend — Iteración 1

Resumen en una línea: **falta un `GET` que devuelva las tareas de un alumno**.
Es lo único que bloquea al frontend. Todo lo demás de la API de `main` nos
sirve tal y como está.

## Por qué

La API permite crear y borrar tareas individuales, pero no listarlas:

| Operación | Endpoint | Existe |
|---|---|---|
| Crear tarea para un alumno | `POST /student-tasks/students/{alumno}` | Sí |
| Crear tarea propia | `POST /student-tasks/me` | Sí |
| Borrar tarea de un alumno | `DELETE /student-tasks/students/{alumno}/{id}` | Sí |
| Borrar tarea propia | `DELETE /student-tasks/me/{id}` | Sí |
| **Listar las tareas de un alumno** | — | **No** |

Sin la lista, la interfaz no puede ofrecer qué tarea borrar ni enseñar la
agenda. Esto deja a medias cuatro historias del Sprint 1:

- **SCRUM-31** Como tutor, quiero eliminar una tarea de la agenda del alumno.
- **SCRUM-41** Como personal, quiero eliminar una tarea de la agenda del alumno.
- **SCRUM-333** Como alumno, quiero eliminar mis propias tareas.
- **SCRUM-325** Como alumno, pertenezco a una clase (ver el apartado 3).

## De dónde viene el hueco

Conviene decirlo claro para que nadie lo lea como un reproche: **el backend
está completo respecto a lo que se le pidió**. El hueco está antes, en la
especificación.

- `GuiaBackend.md` describe 32 rutas. La única que lista tareas es
  `GET /classes/{class_name}/tasks`. Un `GET` de la agenda de un alumno no
  aparece en ningún punto del documento.
- Ese `GET` no existe en `main`, ni en `cambios-backend`, ni en ningún commit
  de la historia del repositorio.
- Y más arriba todavía: **el Product Backlog del Sprint 1 no tiene ninguna
  historia de «consultar las tareas de un alumno»**. Sí tiene «consultar las
  tareas de una clase entera» (SCRUM-337), que es la que se implementó.

El detalle que lo delata: `DELETE /student-tasks/me/{task_id}?task_date=...`
exige conocer el identificador de la tarea y su fecha. Con las rutas
actuales no hay ninguna forma de que un cliente llegue a conocer esos dos
datos. La operación de borrado quedó especificada sin su consulta.

Es material para la revisión de sprint: tres historias de borrado dependían
de una de consulta que nadie escribió.

## 1. `GET /student-tasks/me`

Agenda del alumno autenticado para un día.

```
GET /student-tasks/me?task_date=2026-11-10
Authorization: Bearer <token>
```

- Solo rol `student`; en otro caso `TASK_CREATOR_REQUIRED`, igual que hace ya
  `POST /student-tasks/me`.
- `task_date` obligatorio, formato `date` (el mismo tipo que usáis en
  `CreateTaskRequest`).

## 2. `GET /student-tasks/students/{student_username}`

La misma agenda, vista por quien acompaña al alumno.

```
GET /student-tasks/students/pablo?task_date=2026-11-10
Authorization: Bearer <token>
```

- Roles `staff` y `parent`, con la **misma comprobación de asociación que ya
  tenéis**: `_has_student_relationship(db, rol, usuario, student_username)` en
  `studs_tasks_db.py`. Si no hay relación, `TASK_STUDENT_NOT_ASSOCIATED`.
- Si el alumno no existe, `TASK_STUDENT_NOT_FOUND`.

## Respuesta de ambos

Exactamente la forma que ya devuelve `list_class_tasks`, cambiando la clave de
cabecera:

```json
{
  "errorCode": 0,
  "details": "successful",
  "student_username": "pablo",
  "tasks": [
    {
      "task_id": 12,
      "task_title": "Preparar la mochila",
      "task_date": "2026-11-10",
      "task_start_hour": "09:00:00",
      "task_duration": 15,
      "task_creator": "lucia",
      "task_finished": false,
      "task_index": 0,
      "alt_task_id_fk": null,
      "class_name_fk": "Aula de la autonomía"
    }
  ]
}
```

`task_index` y `class_name_fk` salen gratis: son columnas de `stud_task`. Nos
sirven para ordenar la agenda y para distinguir una tarea de aula de una
individual, pero si os resultan incómodas podemos vivir sin ellas.

Consulta de partida, por si ahorra tiempo (sigue el patrón de
`list_class_tasks`):

```sql
SELECT t.task_id, t.task_title, t.task_start_hour, t.task_duration,
       t.task_creator, t.task_finished, t.alt_task_id_fk,
       a.task_date, a.task_index, a.class_name_fk
FROM stud_task a
JOIN Tasks t ON t.task_id = a.task_id_fk
WHERE a.stud_usr_fk = :student AND a.task_date = :task_date
ORDER BY a.task_index, t.task_start_hour NULLS LAST, t.task_id
```

Donde la pongáis es cosa vuestra; lo natural sería `studs_tasks_db.py` junto al
resto, y el endpoint en `studs_tasks_backend.py` con `_run_db_operation`.

## 3. Opcional: el aula del alumno (SCRUM-325)

Un alumno no puede consultar `/classes` (reservado a administración y
personal) y no hay otra forma de saber a qué aula pertenece. Cualquiera de
estas dos nos vale, la que os resulte más barata:

- Incluir `class_name` en la respuesta de `POST /auth/login` cuando el rol es
  `student`.
- O un `GET /classes/me` que devuelva solo el aula del alumno autenticado.

Es la menos urgente de las tres: sin ella se pierde una insignia informativa,
no una función.

## Lo que NO os pedimos

- **Nada de CORS.** Ejecutamos la aplicación como programa de escritorio
  Linux, que no pasa por el navegador. El problema de origen desaparece.
- **Ninguna tabla nueva ni migración.** Las dos consultas salen de `stud_task`
  y `Tasks`, que ya existen.
- **Ningún cambio en vuestra forma de trabajar.** Nada de SQL fuera de la capa
  `*_db`, nada de endpoints paralelos.
- **Nada sobre pasos, imágenes ni progreso de tareas.** Eso es Iteración 2; ya
  lo hablaremos cuando toque.

## Mientras tanto, el frontend no está parado

El cliente consulta `/openapi.json` al iniciar sesión y adapta la pantalla a
lo que el servidor sabe hacer. Hoy, contra `main`:

| El servidor no… | La aplicación… |
|---|---|
| lista agendas | lo explica y mantiene «Crear tarea» |
| guarda el progreso | oculta «He terminado la tarea» |
| guarda la descripción | no pide descripción en el editor |
| tiene directorio de fotos | ofrece entrar con usuario y PIN |

En cuanto los dos `GET` estén desplegados, la lista se activa sola. **No hace
falta tocar ni una línea del frontend ni coordinar un despliegue conjunto.**
