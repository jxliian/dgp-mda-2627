# Backend / Servidor de Aplicación (`src/backend/`)

Este módulo contendrá la lógica de negocio, la API del sistema y la capa de persistencia de datos.

---

## Estructura Prevista (Agnóstica a Framework)

Independientemente del lenguaje o framework que el equipo elija (Node.js/Express/NestJS, Python/FastAPI/Django, Java/Spring Boot, etc.), se recomienda seguir una arquitectura limpia y modular en capas:

```text
backend/
├── config/             # Configuración del entorno, base de datos y constantes del sistema
├── controllers/        # Controladores de la API (gestión de peticiones y respuestas HTTP)
├── middleware/         # Middleware de autenticación, control de accesos, validación y logs
├── models/ / entities/ # Entidades y esquemas de datos:
│   ├── Usuario.ext     # Estudiantes, Tutores y Administradores
│   ├── PerfilAccesible # Preferencias visuales, sonoras y cognitivas de cada estudiante
│   ├── Tarea.ext       # Tareas del centro y tareas personales (pasos, horarios, estado)
│   ├── Comedor.ext     # Registros de asistencias al comedor y dietas
│   └── Reprografia.ext # Solicitudes de reprografía y estado de tramitación
├── repositories/       # Abstracción del acceso y operaciones sobre la base de datos
├── services/           # Lógica de negocio y casos de uso del dominio
└── utils/              # Funciones auxiliares generales
```

> **Nota:** La tecnología definitiva será definida y documentada en la Propuesta Técnica y en la Planificación de la Iteración 1.
