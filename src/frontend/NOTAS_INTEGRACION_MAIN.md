# Integración de main en iteracion1 · 10/11/2026

Se integró `main` en `iteracion1` mediante un merge tomando como origen
`2ba75b44629bc8ab58327b1bde7c91db9b24328b`. El backend de
`iteracion1` es idéntico al de ese commit: no se han realizado cambios propios
en backend. Las correcciones nuevas están dentro de `src/frontend`.

## Correcciones de frontend

- `GET /users/me` devuelve los campos de la cuenta en la raíz del JSON. El
  cliente ya lee ese formato, conserva el rol y carga los ajustes y permisos
  reales antes de abrir la sesión. También admite el formato anterior con `user`.
- Administración utiliza `POST` y `DELETE
  /classes/{class_name}/students/{student_username}`, igual que el personal.
  Se ha retirado la dependencia de la ruta inexistente `/admin/classes/...`.
- El personal se asigna desde la edición del aula y, ahora también, desde
  «Gestionar asociaciones» en su ficha, seleccionando un aula. Los alumnos
  asociados se vuelven a consultar después de guardar.
- El acceso del alumno es más ancho, con dibujos y casillas mayores, un botón
  de borrado de ancho completo y sin opción de escribir la contraseña.
- «Ajustes» solo aparece al alumno si `stud_access_profile_mod` está activado.
  Su pantalla conserva la accesibilidad y no ofrece cambiar contraseña ni foto.
  El guardado envía únicamente los ajustes que cambian, sin permisos.
- En administración, las contraseñas nuevas o modificadas de un alumno deben
  contener solo cifras `0–9`, que corresponden a los dibujos del acceso.
  **Las cuentas existentes con contraseña alfanumérica necesitan que
  administración la cambie por una numérica.** No se han alterado credenciales.

## Personal asociado debajo del selector de administración

La API permite asignar y retirar personal con `POST` y `DELETE
/classes/{class_name}/staff/{staff_username}`. Sin embargo, `list_classes` y
`get_class`, en `clases/clases_db.py`, devuelven los alumnos pero no el personal
asignado.

El frontend muestra ahora el personal asociado debajo del selector y permite
retirarlo. Si falta `staff` en la respuesta, administración consulta
`GET /student-links/students/{student_username}` para uno de los alumnos del
aula. Como cada alumno solo puede pertenecer a una clase, sus asociaciones
identifican exactamente el personal de esa clase. Esto permite recuperar las
asignaciones existentes al reabrir aulas con alumnos, sin cambios de backend.

**Límite: aulas vacías.** Ninguna ruta permite recuperar su personal. En ese
caso se muestran las asignaciones confirmadas en la sesión actual, con un aviso
de que el listado puede estar incompleto. No se presenta una lista desconocida
como si fuera un aula sin personal, ni se muestra un contador falso de cero.
Las asignaciones recordadas se descartan al cambiar o cerrar la sesión.

Para eliminar ese límite, backend tendría que devolver `staff` también para
aulas vacías, por ejemplo:

```json
{
  "errorCode": 0,
  "class_name": "Aula 1",
  "students": [],
  "staff": [{"username": "lucia", "full_name": "Lucía Martín"}]
}
```

El frontend utiliza directamente `staff` cuando existe. No se ha modificado
ningún endpoint, tabla ni permiso de backend.

### Comprobación posterior sobre el entorno local

Se ha consultado la base de datos en una transacción de solo lectura: hay
asignaciones guardadas en `class_staff`, incluidas las del aula de prueba.
Invocar `get_class` en esa misma transacción devuelve `class_name` y `students`,
sin `staff`. El problema comprobado es que la consulta omite las asignaciones;
no se ha reproducido un error de escritura ni se han modificado datos para
realizar el diagnóstico.

## Política final: solo administración añade alumnos

La vista del personal dispone de una lista paginada de sus alumnos, con
búsqueda por nombre o usuario, sin distinguir mayúsculas ni tildes. La búsqueda
se aplica a todos los resultados antes de paginar y vuelve a la primera página
cuando cambia.

Por indicación final, la vista de personal solo permite consultar y gestionar
alumnos ya matriculados, incluida su retirada. Se han eliminado el desplegable
de candidatos, la entrada de usuario y todos los botones de alta. El cliente
real y el de demostración rechazan nuevas matrículas de personal antes de enviar
la petición. Administración conserva el alta desde el editor de aulas.

La falta de una consulta de alumnos sin aula para personal ya no bloquea ningún
recorrido solicitado: ese perfil no debe añadir alumnos. No se han cambiado
endpoints ni permisos de backend.

## Totales de alumnos actualizados

Las altas y bajas de matrícula y los cambios de personal invalidan las listas de
aulas abiertas mediante `classroomVersion`. Al regresar a las aulas del personal
también se repite la consulta. Administración recarga sus listas al volver de un
editor incluso si se ha usado «Volver» o «Cancelar», porque las asociaciones
pueden haberse guardado antes de cerrar el formulario.

Los contadores usan `student_count` cuando el servidor lo devuelve y, en el
detalle, el tamaño de la lista de alumnos. Se muestran también los totales dentro
del aula. Las pruebas recorren altas y bajas y comprueban el número al volver.

## Boceto de tarea (opcional)

Se ha revisado `docs/Pantallas/Alumno/Vista_de_Tarea_(Alumno).png`. Su recorrido
con pasos, imágenes y reproducción corresponde al alcance posterior que consta
en la documentación de Iteración 1. El backend actual no expone los campos de
pasos ni la ruta de progreso que contempla el cliente de demostración. No se ha
implementado ese rediseño opcional ni se ha ampliado el backend.

## Comprobación

`test/main_contract_test.dart` utiliza respuestas HTTP con el formato de `main`
para verificar la lectura de perfiles, permisos, guardado de accesibilidad y
asignaciones desde administración. Las pruebas de recorrido comprueban también
el acceso visual y el borrado de la contraseña; `sin_scroll_test.dart` verifica
que el acceso ampliado sigue cabiendo en tablet de 1280 × 900.

Estas pruebas no sustituyen una comprobación con la base de datos del centro.

Validación inicial: `flutter analyze` sin incidencias, las 59 pruebas de
`flutter test` superadas y `flutter build web` completado. La comprobación
opcional de WebAssembly avisa de incompatibilidades en la dependencia existente
`flutter_tts`; la compilación web convencional termina correctamente.

Validación actual: `flutter analyze` sin incidencias y las 66 pruebas superadas.
Se cubren búsqueda y navegación en tablet y móvil, recuperación del personal
desde asociaciones, altas desde administración y totales después de retirar
alumnos. También se comprueba que personal no tiene controles de alta y que el
cliente no envía peticiones de nueva matrícula desde ese perfil.
