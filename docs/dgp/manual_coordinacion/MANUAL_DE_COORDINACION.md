# MANUAL DE COORDINACIÓN Y PLAN DE DIRECCIÓN DEL PROYECTO

> **Asignaturas:** Dirección y Gestión de Proyectos (DGP) & Metodologías de Desarrollo Ágil (MDA)  
> **Titulación:** Grado en Ingeniería Informática — Universidad de Granada (UGR)  
> **Curso Académico:** 2026 / 2027  
> **Proyecto:** Sistema de Agenda y Asignación de Tareas Accesible (Proyecto AUTOVIDA — Fundación Purísima Concepción)  
> **Grupo de Prácticas:** Grupo [X] — Subgrupo [Y]  
> **Versión del Documento:** 1.0 (Borrador de Inicio)  
> **Fecha de Elaboración:** 24 de septiembre de 2026  

---

## Firma y Aceptación de los Miembros del Equipo

*Este documento ha sido consensuado, completado y aprobado por todos los integrantes del equipo de trabajo, quienes se comprometen a cumplir con los acuerdos, normativas y procesos descritos a continuación.*

| Nombre y Apellidos | DNI / Identificador | Correo Institucional UGR | Asignatura(s) | Firma de Compromiso |
| :--- | :---: | :---: | :---: | :---: |
| [Miembro 1 - Estudiante A] | 12345678A | estudianteA@correo.ugr.es | DGP / MDA | *Firmado* |
| [Miembro 2 - Estudiante B] | 23456789B | estudianteB@correo.ugr.es | DGP / MDA | *Firmado* |
| [Miembro 3 - Estudiante C] | 34567890C | estudianteC@correo.ugr.es | DGP / MDA | *Firmado* |
| [Miembro 4 - Estudiante D] | 45678901D | estudianteD@correo.ugr.es | DGP / MDA | *Firmado* |
| [Miembro 5 - Estudiante E] | 56789012E | estudianteE@correo.ugr.es | DGP | *Firmado* |
| [Miembro 6 - Estudiante F] | 67890123F | estudianteF@correo.ugr.es | MDA | *Firmado* |

---

## 1. METODOLOGÍA DE DESARROLLO Y CICLO DE VIDA

### 1.1 Modelo de Ciclo de Vida
El proyecto se desarrollará bajo un ciclo de vida de **prototipado evolutivo**, integrando el marco ágil de trabajo de la asignatura **MDA** (Scrum/Kanban adaptado a entornos académicos) con las buenas prácticas de dirección, gestión de alcance, costes, riesgos y plazos de **DGP**.

El desarrollo se articula en **cuatro entregas principales**:
1. **Fase Inicial (Entrega de primeros documentos - 21/22 de octubre de 2026):**
   - Constitución formal del equipo, Manual de Coordinación y Plan de Dirección.
   - Entrevista con el cliente (Colegio Purísima Concepción) y visita al centro.
   - Definición de Personajes, Escenarios y Visión del Producto (MDA - P0 y P1).
   - Elaboración de la Propuesta Técnica preliminar y estimación inicial de costes.
   - Product Backlog inicial y Plan de Entregas (MDA - P2).
2. **Iteración 1 (22 de octubre – 11/12 de noviembre de 2026):**
   - Sprint 1: Arquitectura base, configuración del entorno, módulo central de perfiles de usuario accesibles y estructura básica de agenda.
   - Primer prototipo funcional desplegado y evaluación intermedia.
3. **Iteración 2 (12 de noviembre – 2/3 de diciembre de 2026):**
   - Sprint 2: Implementación de flujos de tareas del centro (reprografía, gestión de comedores/dietas, guía de visitas) y temporizador visual accesible.
   - Sesión de revisión y validación preliminar con el centro.
4. **Iteración 3 (3 de diciembre – 21 de diciembre de 2026):**
   - Sprint 3: Tareas personales, chat accesible tutor-estudiante, ajustes de accesibilidad física y cognitiva, estabilización y pruebas finales.
   - Consolidación de informes de calidad, auditoría de accesibilidad y entrega de código final.
