# Código y Recursos Compartidos (`src/shared/`)

Este directorio está destinado a almacenar definiciones, tipos o contratos que puedan ser compartidos o sincronizados entre el cliente (`frontend/`) y el servidor (`backend/`).

---

## Contenido Previsto

- **Tipos e Interfaces (DTOs):** Definición de contratos de datos para peticiones y respuestas.
- **Constantes del Negocio:** Enumeraciones de roles (`ADMIN`, `TUTOR`, `ESTUDIANTE`), estados de tareas (`PENDIENTE`, `EN_PROCESO`, `COMPLETADA`), tipos de dietas, etc.
- **Especificación de API:** Documentos OpenAPI / Swagger (`openapi.yaml` o `openapi.json`) para definir el contrato de la API de forma agnóstica.
