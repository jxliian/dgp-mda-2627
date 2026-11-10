# Pruebas del backend de AUTOVIDA

Revisado y verificado por el Gestor de Calidad ✅

Este documento describe las pruebas automáticas del backend: qué comprueban, cómo se ejecutan y qué resultado dan.

**Última ejecución:** 09/11/2026 · **Total:** 174 casos · **Resultado:** 174 correctos y 0 fallos esperados.

## 1. Alcance

Son **pruebas de integración**. Cada prueba envía una petición HTTP a la API real y comprueba tanto la respuesta como lo que ha quedado guardado en PostgreSQL. Por tanto, se ejercitan juntas las rutas, la validación de datos, los permisos y las consultas SQL.

| Historia de usuario | Funcionalidad | Fichero |
| :--- | :--- | :--- |
| HU-05 | Sesión autenticada y rol de cada usuario | `test_auth.py` |
| HU-02 | Eliminar cuentas | `test_users.py` |
| HU-03 | Consultar cuentas | `test_users.py` |
| HU-07 y HU-08 | Asociar alumnos con familias y con personal | `test_associations.py` |
| HU-12 | Crear una tarea desde la familia y vincularla a la agenda | `test_tasks.py` |
| HU-13 | Guardar la tarea creada por el personal | `test_tasks.py` |
| HU-15 | Eliminar tareas según el horario escolar | `test_tasks.py` |
| Resto del sprint 1 | Crear y modificar usuarios, tareas propias del alumno, clases, tareas de clase y foto de perfil | `test_sprint1.py` |

**Fuera del alcance:** las tareas alternativas (`PUT /student-tasks/{task_id}/alternative`), que no forman parte del primer sprint.

## 2. Cómo ejecutarlas

**Requisitos**

