# Estructura del Código Fuente (`src/`)

Esta carpeta contendrá la implementación de la aplicación del proyecto. Siguiendo las directrices del proyecto, la arquitectura se mantiene desacoplada y agnóstica a las tecnologías concretas hasta que el equipo consensúe el stack tecnológico definitivo en las primeras sesiones de prácticas.

---

## Organización de Directorios

- **`frontend/`**: Código de la interfaz de usuario de la aplicación (móvil y/o web accesible). Orientado a la experiencia del estudiante (PTVAL), tutores y administración, priorizando accesibilidad cognitiva, visual y motora.
- **`backend/`**: Código de la lógica del servidor, API, servicios de negocio, autenticación, control de perfiles y persistencia de datos.
- **`shared/`**: Modelos comunes, tipos, esquemas de validación de datos o contratos de interfaz (DTOs) compartidos entre cliente y servidor.

Para más detalles sobre la organización interna de cada módulo, consultar sus respectivos archivos README.
