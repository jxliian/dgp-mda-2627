# Auditoría de accesibilidad — Iteración 1

Aplicación Flutter `src/frontend`, rama `iteracion1`. Referencia: **WCAG 2.2
nivel AA**, con el compromiso adicional del proyecto de superar **7:1** en los
textos principales (nivel AAA de contraste).

Parte de la auditoría está automatizada en `test/accessibility_test.dart` y se
ejecuta con `flutter test`: recorre el árbol de semántica de seis pantallas
reales y falla si aparece algo pulsable sin nombre accesible, un objetivo
táctil menor de 48 px o un par de colores por debajo del umbral.

## 1. Contraste de color (1.4.3, 1.4.6, 1.4.11)

Medidas reales de la paleta (`lib/ui/theme.dart`):

| Par de colores | Relación | Umbral | Resultado |
|---|---:|---|---|
| Texto principal sobre lino `#1F2A24` / `#FBF9F5` | 14,11:1 | 7:1 | Cumple |
| Texto secundario sobre lino `#3F4C44` / `#FBF9F5` | 8,58:1 | 7:1 | Cumple |
| Verde bosque sobre lino `#1B4332` / `#FBF9F5` | 10,54:1 | 7:1 | Cumple |
| Texto principal sobre tarjeta `#1F2A24` / `#F3EFE6` | 12,93:1 | 7:1 | Cumple |
| Texto secundario sobre tarjeta `#3F4C44` / `#F3EFE6` | 7,86:1 | 7:1 | Cumple |
| Texto del botón principal `#FFFFFF` / `#1B4332` | 11,08:1 | 4,5:1 | Cumple |
| Aviso de error `#8C2F1C` / `#FDECE8` | 7,22:1 | 4,5:1 | Cumple |
| Aviso informativo `#14402C` / `#E4EDE7` | 9,76:1 | 4,5:1 | Cumple |
| Insignia terracota `#8A3A22` / `#FBECE5` | 6,73:1 | 4,5:1 | Cumple |
| Insignia ámbar `#7A4B06` / `#FDF1DC` | 6,62:1 | 4,5:1 | Cumple |
| Borde de los controles `#8D8779` / blanco | 3,57:1 | 3:1 | Cumple |
| Borde de los controles `#8D8779` / tarjeta | 3,12:1 | 3:1 | Cumple |

**Dos defectos corregidos en esta auditoría:**

1. Los bordes de botones, campos y chips usaban el trazo decorativo `#D9D2C4`,
   que sobre blanco daba 1,4:1 y no permitía distinguir el contorno de un
   control (1.4.11). Se separó el trazo en dos: `Paleta.trazo` para
   separadores y tarjetas, y `Paleta.trazoControl` (`#8D8779`, 3,57:1) para
   todo lo pulsable.
2. La banda de aviso tenía un filo ámbar claro de 2,85:1 sobre su propio
   fondo. Se sustituyó por ámbar oscuro de 2 px (6,62:1).

El modo de alto contraste del alumno sigue disponible y fuerza negro sobre
blanco, por encima de cualquier personalización de color.

## 2. Objetivos táctiles (2.5.8)

Las medidas se subieron el 10/11/2026 para que lo pulsable ocupe buena parte
de la pantalla: el alumnado trabaja en tablet y conviene que cada destino sea
grande y fácil de acertar.

WCAG 2.2 AA exige 24×24 px; Material recomienda 48×48; el proyecto trabaja con
tablet y fija un mínimo propio más alto.

| Elemento | Altura |
|---|---|
| Botón principal | 76 px |
| Botón de texto, acciones con icono, chips | 64 px |
| Fichas de lista (`ActionTile`) | 112 px mínimo |
| Icono de una ficha | 52 px en fila, 96 px en rejilla |
| Foto en la elección de alumno | 200 px |

La prueba automática recorre las seis pantallas y comprueba que ningún nodo
pulsable baja de 48 px en su lado menor. Pasa sin excepciones.

## 2 bis. Sin desplazamiento en tablet (decisión de producto)

