# Propuesta técnica — Proyecto AUTOVIDA

> **Estado:** Borrador para completar y validar  
> **Equipo proponente:** CLENCH Software Development  
> **Asignaturas:** Dirección y Gestión de Proyectos (DGP) y Metodologías de Desarrollo Ágil (MDA)  
> **Titulación:** Grado en Ingeniería Informática — ETSIIT, Universidad de Granada  
> **Curso académico:** 2026–2027  
> **Entidad destinataria:** C.E.E. Fundación Purísima Concepción de Granada  
> **Versión y fecha:** [Completar]

Los campos entre corchetes quedan pendientes de completar. La versión LaTeX modularizada en `PROPUESTA_TECNICA.tex` es el documento principal; este Markdown recoge su contenido como esquema de trabajo.

## 1. Presentación de la empresa

### CLENCH Software Development

El equipo de trabajo opera bajo la identidad **CLENCH Software Development**. Esta iniciativa combina el aprendizaje con el desarrollo de software de calidad para promover la responsabilidad social y la inclusión de personas en situación de vulnerabilidad.

- **Lema y propósito:** *Tecnología accesible para potenciar la autonomía personal*.
- **Misión:** Diseñar, implementar y validar soluciones digitales accesibles que faciliten la rutina diaria de estudiantes con Necesidades Específicas de Apoyo Educativo (NEAE).
- **Valores:** accesibilidad y empatía, calidad, transparencia y coordinación.

## 2. Resumen ejecutivo

**Título:** AUTOVIDA: Sistema de Agenda y Asignación de Tareas Accesible para Alumnado NEAE / PTVAL.

AUTOVIDA propone una aplicación para apoyar al alumnado del Programa de Transición a la Vida Adulta (PTVAL) del C.E.E. Fundación Purísima Concepción en la consulta de actividades y la realización de tareas mediante instrucciones ordenadas y apoyos visuales. El personal del centro podrá preparar actividades y rutinas para los perfiles destinatarios.

La primera versión se plantea como un producto mínimo viable con agenda por alumno, tareas guiadas, registro de pasos completados, rutinas y temporizador visual. Esta propuesta define requisitos verificables, criterios de aceptación, arquitectura preliminar y documentación de entrega; el alcance final se cerrará al contrastarlo con la solicitud original y con el centro.

### Tipo de caso de negocio

La clasificación inicial es un caso impulsado por **demanda educativa y social**: responder a la necesidad del centro de apoyar la organización y autonomía del alumnado PTVAL con una solución accesible. No se presenta como un proyecto originado principalmente por una nueva tecnología o por un mandato legal. La petición concreta que confirma esta clasificación y su referencia documental se incorporarán tras revisar el encargo y las actas. La accesibilidad y la privacidad se tratarán como condiciones de diseño y validación.

### Duración propuesta

Se estima una duración de **4 meses desde la reunión de inicio**. Es una estimación inicial del equipo, no una fecha acordada; deberá ajustarse al alcance aprobado, a la disponibilidad del centro y al calendario académico. La distribución detallada de actividades y meses se completará en el apartado de cronograma.

## 3. Objetivos

### Objetivo general

Diseñar, implementar y validar con el centro una primera versión de AUTOVIDA que permita al personal preparar actividades y al alumnado consultar su agenda, seguir tareas guiadas y registrar su avance mediante una interfaz accesible.

### Objetivos específicos

1. **OE-01 — Definir el alcance:** acordar con el centro los perfiles de usuario, los flujos prioritarios y los requisitos de la primera versión, con prioridad, origen y criterio de aceptación para cada requisito.
2. **OE-02 — Diseñar la interacción:** producir un prototipo revisable de agenda, actividad guiada, rutina y temporizador, y registrar las observaciones del centro y de los perfiles de usuario que se acuerden.
3. **OE-03 — Implementar el MVP:** desarrollar los requisitos RF-01 a RF-08 que queden aprobados y registrar cualquier requisito modificado o aplazado.
4. **OE-04 — Verificar la solución:** ejecutar una prueba vinculada a cada criterio de aceptación aprobado y entregar un informe con resultados, incidencias y limitaciones conocidas.
5. **OE-05 — Preparar la entrega:** entregar la versión acordada, su guía de uso y la documentación técnica y de pruebas incluida en el alcance.