5. **Defensa Final (12 de enero de 2027):**
   - Presentación oral y demostración en vivo del software ante el tribunal y clientes.

### 1.2 Eventos y Ceremonias Ágiles Adaptadas
- **Sprint Planning (Inicio de iteración):** Desglose de historias de usuario en tareas técnicas, asignación de responsables y estimación de esfuerzo en horas y Story Points.
- **Seguimiento Continuo (Weekly & Asynchronous Standup):**
  - Reunión semanal obligatoria durante la sesión de prácticas con el profesor/tutor.
  - Sincronización asíncrona mediante Discord/Telegram para reportar: qué se hizo ayer, qué se hará hoy y qué impedimentos existen.
- **Sprint Review & Demo (Final de iteración):** Demostración del incremento de software potencialmente desplegable ante el docente y/o representantes del cliente.
- **Sprint Retrospective:** Análisis de aspectos positivos a mantener, problemas detectados y plan de mejora continua para el siguiente ciclo.

---

## 2. RECURSOS SOFTWARE Y DESARROLLO

Para la ejecución homogénea del proyecto se seleccionan herramientas colaborativas estándar, garantizando interoperabilidad y trazabilidad:

| Área / Finalidad | Herramienta Propuesta | Justificación y Uso |
| :--- | :--- | :--- |
| **Control de Versiones** | **Git / GitHub** | Repositorio central, flujo mediante Pull Requests, trazabilidad de código y documentación. |
| **Gestión de Tareas y Backlog** | **Jira Software / GitHub Projects** | Tablero Kanban y Scrum, seguimiento de historias de usuario, estimaciones de tiempo y burndown charts. |
| **Diseño y Prototipado UI/UX** | **Figma / Penpot** | Creación de wireframes y prototipos interactivos adaptados a usuarios con discapacidad cognitiva. |
| **Recursos de Accesibilidad** | **Portal ARASAAC** | Catálogo oficial de pictogramas bajo licencia Creative Commons para comunicación aumentativa. |
| **Auditoría de Accesibilidad** | **WAVE, axe DevTools, Colour Contrast Analyser, TalkBack, VoiceOver** | Verificación de contraste cromático, lectores de pantalla para móviles y cumplimiento WCAG 2.1 AA. |
| **Control de Calidad y Linters** | **SonarCloud / Linters específicos** | Análisis estático de código, detección de code smells, vulnerabilidades y métricas de complejidad ciclomática. |
| **Comunicación del Equipo** | **Discord & WhatsApp / Telegram** | Canales temáticos para comunicación síncrona y avisos urgentes. |
| **Reuniones Telemáticas** | **Google Meet / Microsoft Teams** | Sesiones de trabajo grupales, entrevistas grabadas y reuniones con docentes/clientes. |
| **Gestión Documental** | **Repositorio Git (`docs/`) & Google Drive** | Repositorio formal versionado en Markdown y copias de seguridad de material multimedia compartido. |

---

## 3. ORGANIZACIÓN DEL EQUIPO DE TRABAJO (ESTRUCTURA, NORMAS)

### 3.1 Estructura de Roles del Equipo (6 Integrantes)
El equipo combina roles fijos de especialización (calidad y accesibilidad) con roles rotatorios en cada iteración para garantizar que todos los miembros desarrollen competencias de dirección y gestión técnica:

```text
                               ┌────────────────────────┐
                               │   COORDINADORES (2)    │
                               │ (Rotatorio por Sprint) │
                               └───────────┬────────────┘
                                           │
         ┌─────────────────────────────────┼────────────────────────────────┐
         │                                 │                                │
┌────────┴──────────────┐       ┌──────────┴─────────────┐       ┌──────────┴─────────────┐
│  GESTOR DE CALIDAD    │       │ AUDITOR ACCESIBILIDAD  │       │ MODERADOR / CATALOGADOR│
│ (Fijo durante proyecto│       │ (Fijo durante proyecto)│       │ (Rotatorio / Apoyo)    │
└───────────────────────┘       └────────────────────────┘       └────────────────────────┘
```

