# TAREA: Auditoría de Accesibilidad del Frontend Flutter (AUTOVIDA)

## 1. Contexto del Proyecto y Perfil de Usuario
* **Proyecto:** AUTOVIDA · Sistema de agenda visual y gestión de actividades adaptadas.
* **Cliente / Centro:** Colegio de Educación Especial (CeRA) Hermanas Hospitalarias - Fundación Purísima Concepción (Granada).
* **Usuarios Finales:**
  * **Alumnado con NEE (Necesidades Educativas Especiales) y TEA (Trastorno del Espectro Autista):** Requieren consistencia cognitiva absoluta, apoyos visuales (pictogramas ARASAAC), lenguaje directo y libre de ambigüedad, evitar sobrecarga sensorial, y soporte para dificultades motrices (grandes áreas de pulsación).
  * **Personal Docente / Terapeutas / Cuidadoras:** Creación rápida y supervisión de tareas y pasos.
  * **Familias / Tutores:** Consulta de agenda y registro del hogar.
* **Estándares del Proyecto:** WCAG 2.2 Nivel AA/AAA (con especial foco en criterio 1.4.3 de contraste mínimo, 2.5.5/2.5.8 de tamaño de objetivo táctil y 4.1.2 de nombre/función/valor).

---

## 2. Archivos a Auditar en `src/frontend/`
* `src/frontend/lib/ui/components.dart`: Definición del tema (`appTheme`), paletas de color, botones, tarjetas, `SpeechButton` (TTS) y avatares.
* `src/frontend/lib/screens/auth_screens.dart`: Pantallas de bienvenida (`WelcomeScreen`), selección de aula (`StudentClassesScreen`), selección de alumno por foto (`StudentSelectionScreen`) y login con teclado visual numérico (`LoginScreen`).
* `src/frontend/lib/screens/student_screens.dart`: `AgendaScreen`, `DaysScreen`, `TaskDetailScreen` y ejecución paso a paso con temporizador (`TaskRunScreen`).
* `src/frontend/lib/screens/task_editor_screen.dart`: Editor de tareas y pasos.
* `src/frontend/lib/screens/settings_screen.dart`: Pantalla de ajustes de accesibilidad (contraste, talkback, tamaños).

---

## 3. Dimensiones de la Auditoría Requerida

### A. Accesibilidad Visual y Contraste (WCAG 1.4)
1. **Ratio de Contraste:** ¿Cumplen todos los estados (normal, deshabilitado, enfocado, seleccionado) un ratio mínimo de 4.5:1 para texto normal y 3:1 para texto grande y componentes gráficos?
2. **Dependencia del Color:** ¿Hay estados de tareas o pasos (pendiente, en curso, completado) que dependan únicamente del color verde/rojo/ámbar sin etiqueta de texto o icono diferenciador?
3. **Escalabilidad de Texto y Botones:** ¿Qué ocurre con la interfaz cuando el usuario activa texto grande o ajusta el tamaño en `SettingsScreen`? ¿Hay riesgo de desbordamiento (`RenderFlex overflow`)?

### B. Accesibilidad Cognitiva (TEA / Discapacidad Intelectual)
1. **Pictogramas e Iconografía:** Actualmente se utilizan iconos de Material Design (`Icons.work_outline`, `Icons.spa_outlined`). ¿Son lo suficientemente claros para alumnos con TEA o deben reemplazarse por pictogramas oficiales de ARASAAC?
2. **Claridad del Lenguaje:** ¿Las instrucciones son cortas (máximo 1 instrucción por frase)? ¿Se evita el uso indiscriminado de MAYÚSCULAS?
3. **Temporizadores y Ansiedad:** En `TaskRunScreen` (`TaskTimer`), ¿el temporizador genera estrés o dispone de controles claros de pausa y tiempo flexible?
4. **Previsibilidad y Navegación:** ¿La navegación (flechas, volver al inicio, botones de confirmación) es uniforme y predecible entre pantallas?

### C. Accesibilidad Motriz y Táctil (WCAG 2.5)
1. **Target Size (Tamaño de Objetivo):** ¿Tienen todos los botones interactivos, casillas de verificación y tarjetas un área de toque mínima recomendada para pantallas táctiles (mínimo 48x48 dp, idealmente 56x56 dp o 64x64 dp para educación especial)?
2. **Espaciado:** ¿Existe suficiente separación entre botones adyacentes para evitar toques accidentales por temblor o espasticidad?

### D. Lectores de Pantalla y Soporte Asistido (WCAG 4.1)
1. **Semantics de Flutter:** ¿Están los widgets envueltos en `Semantics` con `label`, `hint` y `button: true` para que TalkBack / VoiceOver anuncien correctamente qué es cada elemento?
2. **Fotos y Pictogramas sin Texto Alternativo:** ¿Los avatares y las imágenes de pasos tienen su descripción de accesibilidad?
3. **Botón de Lectura en Voz Alta (`SpeechButton`):** ¿Está disponible en todos los lugares donde un alumno no lector necesita que la app le hable?

---

## 4. Salida Esperada de Claude
1. **Resumen Ejecutivo:** Diagnóstico general del estado actual de accesibilidad del frontend.
2. **Hallazgos Críticos:** Puntos donde la interfaz actual incumple WCAG o las necesidades de alumnos con TEA.
3. **Propuestas de Mejora Concretas:** Lista priorizada de cambios en el código (widget por widget) para elevar la accesibilidad al máximo nivel.
