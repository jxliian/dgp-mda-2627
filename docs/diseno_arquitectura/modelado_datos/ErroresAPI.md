# Catálogo de errores de la API

La API centraliza los códigos y mensajes públicos en `src/backend/proyectFastAPI/errors.py`.
El frontend debe basar su lógica en `errorCode`; `details` es un texto legible para mostrar
al usuario o registrar. Las respuestas de error tienen esta forma:

```json
{
  "errorCode": 1001,
  "details": "Usuario o contraseña incorrectos"
}
```

Las respuestas correctas usan `errorCode: 0` y `details: "successful"`. Los códigos de
error son propios de la API y no equivalen al estado HTTP; el estado HTTP se indica aparte
en la respuesta. Por ejemplo, `errorCode: 1002` se devuelve con HTTP 401.

## Errores funcionales

| errorCode | details | HTTP | Significado y uso |
|---:|---|---:|---|
| 1001 | Usuario o contraseña incorrectos | 401 | El nombre de usuario, la contraseña o el rol no identifican una cuenta válida durante el inicio de sesión. |
| 1002 | Token ausente o inválido | 401 | Falta el token Bearer o no coincide con una sesión activa. |
| 1003 | Se requiere una sesión de administrador | 403 | La operación requiere permisos de administrador. |
| 1004 | Solo puedes consultar los alumnos asociados a tu propia cuenta | 403 | Un tutor o miembro del staff intentó consultar asociaciones de otra cuenta. |
| 1005 | La solicitud contiene datos inválidos | 422 | El cuerpo, los parámetros o la ruta no cumplen la validación del endpoint. El detalle no incluye los valores enviados. |
| 1006 | Usuario no encontrado | 404 | No existe la cuenta solicitada por nombre de usuario, o la cuenta que se iba a editar o eliminar. |
| 1007 | Los estudiantes no tienen correo electrónico | 400 | Se intentó consultar o modificar el correo de una cuenta estudiante. |
| 1008 | Usuario no encontrado por correo | 404 | No hay una cuenta del rol indicado con ese correo. |
| 1009 | Rol no válido | 400 | El rol no es uno de `admin`, `staff`, `student` o `parent`. |
| 1010 | El correo electrónico es obligatorio | 400 | Se intentó crear una cuenta de un rol que requiere correo sin proporcionar uno. |
| 1011 | No se puede eliminar ni cambiar el rol del último administrador | 400 | La operación dejaría el sistema sin administradores. |
| 1012 | Debe indicarse al menos un campo para editar | 400 | La petición de edición no contiene ningún campo modificable. |
| 1013 | No se encontró el usuario o la asociación | 404 | No se encontró el alumno, tutor o miembro del staff necesario para gestionar la asociación. |
| 1014 | La asociación no existe | 404 | Se intentó desenlazar una asociación que no está registrada. |
| 1015 | Tipo de usuario asociado no válido | 400 | La operación de asociaciones recibió un tipo distinto de tutor (`parent`) o staff. |
| 1016 | Ruta no encontrada | 404 | La URL no corresponde a ningún endpoint disponible. |
| 1017 | Se requiere una sesión de personal o tutor | 403 | La operación de tareas solo admite usuarios con rol `staff` o `parent`. |
| 1018 | Alumno no encontrado | 404 | No existe el alumno indicado en la operación de tareas. |
| 1019 | El alumno no está asociado a tu cuenta | 403 | El tutor o miembro del staff no está vinculado al alumno solicitado. |
| 1020 | La tarea alternativa no existe | 404 | No se encontró la tarea alternativa solicitada. |
| 1021 | Tarea no encontrada | 404 | No se encontró la tarea solicitada. |
| 1022 | La tarea alternativa ya está asociada a otra tarea | 409 | La tarea alternativa ya tiene una asociación incompatible. |
| 1023 | El personal solo puede programar tareas entre las 09:00 y las 15:00 | 400 | Un miembro del staff intentó crear una tarea fuera del horario permitido. |
| 1024 | Los tutores solo pueden programar tareas fuera del horario escolar | 400 | Un tutor intentó crear una tarea dentro del horario escolar. |
| 1025 | Los tutores no pueden eliminar tareas programadas durante el horario escolar | 400 | Un tutor intentó eliminar una tarea dentro del horario escolar. |
| 1026 | El personal no puede eliminar tareas programadas fuera del horario escolar | 400 | Un miembro del staff intentó eliminar una tarea fuera del horario permitido. |
| 1027 | Ya existe un usuario con ese nombre de usuario | 409 | El nombre de usuario ya está ocupado en `users`, por lo que no puede repetirse en ninguna especialización de rol. |
| 1028 | Ya existe un usuario con ese correo electrónico en el rol indicado | 409 | El correo ya está ocupado por otra cuenta del rol de destino. |
| 1029 | No tienes permiso para modificar este perfil | 403 | La cuenta intentó editar un perfil ajeno o un estudiante cuyo `stud_access_profile_mod` está desactivado intentó modificar sus datos. |

## Errores internos

Estos códigos indican un fallo del servidor. El frontend puede mostrar un mensaje genérico y
permitir reintentar; no debe esperar detalles de SQL ni de la excepción original.

| errorCode | details | HTTP | Significado |
|---:|---|---:|---|
| 1500 | Error interno del servidor | 500 | Fallo inesperado no clasificado. |
| 1501 | No se pudo consultar el usuario | 500 | Falló una consulta de usuario por nombre o correo. |
| 1502 | No se pudo consultar la lista de usuarios | 500 | Falló la consulta que lista cuentas. |
| 1503 | No se pudo actualizar la contraseña | 500 | Falló la actualización de contraseña. |
| 1504 | No se pudo crear el usuario | 500 | Falló la creación de la cuenta. |
| 1505 | No se pudo eliminar el usuario | 500 | Falló la eliminación de la cuenta. |
| 1506 | No se pudo editar el usuario | 500 | Falló la edición de la cuenta. |
| 1507 | No se pudo actualizar el avatar | 500 | Falló la actualización del avatar. |
| 1508 | No se pudo iniciar sesión | 500 | Falló el proceso de autenticación por un problema interno. |

## Comportamiento para el frontend

- Comprueba `errorCode === 0` para reconocer una respuesta correcta.
- Para un error conocido, usa `errorCode` para decidir el flujo y `details` como texto
  visible si resulta apropiado.
- Trata los códigos 15xx como fallos internos; `details` no revela el error de la base de
  datos.
- Puede haber errores HTTP producidos antes de entrar a un endpoint. También se devuelven
  con el mismo formato JSON `errorCode` y `details`.