1. **Coordinadores (2 miembros en cada iteración):**
   - Responsables de liderar la planificación temporal, seguimiento del cronograma, asignación equitativa de cargas y reporte al profesor.
   - En cada iteración asumen la coordinación 2 miembros diferentes, de modo que todos roten (salvo los 2 gestores fijos).
2. **Gestor de la Calidad (Rol fijo - no rota):**
   - Supervisa el cumplimiento de la metodología, la calidad del proceso y del producto.
   - Revisa la correctitud y completitud de todos los entregables antes de su envío.
   - Monitoriza métricas de código, cobertura de pruebas y resolución de incidencias.
3. **Auditor de Usabilidad y Accesibilidad (Rol fijo - no rota):**
   - Responsable de velar por el cumplimiento de las normativas de accesibilidad (WCAG 2.1 AA, heurísticas de usabilidad cognitiva).
   - Forma a los compañeros en diseño accesible y prueba la aplicación con herramientas de asistencia (TalkBack, switch, lectores).
   - Valida la idoneidad de los pictogramas de ARASAAC y la claridad visual de las pantallas.
4. **Catalogador (Rol rotatorio / compartido):**
   - Gestiona la estructura de documentación en el repositorio, la correcta nomenclatura de archivos y el control de versiones documental.
5. **Moderador (Rol rotatorio / compartido):**
   - Convoca las reuniones, modera los debates, vela por el cumplimiento de los tiempos y recopila la información para la redacción de las actas.
6. **Presentador (Rol rotatorio):**
   - Coordina y prepara el material audiovisual y diapositivas de las defensas orales ante el cliente y el profesorado en cada iteración.

### 3.2 Matriz de Asignación de Roles por Iteración

| Miembro | Asignatura | Fase Inicial | Iteración 1 | Iteración 2 | Iteración 3 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **[Estudiante A]** | DGP / MDA | **Coordinador** | Frontend / Pruebas | Backend / Pruebas | **Coordinador** |
| **[Estudiante B]** | DGP / MDA | **Coordinador** | Backend / DevOps | Frontend / Pruebas | Presentador / Dev |
| **[Estudiante C]** | DGP / MDA | **Gestor de Calidad** | **Gestor de Calidad** | **Gestor de Calidad** | **Gestor de Calidad** |
| **[Estudiante D]** | DGP / MDA | **Auditor Accesib.** | **Auditor Accesib.** | **Auditor Accesib.** | **Auditor Accesib.** |
| **[Estudiante E]** | DGP | Catalogador / Doc | **Coordinador** | Moderador / Doc | Backend / Gestión |
| **[Estudiante F]** | MDA | Moderador / Req | Presentador / Front | **Coordinador** | Frontend / Pruebas |

*Nota: La rotación asegura que los integrantes participen alternativamente en tareas de Frontend, Backend, Documentación y Pruebas, cumpliendo el requisito docente.*

### 3.3 Normas de Convivencia y Compromiso
1. **Puntualidad:** Asistencia puntual a las reuniones presenciales y virtuales (margen de cortesía: 5 minutos).
2. **Transparencia:** Notificar de inmediato cualquier bloqueo o imposibilidad de cumplir con un plazo al menos **48 horas antes** de la fecha acordada.
3. **Respeto e Inclusión:** Fomentar un ambiente constructivo, escuchando las opiniones de todos y tomando decisiones por consenso o por mayoría cualificada si no hay acuerdo unánime.
4. **Dedicación Equitativa:** Cada miembro debe registrar sus horas reales de trabajo individual semanalmente en la plantilla oficial.
5. **Régimen Sancionador Interno:**
   - La falta injustificada a 2 reuniones o el incumplimiento reiterado de entregables asignados implicará una amonestación interna y su reflejo negativo en la evaluación individual entregada a los profesores.

---

## 4. HERRAMIENTAS PARA COMUNICACIONES EN EL EQUIPO DE TRABAJO

