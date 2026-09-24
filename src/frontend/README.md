# Frontend / Aplicación de Usuario (`src/frontend/`)

Este módulo contendrá la interfaz de usuario de la aplicación. Debe estar diseñado bajo estrictos criterios de **accesibilidad universal**, con especial foco en:
- Estudiantes con discapacidad intelectual (programa PTVAL - Colegio Purísima Concepción).
- Estudiantes con dificultades motrices y visuales.
- Tutores (docentes y familiares).
- Administradores del centro.

---

## Estructura Prevista (Agnóstica a Framework)

Una vez seleccionado el stack tecnológico (por ejemplo: Flutter, React Native, Web PWA, etc.), se recomienda seguir la siguiente arquitectura modular:

```text
frontend/
├── assets/             # Recursos estáticos: iconos, audios descriptivos y pictogramas ARASAAC
├── components/         # Componentes UI reutilizables y accesibles (botones adaptados, temporizador visual, tarjetas)
├── screens/ / views/   # Vistas principales de la aplicación:
│   ├── auth/           # Login adaptado (accesible por pictogramas/PIN/patrón según perfil)
│   ├── agenda/         # Agenda diaria y semanal del estudiante
│   ├── tasks/          # Ejecución paso a paso de tareas (con reloj temporal accesible)
│   ├── reprografia/    # Flujo de tarea de reprografía del centro
│   ├── comedor/        # Flujo de registro de comensales y dietas del comedor
│   ├── tutor_panel/    # Panel de gestión, configuración de perfiles y seguimiento del tutor
│   └── chat/           # Chat accesible entre tutor y estudiante
├── services/           # Clientes HTTP, consumo de la API backend y almacenamiento local
├── state/              # Manejo del estado global de la aplicación
├── theme/ / styles/    # Paletas de alto contraste, tipografías legibles y soporte multitema
└── utils/              # Funciones auxiliares de accesibilidad (Text-to-Speech, lectores de pantalla, etc.)
```

> **Nota:** La elección de la tecnología se decidirá en consenso por el equipo tras la entrevista inicial con el cliente y las primeras sesiones de prácticas.
