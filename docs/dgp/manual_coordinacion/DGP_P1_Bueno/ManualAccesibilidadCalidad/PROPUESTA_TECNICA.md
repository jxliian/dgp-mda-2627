# Manual de Accesibilidad y Calidad — Proyecto AUTOVIDA

**Equipo:** CLENCH Software Development
**Responsables del manual:** Julián Carrión Tovar (accesibilidad) y Yeray Rodríguez Navas (calidad)
**Curso:** 2026–2027

## 1. Propósito y alcance

Este manual reúne prácticas y una formación inicial para incorporar accesibilidad y calidad en el diseño, desarrollo y revisión de AUTOVIDA. Está dirigido a todo el equipo. Esta primera versión desarrolla colores, legibilidad y uso de mayúsculas, ausencia de ventanas emergentes, fundamentos de backend y controles de calidad. Se ampliará cuando se definan nuevas necesidades con el centro y las personas usuarias.

La accesibilidad y la calidad se trabajan desde el inicio. Las pautas no sustituyen las pruebas con alumnado y profesionales ni la validación de requisitos concretos.

## 2. Frontend: diseño visual

### Colores y contraste

- Definir una paleta reducida, consistente y con funciones claras para acciones, información, avisos y errores.
- Comprobar el contraste entre texto y fondo con una herramienta; como referencia, usar al menos 4,5:1 para texto normal y 3:1 para texto grande.
- No comunicar estados solo mediante el color. Acompañar, por ejemplo, una tarea urgente de una etiqueta o explicación, no solo de color rojo.
- Acompañar los botones con símbolos reconocibles y etiquetas de texto claras; mantener el mismo símbolo para la misma acción. El símbolo complementa el texto, no lo sustituye, para que la función se entienda aunque no se perciba el color.
- Revisar los estados de foco, selección y deshabilitado, así como los fondos con imágenes o degradados.
- Mantener el mismo significado para cada color en todas las pantallas.

### Texto legible

- Elegir una tipografía sencilla y tamaños cómodos en los dispositivos objetivo.
- Permitir ampliar el texto sin que se corte o solape; revisar móvil y escritorio.
- Usar frases directas, vocabulario cotidiano y una instrucción por frase.
- Separar títulos, instrucciones y acciones; evitar bloques densos y líneas excesivamente largas.
- Reservar las MAYÚSCULAS para rótulos breves, siglas o avisos puntuales. No escribir instrucciones o párrafos completos en mayúsculas.

## 3. Frontend: interacción y contenido

### Evitar ventanas emergentes

No mostrar ventanas emergentes automáticas, publicitarias o innecesarias. Presentar la información habitual en la propia pantalla y junto a la acción relacionada. Los avisos no urgentes no deben robar el foco ni desaparecer antes de poder leerse. Los errores deben explicar cómo continuar y conservar los datos introducidos.

Si una decisión importante requiere un diálogo, justificarlo y diseñarlo para que explique el motivo y las opciones, tenga botones con nombres claros, gestione el foco al abrir y cerrar y permita cancelar cuando sea seguro. No abrir diálogos al cargar una página ni para información rutinaria.

### Mensajes y controles

- Nombrar acciones de forma concreta: «Guardar tarea» en vez de «Aceptar» cuando ese sea el resultado.
- Usar términos consistentes y explicar los errores sin jerga ni códigos aislados.
- Etiquetar los controles; no depender de iconos sin texto, color o sonido como único canal.
- Mantener orden de teclado predecible y foco visible; probar ampliación de texto y navegación sin ratón.

## 4. Formación básica de backend

El backend procesa reglas y datos fuera de la pantalla. En una operación típica, la interfaz envía una petición; el servidor valida los datos y permisos; consulta o actualiza el almacenamiento; y devuelve un resultado que la interfaz presenta de forma comprensible.

Conceptos básicos:

- **API:** operaciones definidas para intercambiar datos entre interfaz y servidor.
- **Base de datos:** almacenamiento organizado que debe evitar datos inconsistentes y conservar solo lo necesario.
- **Autenticación:** identifica quién accede. **Autorización:** determina qué puede hacer.
- **Validación:** comprueba en el servidor que los datos recibidos cumplen las reglas. Nunca se confía únicamente en la validación de pantalla.
- **Errores:** las respuestas deben ser previsibles y útiles para la interfaz, sin revelar detalles técnicos internos.