Las pantallas de alumno y de personal caben enteras en una tablet de 1280×900
sin tener que desplazarlas. Está comprobado en `test/sin_scroll_test.dart`,
que mide el desplazamiento sobrante de nueve pantallas y falla si alguna lo
necesita. El desplazamiento sigue disponible como red de seguridad para letra
ampliada y pantallas pequeñas, donde no es posible evitarlo.

## 2 ter. Apoyos desactivados de origen

Los apoyos visuales (pictogramas, alto contraste, filtros y botones para
escuchar) **nacen apagados**. La pantalla de ajustes está implementada y es
funcional, pero cada apoyo se enciende de forma individual con la familia y el
tutor, según lo que cada alumno necesite. Los permisos del perfil (modificar
su perfil, crear y eliminar sus tareas) no son apoyos y conservan su valor.

## 3. Nombre accesible de los controles (1.1.1, 4.1.2)

La prueba exige que todo nodo con acción de pulsación tenga etiqueta, texto
alternativo o descripción emergente. Correcciones aplicadas:

- Las flechas de paginación y las acciones de eliminar o retirar son ahora
  `IconAction`, un componente que **obliga** a pasar un texto descriptivo
  («Eliminar a Pablo García», «Página siguiente»). No es posible crear un
  botón de icono sin nombre.
- Los botones de perfil del inicio de sesión muestran un nombre corto
  («Personal») y anuncian el completo («Personal del centro»).
- Las teclas del PIN de dibujos anuncian «Corazón, número 1».
- El sello del centro se lee como una sola unidad: «Autovida, agenda del
  Centro CeRA».
- Las imágenes decorativas (pictograma de tarea, icono de ficha) se excluyen
  de la semántica para no repetir el título que ya está al lado. Las fotos de
  personas sí se anuncian: «Foto de Ana García».
- El botón de escuchar lleva texto visible, no solo el icono de altavoz.

## 4. Texto ampliado y reflujo (1.4.4, 1.4.10)

- La interfaz se prueba al **140 %** (inicio de cada rol en pantalla de móvil)
  y al **200 %** (las seis pantallas de la auditoría). No se producen
  desbordamientos ni pérdida de contenido.
- El alumno puede además agrandar la letra desde sus ajustes; el factor se
  multiplica por el del sistema operativo, con tope de 2,5×.
- Defecto corregido: el rótulo del centro desbordaba su fila al 200 %. Ahora
  cede ancho y reparte el texto en varias líneas.
- Las insignias reparten su texto en varias líneas antes que recortarlo.

## 5. Foco visible y manejo por teclado (2.4.7, 2.1.1)

- Anillo de foco propio de 3 px en terracota sobre cualquier botón, campo o
  acción, definido en el tema y no heredado del comportamiento por defecto.
- El orden de tabulación sigue el orden de lectura porque la composición es
  una sola columna de contenido.
- El inicio de sesión admite envío con Intro desde el campo de contraseña y
  declara `autofillHints` de usuario y contraseña.

## 6. Comprensión y estructura (1.3.1, 2.4.6, 3.3.1)

- El título de cada pantalla y cada encabezado de sección se marcan como
  cabecera para poder saltar entre secciones con un lector de pantalla.
- Los avisos de error y confirmación son regiones activas: se anuncian solos
  al aparecer, y los de error se leen precedidos de la palabra «Error».
- Todos los campos obligatorios llevan etiqueta visible con asterisco y texto
  de ayuda; los errores se describen en palabras, no solo en rojo.
- Idioma declarado `es-ES` en toda la aplicación.
- Frases cortas y caja mixta; no hay bloques en mayúsculas.

## 7. Limitaciones conocidas

- Con la letra al 200 %, los nombres de perfil del inicio de sesión se recortan
  en pantalla porque los cuatro deben permanecer en una sola fila. El icono y
  el nombre completo anunciado mantienen la información.
- La lectura en voz depende de que el dispositivo tenga voz en español
  instalada; si no la hay, se avisa en pantalla en lugar de fallar en silencio.
- No se ha probado todavía con lectores de pantalla reales (TalkBack,
  NVDA). La auditoría cubre el árbol de semántica, que es lo que esos
  programas consumen, pero conviene una prueba manual antes de la entrega
  final.