### 4.1 Canales Oficiales
- **Canal Discord del Equipo:**
  - `#general`: Avisos generales, enlaces y anuncios oficiales.
  - `#desarrollo-front`: Discusiones técnicas de interfaz y experiencia de usuario.
  - `#desarrollo-back`: Modelado de base de datos, APIs y lógica de servidor.
  - `#calidad-accesibilidad`: Auditorías, dudas sobre WCAG, feedback de usabilidad y ARASAAC.
  - `#gestion-dgp`: Presupuestos, riesgos, actas y documentación de entregas.
- **Grupo de Mensajería Instantánea (WhatsApp / Telegram):**
  - Exclusivo para urgencias de última hora, avisos de inicio de reunión o imprevistos de fuerza mayor.
- **Correo Institucional (@correo.ugr.es):**
  - Único medio para comunicaciones formales con el profesorado y responsables del Colegio Purísima Concepción.

### 4.2 Protocolo de Reuniones y Actas
- **Periodicidad:**
  - Reunión fija semanal en horario de prácticas con el profesor responsable.
  - Reunión interna de planificación/sincronización de 1 hora semanal (habitualmente lunes por la tarde).
- **Actas:**
  - Toda reunión formal contará con un acta redactada por el Catalogador/Moderador según la plantilla oficial (`docs/plantillas/plantilla_acta_reunion.md`).
  - El acta se publicará en `docs/reuniones/` en un plazo máximo de **24 horas** tras la finalización de la reunión.

---

## 5. RELACIONES CON EL CLIENTE (ENTREVISTAS, REUNIONES, REVISIONES)

### 5.1 Interlocutores del Proyecto
- **Cliente Principal:** Dirección y personal docente del Colegio de Educación Especial Fundación Purísima Concepción (Fundación Hospitalarias - Granada).
- **Destinatarios Finales:** Estudiantes con necesidades educativas especiales del Programa de Transición a la Vida Adulta (PTVAL), tutores escolares y familiares.
- **Peticionarios y Evaluadores:** Profesorado de las asignaturas DGP y MDA de la Universidad de Granada.

### 5.2 Hitos de Interacción y Protocolo
1. **Entrevista Inicial de Requisitos (25 de septiembre de 2026 - 08:30h):**
   - Asistencia en la sesión de teoría para formular las preguntas preparadas previamente y captar necesidades reales.
2. **Visita Técnica al Centro (02 de octubre de 2026):**
   - Asistencia de los representantes designados para observar los espacios de trabajo (taller de reprografía, comedor, aulas) y comprender los flujos cotidianos.
3. **Validaciones Intermedias de Prototipos:**
   - En las iteraciones 1 y 2 se concertarán revisiones con el cliente para mostrar los bocetos y prototipos de la agenda, verificando la compresión cognitiva de los pictogramas y la sencillez de los flujos.
4. **Formalidad y Trato:**
   - Máximo respeto, empatía y sensibilidad hacia la labor social y educativa del centro.
   - Todo material audiovisual o fotográfico del centro estará sujeto al consentimiento expreso y la normativa de protección de datos (RGPD).

---

## 6. ESTÁNDARES DE DOCUMENTACIÓN

### 6.1 Formato y Estructura
- Toda la documentación viva del proyecto se redactará en formato **Markdown (`.md`)** en el repositorio Git para permitir control de versiones línea a línea.
- Para las entregas oficiales en la plataforma docente de la UGR, los documentos se compilarán a formato **PDF estándar**, incluyendo:
  - Portada oficial con logotipo de la UGR, título del proyecto, número de grupo, nombres de autores y fecha.
  - Tabla de contenidos con numeración clara de apartados y subapartados.
  - Historial de cambios y control de versiones del documento.

### 6.2 Nomenclatura de Archivos
- Se utilizará formato en minúsculas separado por guiones bajos o la nomenclatura estandarizada:
  - Actas: `ACTA_EQUIPO_[AÑO]_[MES]_[DIA].md` (ej. `ACTA_EQUIPO_2026_10_05.md`)
  - Documentos técnicos: `DOC_[AMBITO]_[NOMBRE]_[vX.Y].md`

---

## 7. ESTÁNDARES DE CÓDIGO