Para cada función, describir acción, petición, validaciones, reglas, lectura/escritura, respuesta y mensaje visible. El equipo debe comprender este flujo aunque no todo el mundo programe backend.

## 5. Prácticas de backend

- Validar en servidor campos obligatorios, tipos, formatos y límites; aplicar reglas de negocio de forma consistente.
- Guardar únicamente datos necesarios y mantener relaciones y estados coherentes.
- Comprobar permisos en cada operación protegida y aplicar el mínimo acceso necesario; ocultar un botón no sustituye esta comprobación.
- No exponer contraseñas, claves, datos personales ni trazas técnicas en mensajes o registros. Limitar el acceso a datos del alumnado y no reutilizarlos en pruebas sin protección y autorización adecuadas.
- Diferenciar éxito, datos inválidos, falta de permisos y fallos técnicos. No indicar que se guardó una tarea si la operación falló.
- Definir y probar copias de seguridad y recuperación cuando corresponda al alcance y a la infraestructura acordados.

## 6. Prácticas de calidad

1. Acordar el resultado esperado y cómo verificarlo.
2. Identificar casos normales, errores previsibles y necesidades de accesibilidad antes de implementar.
3. Mantener los cambios pequeños y centrados.
4. Pedir revisión a otra persona y probar el cambio.
5. Registrar resultados, incidencias, decisiones y pendientes.

Tipos de prueba: **unitarias** (reglas aisladas), **de integración** (componentes conectados), **de flujo completo** (recorrido de interfaz a servidor) y **de aceptación** (contraste con requisitos acordados). Las pruebas automáticas ayudan, pero no sustituyen la revisión visual, el teclado ni las pruebas con personas usuarias.

Una tarea se considera terminada cuando cumple sus criterios, se han hecho las pruebas pertinentes, otra persona ha revisado el cambio, los bloqueos están resueltos o comunicados y la documentación afectada está actualizada.

## 7. Formación y revisión del equipo

Se proponen tres bloques breves, de 30–45 minutos cada uno:

- **Interfaz accesible:** auditar contraste, texto, mensajes y posibles interrupciones en una pantalla.
- **Backend:** recorrer la creación de una tarea, incluyendo permisos, validación y respuestas de error.
- **Calidad:** revisar un cambio usando criterios de aceptación, pruebas y lista de comprobación.

Para cada funcionalidad, quien la implementa realiza una auto-revisión y otra persona revisa los criterios y las pruebas. Julián apoya la revisión de accesibilidad y Yeray la de calidad; todo el equipo aplica las pautas y comparte la responsabilidad. Las decisiones dependientes del contexto del centro se validan con este antes de cerrarse.

## 8. Responsabilidades

- **Julián Carrión Tovar — Accesibilidad:** mantener las pautas, facilitar revisiones y ejercicios, y registrar problemas de accesibilidad.
- **Yeray Rodríguez Navas — Calidad:** mantener criterios de calidad, promover pruebas y revisiones, y realizar seguimiento de incidencias.
- **Resto del equipo:** aplicar las pautas, revisar cambios, aportar pruebas y elevar dudas.
- **Equipo completo:** acordar prioridades, validar decisiones relevantes y actualizar este manual.

## 9. Lista de comprobación

### Interfaz

- [ ] Contraste comprobado y estados comprensibles sin depender solo del color.
- [ ] Texto legible, directo y consistente; mayúsculas limitadas a rótulos breves.
- [ ] Sin ventanas emergentes automáticas o innecesarias; avisos en contexto.
- [ ] Errores claros y datos introducidos conservados cuando sea posible.
- [ ] Controles etiquetados, navegación por teclado y foco visible comprobados.

### Backend y calidad

- [ ] Datos validados en servidor y reglas de negocio aplicadas.
- [ ] Permisos comprobados en cada operación y datos limitados a lo necesario.
- [ ] Errores controlados y sin información técnica expuesta.
- [ ] Casos normales y de error probados; cambio revisado por otra persona.
- [ ] Incidencias, decisiones y limitaciones registradas.

## 10. Referencias y mejora continua

- W3C, [WCAG 2.2](https://www.w3.org/TR/WCAG22/).
- W3C WAI, [criterio de contraste mínimo](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).
- W3C WAI-ARIA APG, [patrón de diálogo modal](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/).

Registrar las sesiones de formación, ejercicios, dudas y decisiones. No incluir datos personales reales del alumnado en actas ni ejemplos. Este manual es una base inicial y debe revisarse con el avance del proyecto y la retroalimentación del centro.