- Contenedor `autovida_postgres` en marcha.
- Fichero `src/backend/proyectFastAPI/.env` con la variable `DB_PASSWORD`.
- [uv](https://docs.astral.sh/uv/) instalado.

**Comando**, desde `src/backend/proyectFastAPI`:

```bash
uv run --with pytest python -m pytest ../../../tests/integration -v
```

**Resultado esperado:** `174 passed, 0 xfailed`.

Las pruebas no modifican la base de datos de desarrollo (`autovida_db`). Trabajan en otra base, `autovida_test`, que se elimina y se crea de nuevo en cada ejecución con el script oficial `docs/diseno_arquitectura/modelado_datos/CreacionTablas.sqlscript`. Se usa PostgreSQL porque el backend emplea instrucciones que no existen en otros motores más ligeros, como `FOR UPDATE` y `LOCK TABLE`.

## 3. Datos de prueba

Todos los datos son **ficticios**. No se usan datos de alumnado real, porque se trata de menores y de información protegida, y estas pruebas se publican en el repositorio.

Antes de **cada** prueba se vacían las tablas y se cargan estos datos, de modo que ninguna prueba depende de otra:

| Usuario | Rol | Situación |
| :--- | :--- | :--- |
| `admin` | Administrador | Único administrador |
| `lucia` | Personal | Asignada a la clase 1A |
| `pedro` | Personal | Asignado a la clase 2B |
| `madre` | Familia | Asociada a `pablo` |
| `otra_madre` | Familia | Sin alumnos asociados |
| `pablo` | Alumno | En la clase 1A, asociado a `madre` |
| `ana` | Alumna | Sin clase ni familia |

Las fechas utilizadas son el lunes 16/11/2026 y el sábado 14/11/2026. El horario escolar definido en el backend es de 09:00 a 15:00.

## 4. Códigos de respuesta

| Estado HTTP | Significado | | Código API | Significado |
| :---: | :--- | :--- | :---: | :--- |
| 200 / 201 | Correcto / creado | | 1001 | Usuario o contraseña incorrectos |
| 400 | Lo impide una regla de negocio | | 1002 | Token ausente o inválido |
| 401 | Sin sesión válida | | 1003 | Se requiere administrador |
| 403 | Sin permiso | | 1004 | Solo alumnos asociados a la cuenta propia |
| 404 | No existe | | 1005 | Datos inválidos |
| 409 | Conflicto con datos existentes | | 1006 | Usuario no encontrado |
| 422 | Datos con formato incorrecto | | 1011 | No se puede eliminar al último administrador |

El resto de códigos se indica en cada prueba y está definido en `src/backend/proyectFastAPI/errors.py`.

Cuando una prueba aparece con "× n", se ejecuta n veces con datos distintos.

## 5. Descripción de los ficheros

### `conftest.py`: preparación común

No contiene pruebas. `pytest` lo carga automáticamente antes de ejecutarlas.

| Elemento | Función |
| :--- | :--- |
| `engine` | Crea `autovida_test` y sus tablas una vez por ejecución |
| `seed` | Vacía las tablas y carga los datos de la sección 3 antes de cada prueba |
| `client` | Cliente HTTP que llama a la API y la conecta a `autovida_test` |
| `count` | Cuenta filas para comprobar qué se ha guardado |
| `as_user` | Genera la cabecera de una petición hecha con la sesión de un usuario |
| `error_code` | Extrae el código de error de una respuesta |

### `test_auth.py`: inicio y cierre de sesión (HU-05, 20 casos)

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_login_correcto_devuelve_token_y_rol` × 4 | Cada uno de los cuatro roles inicia sesión | 200, token y rol correctos |
| `test_el_token_no_se_guarda_tal_cual` | El token no se almacena en claro | No aparece en `users.token` |
| `test_contrasena_incorrecta` | Contraseña errónea | 401, código 1001 |
| `test_usuario_inexistente_da_el_mismo_error` | No se revela si el usuario existe | 401, código 1001 |
| `test_rol_que_no_es_el_suyo` | Usuario correcto con un rol ajeno | 401, código 1001 |
| `test_login_con_datos_invalidos` × 5 | Sin rol, rol inventado, usuario con espacios, contraseña de más de 72 bytes y campo extra | 422, código 1005 |
| `test_el_token_del_login_sirve_para_entrar` | El token recibido da acceso | 200 |
| `test_ruta_protegida_sin_token` | Acceso sin token | 401, código 1002 |
| `test_ruta_protegida_con_token_falso` | Acceso con un token inventado | 401, código 1002 |
| `test_un_login_nuevo_invalida_la_sesion_anterior` | Solo hay una sesión activa por usuario | El token anterior da 401 |
| `test_logout_cierra_la_sesion` | Cerrar sesión anula el token | 200 y después 401 |
| `test_logout_dos_veces` | Cerrar una sesión ya cerrada | 401 |
| `test_logout_solo_cierra_la_sesion_propia` | No afecta a otros usuarios | La otra sesión sigue activa |

### `test_users.py`: eliminar y consultar cuentas (HU-02 y HU-03, 24 casos)

**Eliminar cuentas (HU-02)**

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_admin_elimina_una_cuenta` | El administrador elimina una cuenta | 200, sin filas en `users` ni `Student` |
| `test_eliminar_un_alumno_borra_sus_vinculos_y_nada_mas` | Efecto del borrado en las relaciones | Desaparecen sus vínculos, el resto de cuentas sigue |
| `test_la_cuenta_eliminada_pierde_su_sesion` | La sesión deja de valer | 401 |
| `test_la_cuenta_eliminada_no_puede_entrar` | No se puede volver a iniciar sesión | 401 |
| `test_no_se_puede_eliminar_al_ultimo_admin` | Siempre queda un administrador | 400, código 1011 |
| `test_con_dos_admins_se_puede_eliminar_uno` | Si hay más de uno, se permite | 200 |
| `test_eliminar_cuenta_inexistente` | La cuenta no existe | 404, código 1006 |
| `test_eliminar_con_rol_equivocado_no_borra_nada` | La cuenta existe con otro rol | 404, la cuenta sigue |
| `test_eliminar_con_rol_inventado` | Rol que no existe | 422, código 1005 |
| `test_solo_el_admin_puede_eliminar` × 3 | Personal, familia y alumno lo intentan | 403, código 1003, sin cambios |
| `test_eliminar_sin_sesion` | Petición sin sesión | 401 |

**Consultar cuentas (HU-03)**

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_admin_ve_todas_las_cuentas` | Listado completo | 200, las 7 cuentas en orden |
| `test_la_consulta_no_devuelve_contrasenas_ni_tokens` | No se exponen datos sensibles | Sin campos `password` ni `token` |
| `test_filtrar_por_rol` | Filtro `?role=parent` | Solo familias, con correo y rol |
| `test_los_alumnos_no_tienen_correo` | Los alumnos no tienen correo | Sin campo `email` |
| `test_consulta_sin_resultados` | Ninguna cuenta de ese rol | 200 y lista vacía |
| `test_filtrar_por_rol_inventado` | Rol que no existe | 422 |
| `test_solo_el_admin_puede_consultar` × 3 | Personal, familia y alumno lo intentan | 403, código 1003 |
| `test_consultar_sin_sesion` | Petición sin sesión | 401 |
| `test_admin_consulta_una_cuenta_concreta` | Consulta de una sola cuenta | 200 y datos del usuario |

### `test_associations.py`: alumnos con familias y personal (HU-07 y HU-08, 36 casos)

Las familias se asocian directamente con cada alumno. El personal se relaciona con los alumnos a través de las clases.

**Asociaciones con familias**

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_admin_asocia_familia_y_alumno` | Crear una asociación | 200 y fila en `par_stud` |
| `test_asociar_dos_veces_no_duplica` | Repetir una asociación | 200, sigue habiendo una fila |
| `test_un_alumno_puede_tener_varias_familias` | Varias familias por alumno | 2 filas |
| `test_asociar_cuentas_que_no_existen_con_ese_rol` × 4 | Alumno inexistente, familia inexistente y cuentas con otro rol | 404, código 1013, sin cambios |
| `test_solo_el_admin_puede_asociar` × 3 | Personal, familia y alumno lo intentan | 403, sin cambios |
| `test_asociar_sin_sesion` | Petición sin sesión | 401 |
| `test_admin_quita_una_asociacion` | Quitar una asociación | 200, la cuenta sigue existiendo |
| `test_quitar_una_asociacion_que_no_existe` | La asociación no existe | 404, código 1014 |
| `test_solo_el_admin_puede_quitar_asociaciones` × 3 | Personal, familia y alumno lo intentan | 403, sin cambios |

**Consultas**

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_admin_ve_familia_y_personal_de_un_alumno` | Vínculos de un alumno | Devuelve familia y personal de su clase |
| `test_solo_el_admin_ve_los_vinculos_de_un_alumno` × 3 | Personal, familia y alumno lo intentan | 403 |
| `test_la_familia_ve_sus_alumnos` | Alumnos de la familia | Devuelve a `pablo` |
| `test_una_familia_no_ve_los_alumnos_de_otra` | Acceso a datos ajenos | 403, código 1004 |
| `test_el_personal_ve_los_alumnos_de_su_clase` | Alumnos del personal | Devuelve a `pablo` |
| `test_el_personal_no_ve_los_alumnos_de_otro` | Acceso a datos ajenos | 403, código 1004 |
| `test_el_admin_ve_los_alumnos_de_cualquiera` | Acceso del administrador | 200 |

**Personal y clases**

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_admin_asigna_personal_a_una_clase` | Asignar personal | 200 y fila en `class_staff` |
| `test_solo_el_admin_asigna_personal` × 3 | Personal, familia y alumno lo intentan | 403, sin cambios |
| `test_asignar_personal_inexistente` | El personal no existe | 404, código 1034 |
| `test_asignar_personal_a_clase_inexistente` | La clase no existe | 404, código 1030 |
| `test_el_personal_inscribe_un_alumno_en_su_clase` | Inscripción en clase propia | 201 y aparece entre sus alumnos |
| `test_el_personal_no_inscribe_en_una_clase_ajena` | Inscripción en clase ajena | 403, código 1032, sin cambios |
| `test_un_alumno_no_puede_estar_en_dos_clases` | Alumno que ya tiene clase | 409, código 1033 |
| `test_el_personal_saca_a_un_alumno_de_su_clase` | Retirar a un alumno | 200 y deja de aparecer |
| `test_admin_quita_personal_de_una_clase` | Quitar personal de una clase | 200 y deja de aparecer, se desvinculan los alumnos |

### `test_tasks.py`: crear y eliminar tareas (HU-12, HU-13 y HU-15, 55 casos)

**Tareas creadas por la familia (HU-12)**

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_la_familia_crea_una_tarea_y_queda_en_la_agenda` | Crear una tarea | 201, filas en `Generic_Task` y `stud_task` |
| `test_la_familia_puede_crear_una_tarea_solo_con_duracion` | Tarea sin hora | 201 |
| `test_la_familia_crea_fuera_del_horario_escolar` × 4 | 08:30 (30 min), 15:00 (30 min), 07:00 (60 min) y 23:00 (600 min) | 201 |
| `test_la_familia_no_crea_dentro_del_horario_escolar` × 5 | 08:30 (31 min), 09:00 (10 min), 10:00 (30 min), 14:59 (1 min) y 23:00 (601 min) | 400, código 1024, sin cambios |
| `test_familia_sin_relacion_con_el_alumno` | Familia no asociada | 403, código 1019, sin cambios |
| `test_tarea_para_un_alumno_inexistente` | El alumno no existe | 404, código 1018 |
| `test_solo_familia_y_personal_crean_para_un_alumno` × 2 | Administrador y alumno lo intentan | 403, código 1017 |
| `test_crear_tarea_sin_sesion` | Petición sin sesión | 401 |
| `test_crear_tarea_con_datos_invalidos` × 8 | Título vacío o largo, duración 0 o de texto, fecha y hora incorrectas, hora con zona horaria y campo extra | 422, código 1005, sin cambios |
| `test_la_agenda_queda_ordenada_por_hora` | Orden de la agenda | Por hora, las tareas sin hora al final |
| `test_la_familia_no_crea_un_sabado_por_la_manana` | No permitir tareas familiares a las 10:00 del sábado | 400, código 1024, sin cambios |

**Tareas creadas por el personal (HU-13)**

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_el_personal_crea_una_tarea_y_se_guarda` | Datos guardados | 201, hora, duración y creador correctos |
| `test_el_personal_crea_dentro_del_horario` × 2 | 09:00 (360 min) y 14:30 (30 min) | 201 |
| `test_el_personal_no_crea_fuera_del_horario` × 4 | 08:59 (30 min), 14:30 (31 min), 15:00 (10 min) y 17:00 (30 min) | 400, código 1023, sin cambios |
| `test_personal_de_otra_clase` | Personal sin relación con el alumno | 403, código 1019, sin cambios |
| `test_tarea_de_clase_llega_a_todos_sus_alumnos` | Tarea asignada a una clase | 201 y una fila por alumno |
| `test_el_personal_no_crea_una_tarea_solo_con_duracion` | Tarea sin hora de inicio | 400, código 1023, sin cambios |

**Eliminar tareas (HU-15)**

La regla se aplica sobre la hora programada de la tarea: el personal elimina las que están dentro del horario escolar y las familias, las que están fuera.

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_el_personal_elimina_una_tarea_del_horario_escolar` | Tarea a las 10:00 | 200, sale de la agenda |
| `test_el_personal_no_elimina_fuera_del_horario_escolar` | Tarea a las 17:00 | 400, código 1026, sigue en la agenda |
| `test_la_familia_elimina_fuera_del_horario_escolar` | Tarea a las 17:00 | 200, sale de la agenda |
| `test_la_familia_no_elimina_dentro_del_horario_escolar` | Tarea a las 10:00 | 400, código 1025, sigue en la agenda |
| `test_limites_del_horario_al_eliminar` × 6 | Personal y familia en los límites de 09:00, 14:59 y 15:00 | Permitido o rechazado según el rol |
| `test_eliminar_una_tarea_inexistente` | La tarea no existe | 404, código 1021 |
| `test_eliminar_con_una_fecha_que_no_es_la_suya` | Fecha distinta a la de la tarea | 404, sigue en la agenda |
| `test_eliminar_sin_indicar_la_fecha` | Falta la fecha | 422 |
| `test_eliminar_sin_relacion_con_el_alumno` × 2 | Personal y familia sin relación | 403, código 1019, sin cambios |
| `test_solo_familia_y_personal_eliminan_de_un_alumno` × 2 | Administrador y alumno lo intentan | 403, código 1017 |
| `test_eliminar_sin_sesion` | Petición sin sesión | 401 |
| `test_quitar_tarea_de_agenda_conserva_tarea_compartida_e_historico` | Al quitarla de un alumno, sigue asignada a otro; luego se conserva el histórico | 200, las asignaciones se retiran individualmente y quedan `Tasks` y `Generic_Task` |

### `test_sprint1.py`: resto de historias del sprint 1 (39 casos)

**Crear usuarios**

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_admin_crea_un_alumno_que_puede_entrar` | Alta de un alumno con sus ajustes de accesibilidad | 200 y puede iniciar sesión |
| `test_admin_crea_cuentas_con_correo` | Alta de administrador, personal y familia | 200 y las 3 cuentas guardadas |
| `test_no_se_repiten_usuario_ni_correo` | Nombre de usuario o correo ya registrados | 409 en ambos casos |
| `test_solo_el_admin_crea_usuarios` | El personal lo intenta | 403 |

**Modificar usuarios**

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_admin_modifica_nombre_y_correo` | Cambio de datos de una cuenta | 200 y datos actualizados |
| `test_cambiar_la_contrasena_cierra_la_sesion` | Cambio de contraseña | 200, la sesión anterior da 401 y la clave nueva permite entrar |
| `test_renombrar_un_alumno_conserva_sus_vinculos` | Cambio del nombre de usuario de un alumno | 200, conserva clase, familia y tareas |
| `test_renombrar_al_personal_actualiza_el_autor_de_sus_tareas` | Cambio del nombre de usuario del personal | 200 y autoría actualizada en `Tasks` |
| `test_sin_ser_admin_no_se_editan_otras_cuentas_ni_el_nombre` | Una familia edita otra cuenta o su propio nombre | 403 en ambos casos |
| `test_no_se_puede_cambiar_el_rol` | El administrador intenta cambiar un rol | 403 |

**Consulta de alumnos y tareas propias del alumno**

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_admin_consulta_los_alumnos_de_un_tutor` | Alumnos asociados a una familia | 200, devuelve a `pablo` |
| `test_el_alumno_crea_y_elimina_su_tarea` | Crear y borrar una tarea propia | 201, 200 y sin fila en `Tasks` |
| `test_el_alumno_crea_una_tarea_sin_hora` | Tarea propia solo con duración | 201 |
| `test_el_alumno_no_crea_en_horario_escolar` | Tarea propia a las 10:00 | 400 |
| `test_el_alumno_sin_permiso_no_crea_tareas` | Alumno con `stud_access_task_mod` desactivado | 403 |
| `test_el_alumno_no_elimina_tareas_de_otros` | Tarea creada por su familia | 404, sigue en la agenda |
| `test_un_adulto_no_usa_las_rutas_del_alumno` | Una familia usa `/student-tasks/me` | 403 |

**Clases**

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_admin_crea_edita_y_borra_una_clase` | Ciclo completo y nombres repetidos | 201, 200, 200 y 409 si el nombre ya existe |
| `test_solo_el_admin_gestiona_las_clases` | El personal crea, edita y borra | 403 en los tres casos |
| `test_renombrar_una_clase_conserva_alumnos_y_tareas` | Cambio de nombre con tareas y alumnos | 200, conserva matrícula y tareas |
| `test_borrar_una_clase_borra_sus_tareas_y_no_los_alumnos` | Eliminar una clase con tareas | 200, sin tareas de clase, el alumno sigue |
| `test_el_personal_consulta_solo_sus_clases` | Listado y detalle según la clase | Solo la propia; 403 en clase ajena y para familias |
| `test_el_admin_no_apunta_alumnos_a_una_clase` | La matrícula corresponde al personal | 403, sin cambios |
| `test_un_alumno_nuevo_recibe_las_tareas_de_su_clase` | Matricular con tareas ya creadas | Recibe la tarea de la clase |
| `test_sacar_a_un_alumno_quita_solo_las_tareas_de_clase` | Retirar a un alumno de la clase | 200, conserva sus tareas individuales |

**Tareas de clase**

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_el_personal_consulta_las_tareas_de_su_clase` | Listado de tareas de la clase | 200, con la tarea y sus alumnos |
| `test_el_personal_modifica_una_tarea_de_clase` | Cambio de título, fecha y hora | 200, una sola asignación con la fecha nueva |
| `test_una_tarea_de_clase_no_se_mueve_fuera_del_horario` | Cambio a las 17:00 | 400 |
| `test_el_personal_elimina_una_tarea_de_clase` | Eliminar la tarea | 200, sin filas en `stud_task` ni `Tasks` |
| `test_personal_de_otra_clase_no_gestiona_sus_tareas` | Personal de otra clase crea, consulta y borra | 403 en los tres casos |

**Foto de perfil**

| Prueba | Qué comprueba | Resultado esperado |
| :--- | :--- | :--- |
| `test_el_alumno_sube_un_png` | Subida de un PNG válido | 200 y se recupera la misma imagen |
| `test_el_alumno_sube_un_jpeg` | Subida de un JPEG | 200 y tipo `image/jpeg` |
| `test_el_alumno_sube_un_webp` | Subida de un WebP | 200 |
| `test_cambiar_la_foto_no_acumula_imagenes` | Reemplazar la foto | Queda una sola fila en `Avatar` |
| `test_sin_foto_se_ve_la_imagen_por_defecto` | Alumno sin foto | Imagen SVG predeterminada |
| `test_se_rechazan_ficheros_invalidos_o_demasiado_grandes` | Fichero que no es imagen y fichero de más de 5 MB | 422 y 413 |
| `test_solo_un_alumno_sube_su_foto` | Una familia lo intenta | 403 |
| `test_admin_y_personal_de_su_clase_ven_la_foto` | Acceso a la foto de un alumno | 200 para administrador y personal de su clase; 403 para personal de otra |
| `test_la_familia_no_ve_la_foto` | Comportamiento actual de la ruta de fotos | 403 |

## 6. Decisiones pendientes

No quedan pruebas marcadas con `@pytest.mark.xfail`. Esta tabla registra el tratamiento de festivos, que aún requiere un calendario del centro.

| Ref. | Prueba | Situación actual | Decisión pendiente |
| :---: | :--- | :--- | :--- |
| F1 | `test_admin_consulta_una_cuenta_concreta` | Solo existe el listado de cuentas | Añadir `GET /users/{role}/{username}` CORREGIDO ✅ |
| F2 | `test_admin_quita_personal_de_una_clase` | Se puede asignar personal a una clase, pero no quitarlo | Añadir `DELETE /classes/{class_name}/staff/{staff_username}` CORREGIDO ✅| 
| F3 | `test_la_familia_crea_un_sabado_por_la_manana` | El horario de 09:00 a 15:00 se aplica todos los días | Definir el tratamiento de fines de semana y festivos DECIDIDO ✅ Por ahora no se permitirá la asignación de tareas por la mañana en fin de semana.|
| F4 | `test_el_personal_crea_una_tarea_solo_con_duracion` | Al personal se le exige hora de inicio | Confirmar si el personal puede crear tareas solo con duración
CORREGIDO ✅ El personal debe crear tareas con hora de inicio obligatoriamente|
| F5 | `test_eliminar_no_deja_la_tarea_huerfana` | La tarea sale de la agenda, pero su fila permanece en `Tasks` | Decidir si se elimina la fila o se conserva como histórico. DECIDIDO ✅ Se conserva para que otros alumnos que la compartan sigan teniéndola y a modo de histórico|

## 7. Validación de las pruebas

Para comprobar que las 135 pruebas iniciales detectan errores reales, se introdujeron de forma deliberada ocho fallos en una copia del código. Las pruebas detectaron los ocho:

| Fallo introducido | Casos que fallaron |
| :--- | :---: |
| Eliminar cuentas sin exigir administrador | 4 |
| Fin del horario escolar a las 16:00 al crear tareas | 5 |
| El personal elimina tareas a cualquier hora | 2 |
| La familia elimina tareas a cualquier hora | 3 |
| Token guardado sin cifrar | 108 |
| Consultar los alumnos de otra cuenta | 2 |
| Eliminar al último administrador | 1 |
| Un alumno en dos clases a la vez | 1 |

Además, las pruebas de `test_sprint1.py` detectaron dos errores reales del backend, ya corregidos en `gestion_usuarios/users_mng_backend.py`:

| Error encontrado | Casos que fallaron |
| :--- | :---: |
| Referencia incorrecta a los campos de accesibilidad: no se podían crear alumnos ni modificar cuentas | 6 |
| Comprobación incorrecta del final del fichero: se rechazaban todas las imágenes PNG | 1 |
