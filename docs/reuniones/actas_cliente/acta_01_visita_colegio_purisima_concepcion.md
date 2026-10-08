# Acta de Reunión con Cliente nº 01: Visita Presencial al C.E.E. Fundación Purísima Concepción

**Proyecto:** Agenda Accesible - Proyecto AUTOVIDA  
**Entidad Colaboradora / Cliente:** C.E.E. Fundación Purísima Concepción de Granada  
**Asignaturas:** Dirección y Gestión de Proyectos (DGP) & Metodologías de Desarrollo Ágil (MDA) - Grado en Ingeniería Informática, UGR  
**Grupo de Desarrollo:** CLENCH Software Development  
**Fecha:** 02 de octubre de 2026  
**Horario:** 09:30 - 13:30 (Jornada matinal en el centro)  
**Lugar / Modalidad:** Presencial — Instalaciones del C.E.E. Fundación Purísima Concepción (Granada). Recorrido por aulas de PTVAL (Programa de Transición a la Vida Adulta y Laboral), talleres ocupacionales y pabellones del centro.  
**Representante Asistente del Equipo:** Julián Carrión Tovar (Gestor de Usabilidad y Accesibilidad - Representante presencial de CLENCH)  
**Redactor de Notas de Campo:** Julián Carrión Tovar  
**Puesta en Común y Elaboración Documental:** Realizada de forma colaborativa y conjunta por la totalidad del equipo CLENCH Software Development  

---

> [!NOTE] Nota sobre Elaboración Documental y Control de Versiones en GitHub
> Todos los documentos, actas y materiales del proyecto son elaborados de forma conjunta y colaborativa entre todos los miembros del equipo. En esta fase inicial de especificación y coordinación, **Julián Carrión Tovar** es quien colabora en los documentos y se encarga además de subirlos y mantenerlos en el repositorio de **GitHub** para el control de versiones. Conforme avance el proyecto y se intensifique el desarrollo del código software, todos los integrantes del equipo colaborarán activamente realizando aportaciones y *commits* directos en el repositorio.

---

## 1. Asistencia y Participantes

### 1.1 Representantes del Cliente (C.E.E. Fundación Purísima Concepción)
- **Equipo Directivo y Coordinación del Proyecto AUTOVIDA:** Responsables pedagógicos y de innovación del centro.
- **Equipo Docente y Terapeutas:** Profesores de taller, especialistas en Pedagogía Terapéutica (PT), Audición y Lenguaje (AL) y terapeutas ocupacionales.
- **Alumnado Observado:** Grupos de estudiantes de PTVAL en talleres con materiales reciclados y aulas de trabajo.

### 1.2 Representantes de CLENCH Software Development
| Integrante | Rol en el Equipo | Asistencia a la Visita | Observaciones |
| :--- | :--- | :---: | :--- |
| **Julián Carrión Tovar** | Gestor de Usabilidad y Accesibilidad | **Sí (Presencial)** | **Único asistente en representación presencial de todo el equipo** |
| **Miguel Ángel Luque** | Coordinador | Representado | Participación en análisis posterior y redacción colaborativa |
| **José Rodríguez Fernández** | Presentador | Representado | Participación en análisis posterior y redacción colaborativa |
| **Pablo de la Torre Roldán** | Catalogador | Representado | Participación en análisis posterior y redacción colaborativa |
| **Pablo Hernández Ibáñez** | Moderador | Representado | Participación en análisis posterior y redacción colaborativa |
| **Yeray Rodríguez Navas** | Gestor de Calidad | Representado | Participación en análisis posterior y redacción colaborativa |
| **Amine Azzammouri** | Refuerzo de Coordinación | Representado | Participación en análisis posterior y redacción colaborativa |

*Nota:* Debido a las indicaciones de aforo para las visitas al centro escolar, asistió un único representante por grupo de prácticas. Los resultados, observaciones y datos recogidos fueron posteriormente puestos en común con todos los integrantes del equipo.

---

## 2. Objetivo de la Visita
Realizar una sesión de observación directa y toma de requerimientos contextuales in situ en el C.E.E. Fundación Purísima Concepción para:
1. Observar directamente las capacidades motrices, cognitivas, sensoriales y comunicativas de los alumnos de PTVAL interactuando con la tecnología.
2. Cumplimentar la lista de verificación (*checklist*) técnica sobre hardware, sistemas aumentativos y alternativos de comunicación (SAAC), entornos y ayudas técnicas.
3. Conocer de primera mano las rutinas docentes, talleres prácticos y necesidades del profesorado para la gestión de la aplicación *Agenda Accesible*.
4. Recoger requerimientos clave para el diseño de la interfaz de usuario (UI/UX accesible), la arquitectura técnica y el modelo de datos.

