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

## Fotos de perfil

Cada cuenta, cualquiera que sea su rol, tiene una foto vinculada desde `users.avatar_id_fk` a `Avatar`. Las cuentas nuevas reciben una silueta SVG predeterminada. El administrador puede cambiar la foto de cualquier cuenta con `PUT /users/{role}/{username}/avatar`; cada usuario puede cambiar la propia con `PUT /users/me/avatar`, y el alumnado necesita `stud_access_profile_mod`. Los archivos se envían como multipart `file` en PNG, JPEG o WebP, con un máximo de 5 MB. `GET /users/me/avatar` devuelve la foto propia y `avatar_url` apunta a `GET /users/{role}/{username}/avatar-image`.

### Quién puede consultar cada foto

El acceso depende de las relaciones guardadas en las tablas de matrícula, docencia y familia. Antes del inicio de sesión, la pantalla de identificación visual puede consultar únicamente las fotos del alumnado matriculado; las demás fotos requieren sesión:

| Quién consulta | Fotos que puede ver |
| --- | --- |
| Alumno | Alumnado que comparte alguna de sus clases, sus tutores asociados y el personal que enseña en sus clases |
| Tutor | Sus alumnos asociados y el personal que enseña en alguna clase de esos alumnos |
| Personal docente | Alumnado de las clases que imparte |
| Administrador | Cualquier cuenta |
| Cualquier rol | Su propia foto |
| Sin sesión | Fotos del alumnado matriculado, para elegir su perfil en el acceso visual |

Los tutores pueden ver la foto del profesor a cargo de su hijo para poder identificarlo. La consulta sin sesión no da acceso a fotos de personal, familias o administradores ni a fotos de alumnos que no estén matriculados en una clase.

El esquema se crea desde cero con `../../docs/diseno_arquitectura/modelado_datos/CreacionTablas.sqlscript`; no se requiere una migración incremental.