### 7.1 Principios Generales
- **Clean Code:** Código legible, modular, auto-explicativo y con funciones de responsabilidad única (principios SOLID).
- **Desacoplamiento:** Clara separación entre la capa de presentación (frontend), capa de negocio y acceso a datos (backend).
- **Comentarios Relevantes:** Comentar únicamente la lógica compleja o decisiones no triviales; evitar comentarios redundantes que repitan el código.

### 7.2 Convenciones de Nomenclatura y Estilo
- Nombres de clases y componentes: `PascalCase` (ej. `BotonAccesible`, `TareaService`).
- Funciones, métodos y variables: `camelCase` (ej. `obtenerTareasPorEstudiante`, `esModoContrasteAlto`).
- Constantes y enumerados: `UPPER_SNAKE_CASE` (ej. `ESTADO_TAREA_COMPLETADA`).
- Uso obligatorio de linters y formateadores de código (configurados en el repositorio) para asegurar consistencia automática en cada commit.

---

## 8. PLAN DE GESTIÓN DE CAMBIOS

Ante cualquier solicitud de cambio (proveniente del cliente, del profesorado o de una necesidad técnica surgida durante el desarrollo), se seguirá el siguiente procedimiento formal:

```text
  [Propuesta de Cambio] 
          │
          ▼
  [Análisis de Impacto] (Alcance, Plazos, Horas, Calidad, Accesibilidad)
          │
          ▼
  [Revisión del Coordinador y Gestor de Calidad]
          │
     ┌────┴──────────────┐
     │                   │
  [Aprobado]         [Rechazado / Pospuesto]
     │                   │
     ▼                   ▼
[Actualizar Backlog   [Notificación y registro
 y Cronograma]         del motivo]
```

1. **Registro:** Cumplimentar una solicitud de cambio formal indicando origen, justificación y descripción.
2. **Evaluación de Impacto:** Los coordinadores de la iteración y el gestor de calidad analizarán el impacto en:
   - Fechas límite del pliego técnico.
   - Carga de trabajo y horas asignadas a los miembros.
   - Requisitos de accesibilidad y riesgos técnicos.
3. **Decisión:** Si el cambio altera las fechas o el alcance pactado con el cliente o profesor, se requerirá comunicación previa justificada con al menos **3 días de antelación**, tal como exige el pliego técnico.

---

## 9. CONTROL DE VERSIONES (MÉTODO Y HERRAMIENTAS)

### 9.1 Estrategia de Trabajo Colaborativo en Rama Única (`main`)
Para mantener un flujo de trabajo ágil, directo y sin sobrecarga innecesaria de ramas o Pull Requests, el equipo trabajará de manera coordinada **directamente sobre la rama principal (`main`)**.

Para asegurar la estabilidad del proyecto y evitar sobrescrituras de código o conflictos, se establecen las siguientes **normas obligatorias**:
1. **Sincronización Continua (`git pull`):** Antes de iniciar cualquier tarea, y obligatoriamente antes de hacer `git push`, cada miembro debe ejecutar `git pull` para incorporar las novedades subidas por los compañeros.
2. **Coordinación Activa y Reparto Modular:** Los miembros del equipo se asignarán componentes, pantallas o documentos independientes. Cuando alguien vaya a modificar un archivo central o compartido, lo notificará previamente al grupo para evitar conflictos de edición simultánea.
3. **Validación Local Estricta:** Queda prohibido subir código roto a `main`. Cada miembro debe verificar localmente que el proyecto compila, ejecuta y no genera errores antes de hacer `push`.
4. **Commits Atómicos y Claros:** Se realizarán commits pequeños y bien delimitados, facilitando identificar cambios y revertir si fuera necesario.

### 9.2 Convención de Commits (Conventional Commits)
Los mensajes de confirmación seguirán el formato:
`<tipo>: <descripción concisa>`