---

## 3. Registro Detallado de Observaciones (Checklist de Campo)

### 3.1 Área 1: Habilidades Motrices e Interacción Física
- **Tipo de pulsación:** 
  - El alumnado utiliza principalmente **tabletas digitales**. En los alumnos observados durante la visita no se apreciaron dificultades relevantes en la motricidad fina de las manos; pulsan mayoritariamente con la yema de los dedos con soltura.
  - No obstante, se constata que existen otros alumnos del centro (por ejemplo, en silla de ruedas o con movilidad reducida severa) que utilizan sistemas de control por seguimiento ocular (**Eye Tracking**).
- **Precisión y temblores involuntarios:** 
  - Los alumnos evaluados manejaban la tecnología táctil con solvencia. A pesar de ello, se determinó la necesidad de ser prudentes y blindar la aplicación mediante filtros anti-rebote (márgenes de retardo entre pulsaciones y áreas activas amplias) para prevenir toques involuntarios o accidentales.
- **Gestos complejos vs. gestos simples:** 
  - En general muestran destreza en desplazamientos básicos, pero se desconoce el grado de dominio de gestos complejos como *drag & drop* (arrastrar y soltar), *swipe* rápido o *pinch-to-zoom* (pellizcar para ampliar).
  - **Decisión de diseño:** Prioridad absoluta por **movimientos y gestos simples (*tap* / pulsación directa)**. No supeditar ninguna acción crítica a gestos complejos.
- **Zona de alcance ergonómico en pantalla:** 
  - La zona central de la pantalla es alcanzada con total naturalidad y comodidad.
  - **Criterio obligatorio:** Evitar concentrar opciones críticas o botones en las esquinas o en los extremos perimetrales de la pantalla.
- **Tiempo de respuesta:** 
  - En la mayoría de los casos observados, el tiempo transcurrido desde la aparición de la indicación visual hasta la ejecución de la pulsación por parte del alumno es corto.

---

### 3.2 Área 2: Percepción Visual, Auditiva y Sensorial
- **Sensibilidad visual y estímulos:** 
  - Existen alumnos con diversas dificultades visuales y baja visión. Se debe evitar la emisión de estímulos visuales agresivos: fondos excesivamente brillantes, parpadeos continuos o animaciones rápidas.
  - Se requiere incorporar obligatoriamente **modo claro, modo oscuro, paletas personalizables y modos adaptados a daltonismo** con colores claramente distinguibles.
- **Contraste y legibilidad:** 
  - Se reitera la exigencia de fondos limpios con elementos de alto contraste. Tipografías sans-serif de trazo grueso, legibles y claras.
- **Tamaño de elementos e iconos:** 
  - Aunque no se cuenta con métricas milimétricas cerradas, el tamaño debe ser generoso y fácilmente identificable. Se tomarán como referencia de dimensionamiento los materiales pedagógicos impresos facilitados por el centro.
- **Respuesta auditiva y sensorial:** 
  - Para prevenir episodios de sobrecarga sensorial o fatiga, el sistema de notificaciones debe ser configurable de forma individual por perfil: **voz, sonido acústico o imagen/pictograma**.
- **Feedback háptico:** 
  - Se confirmó que la respuesta mediante **vibración del dispositivo táctil** resulta muy positiva como refuerzo táctil confirmatorio (*"Sería de agradecer"*).

---

### 3.3 Área 3: Comunicación, Lenguaje y Carga Cognitiva
- **Sistemas Aumentativos y Alternativos de Comunicación (SAAC):** 
  - Se constató el uso masivo e interés central en la comunicación por pictografías.
  - El sistema estándar vehicular en el material del colegio es **ARASAAC**.
- **Lectoescritura:** 
  - No hay un nivel uniforme de lectoescritura: conviven alumnos con lectura funcional con otros que dependen enteramente de pictogramas y soporte auditivo.
  - Se contemplan notificaciones por voz y pictogramas. Para los textos escritos, se aplicarán pautas de **Lectura Fácil** y se evitarán estrictamente explicaciones y párrafos largos.
- **Saturación en pantalla y carga cognitiva:** 
  - Se constata la necesidad de mantener pantallas limpias y despejadas: procesan un volumen reducido de estímulos a la vez.
  - **Regla estricta:** Presentar un **número reducido de opciones simultáneas (entre 2 y 4 opciones por pantalla)**, evitando menús saturados.
- **Gestión del error no punitiva:** 
  - La reacción a fallos depende de cada alumno. Se descartan totalmente avisos sonoros estridentes de error o penalizaciones visuales frustrantes (por ejemplo, aspas rojas llamativas).
  - En caso de no poder cumplir una tarea, se facilitará una **tarea alternativa adaptada**, guardando el registro de lo que se ha realizado y lo que ha quedado pendiente sin asociarle carga negativa.
