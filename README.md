# Sistema de Agenda y Gestión de Tareas Accesible (AUTOVIDA)

[![UGR](https://img.shields.io/badge/UGR-Universidad%20de%20Granada-blue.svg)](https://www.ugr.es/)
[![Curso](https://img.shields.io/badge/Curso-2026%2F2027-brightgreen.svg)]()
[![Asignaturas](https://img.shields.io/badge/Asignaturas-DGP%20%7C%20MDA-orange.svg)]()
[![Accesibilidad](https://img.shields.io/badge/Accesibilidad-WCAG%202.1%20AA-purple.svg)]()

Proyecto informático de Aprendizaje-Servicio desarrollado de manera colaborativa para las asignaturas de **Dirección y Gestión de Proyectos (DGP)** y **Metodologías de Desarrollo Ágil (MDA)** del Grado en Ingeniería Informática de la **Universidad de Granada (UGR)**.

El proyecto se realiza en colaboración con el **Colegio de Educación Especial Fundación Purísima Concepción de Granada** (Fundación Hospitalarias), dentro del proyecto de innovación docente:  
*“26-175. Aprendizaje-servicio y Software Accesible para la Autonomía y la Transición a la Vida Adulta en Estudiantes NEAE (AUTOVIDA)”*.

---

## 📌 1. Visión y Objetivos del Proyecto

El objetivo es desarrollar una solución de software accesible que proporcione una **agenda visual personalizada y estructuración del tiempo** para estudiantes con necesidades educativas especiales (NEAE), facilitando su autonomía y su preparación dentro del **Programa de Transición a la Vida Adulta (PTVAL)**.

### Módulos y Tareas Clave:
- **Tareas del Centro Escolar:**
  - **Reprografía:** Flujo asistido por pasos (recogida de material en aula, reprografía/taller y entrega al aula destinataria).
  - **Comedor:** Recorrido por aulas para registro de comensales y tipos de menús/dietas (sin gluten, triturada, hiposódica, etc.).
  - **Menú Mensual:** Entrega física del menú por aula con control de entregas.
  - **Guías de Visita:** Apoyo para estudiantes embajadores del centro en visitas externas.
- **Tareas Personales Adaptadas:**
  - Planificación con apoyo de imágenes, vídeos, audios y pictogramas **ARASAAC**.
  - Temporizador visual y accesible para mostrar el paso del tiempo de forma intuitiva.
  - Secuencias de pasos con confirmación visual de avance.
- **Perfiles y Personalización Universal:**
  - Ajustes por estudiante: tamaño y tipografía, contraste alto, posición de botones.
  - Acceso accesible (autenticación simplificada o visual).
  - Roles: **Estudiante**, **Tutor** (escolar y familiar) y **Administrador**.
  - Chat accesible de apoyo y refuerzo entre tutor y estudiante.

---

## 📂 2. Estructura del Repositorio

El repositorio mantiene una estructuración clara y modular, sin atarse aún a tecnologías específicas:

```text
dgp-mda-2627/
├── docs/                          # Documentación formal y entregables del proyecto
│   ├── README.md                  # Índice general de documentación y fechas clave
│   ├── referencias/               # Guiones oficiales, pliego técnico y requisitos de partida
│   ├── dgp/                       # Entregables de Dirección y Gestión de Proyectos
│   │   ├── manual_coordinacion/   # Manual de Coordinación y Plan de Dirección
│   │   ├── propuesta_tecnica/     # Propuesta técnica de la solución
│   │   ├── planificacion_cronograma/ # Planificación temporal y seguimiento
│   │   ├── gestion_riesgos/       # Matriz y mitigación de riesgos
│   │   ├── gestion_costes/        # Presupuesto y costes
│   │   └── seguimiento_horas/     # Registro consolidado de horas del equipo
│   ├── mda/                       # Entregables de Metodologías de Desarrollo Ágil
│   │   ├── personajes_escenarios/ # Personajes y escenarios de uso (P0 y P1)
│   │   ├── product_backlog/       # Product Backlog y plan de entregas (P2)
│   │   ├── iteraciones/           # Entregables de Iteración 1, 2 y 3
│   │   └── retrospectivas/        # Informes de revisión y retrospectiva
│   ├── reuniones/                 # Registro y custodia de actas de reunión
│   │   ├── actas_equipo/          # Reuniones internas del grupo
│   │   ├── actas_cliente/         # Reuniones con el Colegio Purísima Concepción
│   │   └── actas_tutor/           # Seguimiento semanal con el docente
│   ├── diseno_arquitectura/       # Arquitectura del sistema, modelos de datos y wireframes
│   ├── calidad_accesibilidad/     # Auditorías WCAG 2.1 AA, heurísticas y reportes de calidad
│   └── plantillas/                # Plantillas de gestión de trabajo (actas, registro de horas)
│
├── src/                           # Código fuente (modular y agnóstico a framework inicial)
│   ├── frontend/                  # Interfaz de usuario adaptada (móvil/web accesible)
│   ├── backend/                   # API, lógica de negocio y persistencia
│   └── shared/                    # Modelos, DTOs y tipos compartidos
│
├── tests/                         # Baterías de pruebas
│   ├── unit/                      # Pruebas unitarias
│   ├── integration/               # Pruebas de integración
│   ├── e2e/                       # Pruebas de extremo a extremo
│   └── accessibility/             # Pruebas de accesibilidad (contraste, lectores, validadores)
│
├── scripts/                       # Utilidades, semillas de datos (mockups ARASAAC)
├── .gitignore                     # Exclusiones de Git exhaustivas y multiplataforma
└── README.md                      # Presentación general y directrices del repositorio
```

---

## 👥 3. Organización y Roles del Equipo

El equipo cuenta con **6 integrantes**:

- **Coordinadores (Rotatorio):** Dos miembros lideran cada iteración, gestionando la planificación y sincronización del equipo.
- **Gestor de Calidad (Fijo):** Vela por la calidad del proceso, la completitud de los entregables y la estabilidad del código.
- **Auditor de Usabilidad y Accesibilidad (Fijo):** Asegura el cumplimiento de normativas de accesibilidad (WCAG 2.1 AA), lectores de pantalla (TalkBack/VoiceOver) y adaptación con ARASAAC.
- **Catalogador:** Custodia la documentación, versiones y nomenclatura en `docs/`.
- **Moderador:** Dinamiza las reuniones, controla tiempos y redacta las actas.
- **Presentador:** Prepara y coordina las exposiciones públicas y defensas orales.

> Más información en el [Manual de Coordinación](file:///home/jxlig0d/Escritorio/DGP-MDA-REPO/dgp-mda-2627/docs/dgp/manual_coordinacion/MANUAL_DE_COORDINACION.md).

---

## 🌿 4. Flujo de Trabajo en Git (Rama Única `main`)

Para simplificar la operativa y evitar la sobrecarga de ramas o Pull Requests, **todos los integrantes trabajarán directamente sobre la rama `main` con cuidado y coordinación activa**.

### Normas de Trabajo Seguro:
1. **`git pull` obligatorio:**
   - Siempre ejecuta `git pull` antes de comenzar a trabajar.
   - Vuelve a ejecutar `git pull` justo antes de hacer `git push` para incorporar cambios recientes de los compañeros.
2. **Reparto claro y comunicación:**
   - Cada miembro trabaja en sus módulos, componentes o documentos asignados.
   - Si vas a tocar un archivo común o de configuración, avisa previamente por el grupo para no pisar el trabajo de nadie.
3. **Validación previa en local:**
   - **Nunca se sube código roto a `main`.** Verifica que el proyecto compila y funciona en tu máquina antes de hacer push.
4. **Commits atómicos y descriptivos (Conventional Commits):**
   - Formato: `<tipo>: <descripción concisa>`
   - Tipos principales:
     - `feat`: Nueva funcionalidad
     - `fix`: Corrección de fallos
     - `docs`: Modificación o adición de documentación / actas
     - `style`: Formateo de código sin cambio funcional
     - `refactor`: Refactorización interna
     - `test`: Pruebas unitarias o de integración
     - `chore`: Tareas de configuración o dependencias
     - `a11y`: Mejoras de accesibilidad
   - *Ejemplo:* `feat: agregar temporizador visual accesible`

---

## 🗓️ 5. Fechas Clave (Curso 2026-2027)

| Fecha / Hito | Evento / Entregable |
| :--- | :--- |
| **25 de septiembre de 2026 (08:30h)** | Entrevista inicial con el cliente (Colegio Purísima Concepción) en clase de MDA. |
| **01-02 de octubre de 2026** | Inicio de sesiones de prácticas y definición de tecnologías. |
| **02 de octubre de 2026** | Visita presencial al centro (representantes de equipos). |
| **21-22 de octubre de 2026 (23:59h)** | **Entrega de primeros documentos:** Manual de coordinación, Propuesta técnica, Backlog inicial, Horas y Actas. |
| **11-12 de noviembre de 2026 (23:59h)** | **Entrega Iteración 1:** Primer prototipo funcional + Presentación. |
| **02-03 de diciembre de 2026 (23:59h)** | **Entrega Iteración 2:** Incremento de software (tareas centro/comedor) + Presentación. |
| **21 de diciembre de 2026 (23:59h)** | **Entrega Iteración 3:** Software completo, informes finales de calidad y accesibilidad. |
| **12 de enero de 2027 (tarde)** | **Presentación oral y defensa final del proyecto** (equipo completo). |

---

## 📋 6. Plantillas de Gestión Operativa

- [Plantilla de Actas de Reunión](file:///home/jxlig0d/Escritorio/DGP-MDA-REPO/dgp-mda-2627/docs/plantillas/plantilla_acta_reunion.md)
- [Plantilla de Registro de Horas Individuales](file:///home/jxlig0d/Escritorio/DGP-MDA-REPO/dgp-mda-2627/docs/plantillas/plantilla_registro_horas.md)
- [Índice de Documentación](file:///home/jxlig0d/Escritorio/DGP-MDA-REPO/dgp-mda-2627/docs/README.md)