Tipos permitidos:
- `feat`: Nueva funcionalidad o avance del sistema.
- `fix`: Corrección de un fallo o defecto.
- `docs`: Modificación exclusiva de documentación o actas.
- `style`: Ajustes estéticos o formateo sin cambios lógicos.
- `refactor`: Refactorización de código.
- `test`: Inclusión o ajuste de pruebas.
- `chore`: Mantenimiento, dependencias o configuración.
- `a11y`: Ajustes específicos de accesibilidad y usabilidad.

*Ejemplo:* `feat: agregar temporizador visual con cuenta atras accesible`

---

## 10. GESTIÓN DE CALIDAD Y ACCESIBILIDAD

### 10.1 Gestión de Calidad (Proceso y Producto)
- **Definition of Ready (DoR):** Una tarea solo se inicia si cuenta con objetivos claros y requisitos de accesibilidad identificados.
- **Definition of Done (DoD):** Una tarea solo se considera finalizada cuando:
  - El código ha sido probado localmente y compila sin errores.
  - Se han superado los linters y pruebas correspondientes.
  - La interfaz cumple con los criterios de accesibilidad aplicables.
  - Ha sido sincronizada y subida a `main` sin conflictos.
  - La documentación asociada está actualizada.
- **Control de Entregables:** El Gestor de Calidad realiza una revisión formal de corrección, ortografía, formato y completitud 48 horas antes de cada entrega oficial.

### 10.2 Gestión de Usabilidad y Accesibilidad
La accesibilidad no es un añadido final, sino el núcleo del diseño del proyecto:
- **Estándar WCAG 2.1 Nivel AA:** Cumplimiento estricto en ratios de contraste (mínimo 4.5:1 para texto normal, 3:1 para elementos gráficos).
- **Adaptación Cognitiva:**
  - Interfaces limpias, libres de distracciones, con navegación predictiva y retroalimentación clara.
  - Integración sistemática de pictogramas ARASAAC para reforzar visualmente cada texto y acción.
  - Disponibilidad de secuencias visuales paso a paso para la realización de tareas complejas (reprografía, menús, etc.).
- **Accesibilidad Física y Sensorial:**
  - Objetivos táctiles de al menos 48x48 dp para facilitar la pulsación en casos de problemas de motricidad fina.
  - Compatibilidad verificada con lectores de pantalla móviles (**TalkBack** en Android y **VoiceOver** en iOS).
  - Opciones de personalización de perfil: modo de contraste alto, tamaños de fuente ajustables y temporizadores configurables (visibles u ocultos según necesidad del usuario).

---

## 11. PLAN DE MEDICIÓN DEL DESEMPEÑO Y RECOMPENSAS

### 11.1 Registro y Control del Esfuerzo
- Cada integrante completará su **registro individual de dedicación horaria** semanalmente (`docs/plantillas/plantilla_registro_horas.md`), contabilizando el tiempo exacto invertido en desarrollo, gestión, reuniones y documentación.
- Los coordinadores y el Gestor de Calidad consolidarán las horas en cada iteración para detectar a tiempo sobrecargas o desviaciones de esfuerzo.

### 11.2 Evaluación 360º y Autoevaluación
- Al finalizar cada una de las 3 iteraciones, cada miembro completará una encuesta de autoevaluación y co-evaluación interna valorando:
  - Grado de cumplimiento de las tareas asignadas.
  - Calidad del trabajo aportado.
  - Actitud proactiva, colaboración y capacidad de comunicación.
- Los resultados se comentarán constructivamente en la reunión de retrospectiva para tomar acciones de compensación.

### 11.3 Plan de Recompensas y Reconocimiento
- **Reconocimiento Interno:** En cada retrospectiva se destacará formalmente el rol o miembro que haya realizado aportes excepcionales de innovación, calidad o soporte al equipo.
- **Rotación Preferencial:** Aquellos miembros que hayan completado sus tareas con anticipación y excelencia tendrán prioridad para elegir roles y módulos de desarrollo en la siguiente iteración.
- **Distribución Equitativa de Calificación:** El objetivo del equipo es garantizar que la calidad global del proyecto y la implicación demostrada en los informes de gestión permitan a todos los miembros aspirar a la máxima calificación posible (10) en la evaluación de prácticas.