- **Refuerzo positivo y motivación:** 
  - Se mencionaron juegos adaptados y dinámicas personalizadas. El registro de hitos debe servir para motivar y orientar al alumno.

---

### 3.4 Área 4: Dispositivos, Accesorios, Hardware y Conectividad
- **Dispositivos reales del centro:** 
  - En las aulas se utilizan principalmente **tabletas Android** (gama Samsung y similares, resolución HD, dispositivos modernos) y **pizarras digitales interactivas Android**.
- **Fundas protectoras:** 
  - Las tabletas cuentan con fundas rugerizadas de protección que no interfieren ni tapan los márgenes de las pantallas táctiles.
- **Periféricos de apoyo:** 
  - Presencia de sistemas de seguimiento ocular (**Eye Tracking**) para estudiantes con movilidad restringida.
- **Conectividad a Internet:** 
  - En el interior de las instalaciones y aulas existe conexión Wi-Fi estable. Sin embargo, en actividades exteriores, excursiones o desplazamientos fuera del centro no se dispone de conectividad garantizada.
  - **Requisito arquitectónico clave:** La aplicación debe funcionar **100 % de manera autónoma y offline (sin conexión a Internet)**, con almacenamiento en base de datos local y sincronización cuando la red esté disponible.
- **Rendimiento del hardware:** 
  - Los dispositivos Android del centro soportan sin problemas el tipo de aplicación que se desarrollará en Flutter, sin experimentar calentamientos ni consumos excesivos de batería.

---

### 3.5 Área 5: Necesidades de Docentes, Terapeutas y Administración
- **Perfiles de usuario altamente personalizados:** 
  - Se determinó como necesidad prioritaria y crítica: la aplicación es eminentemente personalizable. Cada alumno requiere un perfil que defina cómo desea y puede recibir la información (canal de notificación preferido: voz, sonido o imagen; esquema cromático; tiempos de temporizador; apoyos visuales).
- **Zona de administración protegida:** 
  - Se requiere un **menú de ajustes y configuración protegido mediante credenciales (PIN de 4 dígitos o contraseña)** para evitar modificaciones o salidas accidentales por parte de los alumnos durante el uso.
- **Métricas y seguimiento docente:** 
  - Es conveniente registrar métricas de uso (tiempo empleado, tareas completadas, tareas alternativas requeridas, evolución). Se enfatiza que estos datos son de **uso exclusivo para el centro, los terapeutas y los docentes**, sin exponer evaluaciones punitivas al alumnado.
- **Dinámica pedagógica y nivel de asistencia:** 
  - El trabajo en el centro es colaborativo y grupal, coordinado por los docentes y con figuras de **jefes de proyecto entre los propios alumnos**.
  - Aunque el entorno es tutorizado, la herramienta debe maximizar la autonomía progresiva del estudiante para favorecer su **transición efectiva a la vida adulta**.

---

### 3.6 Área 6: Observaciones de Campo y Notas Extra
Durante el recorrido por las instalaciones se levantaron las siguientes notas de gran relevancia funcional:
1. **Desplazamientos y distribución espacial:**
   - El centro cuenta con pabellones físicamente separados.
   - Existen alumnos con **dificultades de equilibrio motriz** en sus traslados.
   - Surge el requisito de incorporar un **modo de "Ruta / Visita guiada"** que facilite el desplazamiento estructurado por las dependencias del colegio.
2. **Esquema corporal:**
   - Ciertos alumnos carecen de una adecuada percepción o conciencia de su propio cuerpo. Las interfaces deben evitar requerir nociones corporales espaciales complejas.
3. **Tipografía adaptada:**
   - Preferencia clara por el empleo de tipografías legibles y **textos en mayúsculas** para facilitar la lectura inicial.
4. **Trabajo en talleres y grupos dinámicos:**
   - Se realizan talleres con materiales reciclados.
   - Los alumnos trabajan por grupos con nombres que van rotando periódicamente, existiendo en cada iteración la figura rotativa del *jefe de proyecto*.
5. **Diversidad del claustro de profesores:**
   - Coexisten profesores más veteranos junto con educadores jóvenes más acostumbrados a la tecnología. La interfaz del panel docente debe ser sumamente intuitiva, sin curvas de aprendizaje empinadas.
6. **Módulos de personalización de la vida diaria:**
   - Cada estudiante confecciona su propia agenda. Se detectaron casos de uso reales que enriquecen la visión del producto:
     - Agenda escolar estructurada diaria.
     - Cartelera de cine personalizada.
     - Juegos de mesa adaptados.
     - Pastillero y medicación personalizada.
     - Gestión de comandas de comedor (menús, dietas especiales, ausencias y entrega de menús a familias).
