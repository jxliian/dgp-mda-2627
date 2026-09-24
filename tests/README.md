# Estrategia y Estructura de Pruebas (`tests/`)

Este directorio aloja todas las baterías de pruebas automatizadas y manuales requeridas por la gestión de calidad y las buenas prácticas de ingeniería de software.

---

## Organización de Pruebas

- **`unit/`**: Pruebas unitarias para validar funciones individuales, modelos de datos y lógica de negocio aislada.
- **`integration/`**: Pruebas de integración entre módulos, comunicación cliente-servidor y operaciones con la base de datos.
- **`e2e/`**: Pruebas de extremo a extremo (End-to-End) que simulan los flujos de usuario reales (ej. inicio de sesión, marcado de tareas paso a paso, asignación de reprografía).
- **`accessibility/`**: Pruebas y auditorías específicas de usabilidad y accesibilidad:
  - Verificación de ratios de contraste cromático (WCAG 2.1 AA mínimo 4.5:1).
  - Pruebas de navegación asistida (TalkBack, VoiceOver, navegación solo por teclado/switch).
  - Scripts con motores de auditoría automatizada (axe-core, Lighthouse, pa11y).
  - Listas de control de lectura fácil y validación de pictogramas ARASAAC.