## 4. Requisitos propuestos

Los siguientes requisitos son una propuesta inicial del equipo, no requisitos ya aprobados por el centro. Se completará la referencia `[#]` con la petición, documento o acta de origen y se validará cada requisito con las personas responsables.

### Requisitos funcionales del producto mínimo viable

| ID | Requisito propuesto | Criterio de aceptación | Origen | Prioridad |
| --- | --- | --- | --- | --- |
| RF-01 | La aplicación distinguirá los perfiles de personal y alumnado. El personal podrá crear y modificar actividades; el alumnado solo podrá consultar las actividades que tenga asignadas y registrar su avance. | Con una cuenta de cada perfil, comprobar que el personal puede editar una actividad y que el alumnado no puede acceder a las funciones de edición. | [#] | MVP |
| RF-02 | El personal podrá crear una actividad asignada a un alumno, con título, fecha, hora de inicio y una o más instrucciones ordenadas. | Crear una actividad con dos instrucciones y verificar que aparece en el perfil del alumno asignado con fecha, hora y orden correctos. | [#] | MVP |
| RF-03 | El alumno podrá seleccionar una fecha para consultar su agenda. Al abrirla se mostrará por defecto la fecha actual y las actividades asignadas a ese alumno, ordenadas por hora de inicio. Si no hay actividades, se mostrará «No hay actividades para esta fecha». | Abrir la agenda y comprobar la fecha actual; seleccionar otra fecha con actividades y una sin actividades, y verificar contenido, orden y mensaje. | [#] | MVP |
| RF-04 | El alumno podrá marcar cada instrucción como completada y consultar cuáles quedan pendientes dentro de la actividad. | Completar una instrucción de una actividad de dos pasos y verificar que la primera figura como completada y la segunda como pendiente. | [#] | MVP |
| RF-05 | El personal podrá crear una rutina asignada a un alumno mediante una lista ordenada de actividades; el alumno podrá consultar esa lista y marcar cada elemento como completado. | Crear una rutina de dos elementos y comprobar que se presenta en el orden definido y que el estado de cada elemento puede actualizarse. | [#] | MVP |
| RF-06 | El personal podrá asociar a una actividad una duración entera de entre 1 y 60 minutos. El alumno podrá iniciar un temporizador que mostrará el tiempo restante en minutos y segundos y, al llegar a cero, el mensaje «Tiempo finalizado» y un pictograma de fin. | Configurar un minuto, iniciar el temporizador y comprobar que el contador se actualiza cada segundo y que al llegar a cero aparecen el mensaje y el pictograma. | [#] | MVP |
| RF-07 | Una persona con una cuenta habilitada podrá iniciar sesión introduciendo sus credenciales. Tras validarlas, la aplicación mostrará las funciones correspondientes a su perfil. | Iniciar sesión con credenciales válidas de cada perfil y comprobar que se accede a las funciones autorizadas; repetir con credenciales no válidas y verificar que se deniega el acceso y se muestra un mensaje de error. | [#] | MVP |
| RF-08 | Una persona con sesión iniciada podrá cerrarla desde la aplicación. Al hacerlo, la sesión dejará de estar activa y será necesario iniciar sesión de nuevo para acceder a las funciones protegidas. | Cerrar sesión y comprobar que se vuelve a la pantalla de inicio de sesión; intentar abrir una función protegida y verificar que se solicita autenticación. | [#] | MVP |

### Requisitos no funcionales propuestos

- **Accesibilidad de los apoyos:** cada instrucción mostrará una descripción textual y un pictograma o imagen asociado. Se revisará el prototipo con los perfiles de usuario que acuerde el centro y se registrarán los problemas observados.
- **Idioma:** los textos de la interfaz incluidos en la primera versión estarán en español.
- **Privacidad y permisos:** antes de usar datos reales se definirá qué datos son imprescindibles, quién puede consultarlos y cómo se protegerán. La matriz de permisos se verificará con pruebas para cada perfil.
- **Dispositivos y funcionamiento sin conexión:** plataformas, dispositivos y necesidad de uso sin conexión quedan por decidir con el centro; no se consideran requisitos aprobados todavía.

### Elementos que se proponen posponer

Para mantener acotada la primera versión, se propone dejar para una fase posterior los módulos de reprografía, consulta de menús o dietas, guía de visitas y mensajería entre alumnado y tutores. No se descartan: se documentará para cada uno la petición de origen, su prioridad y la decisión acordada antes de incorporarlo al alcance.

## 5. Justificación de la propuesta

Las decisiones son una justificación inicial del equipo para acotar la primera versión. Se apoyan en el propósito de apoyar la organización y autonomía del alumnado PTVAL y deben contrastarse con las solicitudes originales del centro y la información recogida en reuniones.

### Soluciones relacionadas y comparativa

La revisión preliminar compara herramientas y recursos descritos por sus entidades responsables. No afirma que las soluciones existentes carezcan de funciones que no aparezcan en sus descripciones públicas.

| Referencia | Capacidades descritas públicamente | Relación con AUTOVIDA |
| --- | --- | --- |
| [In-TIC Agenda (Fundación Orange / IMEDIR)](https://fundacionorange.es/aplicaciones/in-tic-agenda/) | Permite crear agendas diarias, semanales y libres con actividades asociadas a secuencias de pictogramas, configurables por profesionales o familiares. | Coincide con la organización visual y secuenciación de actividades. AUTOVIDA propone asignar tareas por perfil, registrar pasos completados y asociar un temporizador a una actividad. |
| [Día a Día (Fundación Orange)](https://fundacionorange.es/aplicaciones/dia-a-dia/) | Diario visual para guardar y revisar actividades mediante imágenes, fotos, vídeos y textos; permite situarlas en momentos del día y asociarlas con personas y lugares. | Su descripción se centra en el diario visual. AUTOVIDA plantea centrarse en la agenda de actividades pendientes asignadas por el personal y en acompañar su realización. |
| [Agendas visuales (ARASAAC)](https://aulaabierta.arasaac.org/materiales-caa-agendas-visuales) | Reúne materiales de agendas visuales con pictogramas y explica su uso para evocar actividades previstas o realizadas, apoyar la anticipación y facilitar la comunicación entre centro y familia. | Aporta una referencia para los apoyos visuales. AUTOVIDA propone integrarlos en una aplicación con perfiles, tareas y seguimiento del avance; la selección y las condiciones de uso de los pictogramas se verificarán antes de incorporarlos. |

La revisión se basa en las descripciones oficiales consultadas el 8 de octubre de 2026. Antes de cerrar la propuesta se comprobarán las versiones disponibles, dispositivos compatibles, condiciones de uso y adecuación con el centro; esta tabla no sustituye a una prueba práctica.

### Justificación de decisiones de alcance

| Decisión propuesta | Requisitos relacionados | Justificación y efecto en el alcance |
| --- | --- | --- |
| Incluir agenda y actividades asignadas en el MVP. | RF-01, RF-02 y RF-03. | Responde al propósito de organizar tareas cotidianas. Limitar la agenda a actividades asignadas permite probar el flujo principal sin introducir calendarios compartidos o integraciones externas. |
| Incluir instrucciones ordenadas y registro de avance. | RF-02 y RF-04. | Dividir una actividad en pasos observables permite comprobar qué instrucciones se han presentado y completado. La redacción y el apoyo visual se validarán con el centro y las personas usuarias. |
| Incluir rutinas configurables por el personal. | RF-01 y RF-05. | Permite preparar secuencias recurrentes desde el centro. La frecuencia y la forma de repetición quedan por concretar. |
| Incluir un temporizador visual sencillo. | RF-06. | Apoya actividades con duración definida. Se limita a iniciar la duración configurada y señalar su finalización; pausas y avisos sonoros quedan fuera hasta validar su necesidad. |
| Posponer reprografía, menús/dietas, visitas y mensajería. | Requisitos futuros por identificar. | Son flujos distintos del núcleo de agenda y tareas. Menús/dietas y mensajería pueden requerir decisiones adicionales sobre datos y permisos; reprografía y visitas dependen de procesos específicos del centro. |

En la revisión con el centro se anotará para cada decisión la petición de origen, la persona o documento que aporta la información, el beneficio esperado, el coste o dependencia y el acuerdo final. Si la solicitud original contradice una decisión de esta tabla, se actualizarán el requisito, su prioridad y su justificación.

- **Reunión o documento de referencia:** [Completar].
- **Decisiones confirmadas:** [Completar].
- **Cambios solicitados y motivo:** [Completar].
- **Persona que valida por parte del centro:** [Completar].

## 6. Antecedentes del equipo de trabajo

La propuesta identifica al equipo CLENCH Software Development. Para presentar su capacidad de ejecución con evidencias, cada integrante completará conocimientos relevantes, experiencia previa y una referencia verificable. No se atribuyen tecnologías ni experiencia que todavía no hayan sido confirmadas.

| Integrante | Experiencia y conocimientos relacionados con el proyecto | Evidencia / referencia |
| --- | --- | --- |
| Miguel Ángel Luque | [Tecnologías, tareas y nivel de experiencia] | [Asignatura, proyecto o repositorio] |
| Yeray Rodríguez Navas | [Tecnologías, tareas y nivel de experiencia] | [Asignatura, proyecto o repositorio] |
| Julián Carrión Tovar | [Tecnologías, tareas y nivel de experiencia] | [Asignatura, proyecto o repositorio] |
| Pablo Hernández Ibáñez | [Tecnologías, tareas y nivel de experiencia] | [Asignatura, proyecto o repositorio] |
| Pablo de la Torre Roldán | [Tecnologías, tareas y nivel de experiencia] | [Asignatura, proyecto o repositorio] |
| José Rodríguez Fernández | [Tecnologías, tareas y nivel de experiencia] | [Asignatura, proyecto o repositorio] |
| Amine Azzammouri | [Tecnologías, tareas y nivel de experiencia] | [Asignatura, proyecto o repositorio] |

El equipo comprobará que dispone de responsables o apoyo para desarrollo de la aplicación, backend y persistencia, diseño accesible de interfaces, pruebas y documentación, y coordinación con el centro. Las carencias y necesidades de aprendizaje se anotarán como riesgos o acciones de formación.

## 7. Descripción y arquitectura de la solución

Se propone una aplicación cliente para alumnado y personal del centro. El personal configurará actividades y rutinas; el alumnado consultará su agenda, seguirá las instrucciones y actualizará el estado de cada paso. La arquitectura es una propuesta lógica inicial y queda sujeta a la confirmación de requisitos de dispositivos, alojamiento, seguridad y mantenimiento.

### Esquema lógico

```text
Personal y alumnado → Aplicación cliente (Flutter / Dart)
                    → API REST (Python / FastAPI)
                    → Persistencia (PostgreSQL)
```

### Componentes propuestos

- **Aplicación cliente:** Flutter y Dart para presentar agenda, actividades guiadas, rutinas, apoyos visuales y temporizador.
- **Servicio backend:** Python con FastAPI para validar permisos, gestionar perfiles, actividades y rutinas, y registrar el avance comunicado por el cliente.
- **Persistencia:** PostgreSQL para los datos necesarios de perfiles, asignaciones y progreso. El esquema y el periodo de conservación se definirán tras acordar los datos mínimos.
- **Diseño y apoyos visuales:** Figma para prototipos; se propone evaluar pictogramas de ARASAAC y verificar atribución y condiciones de uso antes de incorporarlos.

### Flujo principal

El personal registra una actividad y sus instrucciones; el servicio comprueba los permisos y guarda la asignación; el cliente del alumno consulta únicamente sus actividades y envía el estado de los pasos completados. El servicio devuelve el estado actualizado para mostrarlo en la agenda.

**Decisiones técnicas pendientes:** plataformas y dispositivos, mecanismo de autenticación, alojamiento, copias de seguridad, funcionamiento sin conexión, accesibilidad de los controles y responsable de mantenimiento. La selección tecnológica es preliminar, no contractual.

## 8. Actividades y cronograma

De acuerdo con la indicación docente, este apartado se completará cuando se estudie en teoría la planificación de actividades y cronogramas. Responsables, participación del cliente, duraciones, dependencias y fechas quedan pendientes y no son compromisos aprobados.

### Actividades y entregables previstos

| Actividad | Objetivo | Participantes e implicación | Entregable / evidencia |
| --- | --- | --- | --- |
| Análisis y validación de necesidades | OE-01 | Equipo: [asignar]. Centro: [interlocutores y disponibilidad]. | Requisitos y alcance aprobados |
| Diseño de flujos y prototipo | OE-02 | Equipo: [asignar]. Centro y usuarios: [sesiones a acordar]. | Prototipo y observaciones registradas |
| Implementación del MVP | OE-03 | Equipo: [asignar]. Centro: [validación de dudas]. | Versión con requisitos aprobados |
| Pruebas y ajustes | OE-04 | Equipo: [asignar]. Centro y usuarios: [validación acordada]. | Informe de pruebas e incidencias |
| Documentación y entrega | OE-05 | Equipo: [asignar]. Centro: [revisión y recepción]. | Aplicación y documentación final |

### Cronograma a completar en teoría

| Actividad | Mes de inicio | Duración | Dependencia / hito |
| --- | --- | --- | --- |
| Análisis y validación | [Completar] | [Completar] | [Completar] |
| Diseño y prototipo | [Completar] | [Completar] | [Completar] |
| Implementación | [Completar] | [Completar] | [Completar] |
| Pruebas y ajustes | [Completar] | [Completar] | [Completar] |
| Documentación y entrega | [Completar] | [Completar] | [Completar] |

La suma de duraciones deberá ser coherente con los cuatro meses estimados en el resumen; cualquier variación se justificará y se validará con el centro.

## 9. Cauces de seguimiento con el cliente

Se propone una cadencia sencilla para que el centro conozca el estado, pueda resolver bloqueos y valide entregables. Los canales, participantes y frecuencia se confirmarán en la reunión de inicio.

| Cauce propuesto | Frecuencia | Información / propósito | Participación del cliente |
| --- | --- | --- | --- |
| Resumen de estado por correo electrónico | Semanal | Trabajo completado, siguiente paso, bloqueos, riesgos y decisiones necesarias. | Nombrar contacto destinatario y responder a decisiones solicitadas. |
| Reunión de seguimiento | Cada dos semanas | Revisar avances, mostrar el prototipo o versión disponible, resolver dudas y acordar cambios. | Asistir con el interlocutor designado y validar acuerdos. |
| Registro compartido de decisiones e incidencias | Actualización continua | Identificador, descripción, impacto, responsable y estado de cada decisión o incidencia. | Revisar y confirmar las decisiones que requieran aprobación del centro. |

El equipo enviará un aviso extraordinario cuando una incidencia pueda afectar a un requisito aprobado, una fecha objetivo o la seguridad de los datos. Los cambios de alcance no se darán por aprobados solo por comunicarlos en el informe de estado.

## 10. Valor añadido, beneficios y beneficiarios

### Valor añadido candidato

Estos elementos podrían aportar valor más allá de una agenda básica. Solo se presentarán como valor añadido definitivo cuando se comparen con la petición original y el centro confirme que no estaban ya solicitados.

| Elemento candidato | Valor que se propone aportar | Estado de contraste |
| --- | --- | --- |
| Registro de avance por instrucción | Permitir al alumno identificar pasos pendientes y al personal revisar el progreso de una actividad. | Comparar con la petición original |
| Temporizador visual ligado a una actividad | Hacer visible el tiempo restante y señalar explícitamente el final. | Comparar con la petición original |
| Rutinas preparadas por el personal | Facilitar la reutilización de secuencias de actividades adaptadas a cada alumno. | Comparar con la petición original |

### Beneficios y beneficiarios

| Beneficiario | Número estimado | Beneficio esperado y forma de comprobarlo |
| --- | --- | --- |
| Alumnado PTVAL (directo) | [Confirmar matrícula y usuarios participantes con el centro] | Consultar actividades y seguir instrucciones visuales. Probar los flujos con los perfiles acordados y registrar resultados e incidencias. |
| Profesorado y profesionales de apoyo (directos) | [Confirmar personal que utilizará la aplicación] | Preparar actividades y rutinas y revisar el estado de los pasos. Validar estas tareas durante las pruebas. |
| Familias (indirectas, si procede) | [Confirmar si forman parte del alcance] | Posible continuidad de rutinas entre centro y hogar; no se presupone acceso familiar hasta acordar permisos. |

El número de personas y los indicadores cuantitativos se completarán con datos del centro. No se atribuyen ahorros de tiempo ni mejoras de autonomía antes de establecer una línea de partida y medir la solución con criterios acordados.

## 11. Documentación para el cliente y actas del proyecto

Se mantendrán diferenciadas la documentación para la entidad destinataria y los registros internos del equipo. Los documentos previstos se ajustarán al alcance aprobado y a los formatos y fechas acordados.

### Documentación propuesta para el cliente

| ID | Documento | Contenido previsto | Responsable | Fecha objetivo |
| --- | --- | --- | --- | --- |
| DC-01 | Requisitos y alcance aprobados | Requisitos, prioridades, criterios de aceptación, exclusiones y cambios acordados. | [Asignar] | [dd/mm/aaaa] |
| DC-02 | Guía de uso | Instrucciones para el personal y el alumnado sobre las funciones incluidas en la versión entregada. | [Asignar] | [dd/mm/aaaa] |
| DC-03 | Descripción de la solución | Componentes, perfiles, permisos, requisitos de instalación y dependencias relevantes. | [Asignar] | [dd/mm/aaaa] |
| DC-04 | Informe de pruebas y entrega | Pruebas ejecutadas, resultados, incidencias conocidas y comprobación de criterios de aceptación. | [Asignar] | [dd/mm/aaaa] |
| DC-05 | Instrucciones de administración y mantenimiento | Configuración, gestión de usuarios, copias de seguridad y recuperación, si esas funciones se incluyen en el alcance. | [Asignar] | [dd/mm/aaaa] |

### Registros internos y reuniones

El equipo conservará las actas de sus reuniones, el registro de decisiones y el seguimiento de tareas. Cuando haya reuniones con el centro, se preparará también un acta o resumen validable por las personas asistentes. Las actas internas no se considerarán aprobaciones del cliente; los acuerdos externos se identificarán y confirmarán con sus participantes.

Cada acta incluirá fecha, hora de inicio y fin, asistentes, puntos tratados, decisiones, tareas asignadas, responsables y fechas límite. Se guardará con un nombre uniforme, por ejemplo `ACTA-AAAA-MM-DD-NN`, y se enlazará desde el registro de decisiones cuando origine o modifique un requisito.

### Plantilla de acta

- **Identificador:** [ACTA-AAAA-MM-DD-NN]
- **Tipo de reunión:** [Equipo / cliente / conjunta]
- **Fecha:** [dd/mm/aaaa]
- **Hora de inicio y fin:** [hh:mm–hh:mm]
- **Lugar o medio:** [Completar]
- **Convoca / redacta:** [Completar]
- **Asistentes:** [Nombre y rol de cada persona]

**Puntos tratados y acuerdos**

| N.º | Punto tratado / información relevante | Acuerdo o decisión y persona que lo valida |
| --- | --- | --- |
| 1 | [Completar] | [Completar] |
| 2 | [Completar] | [Completar] |
| 3 | [Completar] | [Completar] |

**Tareas acordadas**

| Tarea / resultado esperado | Responsable | Fecha límite | Estado |
| --- | --- | --- | --- |
| [Completar] | [Completar] | [dd/mm/aaaa] | [Pendiente] |
| [Completar] | [Completar] | [dd/mm/aaaa] | [Pendiente] |

- **Próxima reunión:** [fecha, hora, participantes y objetivo].
- **Revisión del acta:** [personas que revisan y fecha de conformidad].