7. **Naturaleza de las notificaciones sonoras y voces (*"¿Voces suyas??? No IA"*):**
   - **Requisito determinante:** Se solicita enfáticamente que las notificaciones habladas utilicen **voces humanas familiares y cálidas** (grabadas por docentes o terapeutas del centro), rechazando terminantemente voces sintéticas estridentes o asistentes fríos de inteligencia artificial que puedan provocar confusión, rechazo o sobrecarga sensorial en el alumnado.

---

## 4. Acuerdos y Requisitos Técnicos Derivados

*(Todos los requisitos y acuerdos son asumidos de forma conjunta por el equipo CLENCH Software Development. La concreción y reparto específico de módulos se definirá de manera consensuada conforme madure el Product Backlog).*

| Código | Requisito / Criterio de Diseño | Ámbito de Aplicación | Responsabilidad |
| :---: | :--- | :---: | :--- |
| **[ACU-CLI-01.1]** | **Arquitectura Offline-First:** La app debe operar 100% sin conexión mediante almacenamiento local persistente (SQLite / Hive). | Arquitectura / Backend | Equipo CLENCH (Conjunto) |
| **[ACU-CLI-01.2]** | **Pantallas de Baja Carga Cognitiva:** Máximo 2 a 4 opciones por pantalla, botones grandes y centrados, evitando esquinas. | UI/UX / Frontend | Equipo CLENCH (Conjunto) |
| **[ACU-CLI-01.3]** | **Gestos Simples Únicamente:** Interacción basada en *tap* directo con filtro anti-rebote (*debounce*). No requerir gestos complejos. | Accesibilidad | Equipo CLENCH (Conjunto) |
| **[ACU-CLI-01.4]** | **Pictogramas ARASAAC:** Integración del repositorio estándar de ARASAAC como base visual primaria de comunicación. | Accesibilidad | Equipo CLENCH (Conjunto) |
| **[ACU-CLI-01.5]** | **Personalización Total por Perfil:** Modelo de datos que contemple canal de alerta (voz/sonido/imagen), modo visual (claro/oscuro/alto contraste/daltonismo) y fuentes en mayúsculas. | Modelado de Datos | Equipo CLENCH (Conjunto) |
| **[ACU-CLI-01.6]** | **Locuciones Humanas:** Permitir la subida y reproducción de audios grabados por educadores, evitando síntesis fría por IA. | Accesibilidad / Media | Equipo CLENCH (Conjunto) |
| **[ACU-CLI-01.7]** | **Panel de Administración con PIN:** Acceso protegido a configuraciones docentes y visualización de métricas de uso no punitivas. | Seguridad / Backend | Equipo CLENCH (Conjunto) |
| **[ACU-CLI-01.8]** | **Módulo de Tareas Especiales:** Modelado para comanda de comedor, temporizador visual, reprografía y guiado de rutas por el centro. | Requisitos / Backlog | Equipo CLENCH (Conjunto) |

---

## 5. Próximos Pasos de Trabajo

Las siguientes líneas de trabajo se abordarán de manera transversal y colaborativa por todos los integrantes del equipo durante la Fase Inicial, ajustando el reparto específico según las necesidades de cada entrega:

1. **Elaboración de Personajes y Escenarios (P0/P1):** Modelado de perfiles reales de alumnado y docentes basados en la visita.
2. **Definición de Bocetos y Wireframes Iniciales:** Prototipos de navegación simplificada (2 a 4 opciones) y contraste accesible.
3. **Estudio de Arquitectura Técnica y Persistencia Local:** Planteamiento de la estructura Flutter con soporte *offline*.
4. **Consolidación del Modelo de Datos Preliminar:** Esquema para perfiles personalizados, agendas, tareas y métricas docentes.
5. **Revisión Continua de Entregables:** Refinamiento grupal de toda la documentación previa a las fechas de entrega oficial.

---

## 6. Próxima Interacción con el Cliente
- **Fecha Prevista:** Segunda quincena de octubre de 2026 (coincidiendo con la entrega de la fase de especificación y primeros prototipos interactivos).
- **Modalidad:** Consulta telemática / Presencial con el profesorado de prácticas y representantes del colegio.
- **Objetivo Principal:** Presentar y validar los wireframes de navegación simplificada, el catálogo de pictogramas ARASAAC y la estructura del panel docente protegido por PIN.

---

**Acta elaborada y consensuada por el equipo CLENCH Software Development.**  
*En Granada, a 02 de octubre de 2026.*
