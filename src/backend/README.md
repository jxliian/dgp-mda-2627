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

## Foto de perfil del alumno

Con una sesión Bearer de alumno, `PUT /users/students/me/avatar` recibe un archivo
multipart en el campo `file`. Admite imágenes PNG, JPEG y WebP de hasta 5 MB. La
respuesta incluye `avatar_url`; `GET /users/students/me/avatar` devuelve la imagen
actual o una silueta SVG predeterminada si todavía no hay foto. La subida requiere
que `stud_access_profile_mod` permita editar el perfil.
