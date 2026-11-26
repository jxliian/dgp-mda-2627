import 'package:flutter/material.dart';

/// Acciones al pie del contenido de una pantalla, siempre en el mismo sitio.
///
/// Esta es la regla de colocación del proyecto, y esta clase es el único sitio
/// donde se escribe:
///
///  1. **La acción principal cierra la pantalla por la derecha.** Es la única
///     rellena y siempre la última que se lee.
///  2. **Las acciones secundarias van a su izquierda**, en el orden en que se
///     pasan, con contorno.
///  3. **La acción destructiva va sola, en una fila aparte y debajo**, separada
///     del resto. Nunca al lado de la principal: son dos decisiones distintas y
///     una de ellas no se puede deshacer.
///  4. Nada va después. Si una pantalla necesita algo más, va antes de aquí.
///
/// Las acciones de navegación ---abrir otra pantalla--- no son acciones de
/// cierre: van arriba, junto al contenido con el que tienen que ver, no aquí.
class ScreenActions extends StatelessWidget {
  const ScreenActions({
    super.key,
    this.primary,
    this.secondary = const [],
    this.destructive,
    this.topPadding = 30,
  });

  /// Acción principal de la pantalla. Rellena y a la derecha del todo.
  final Widget? primary;

  /// Acciones secundarias, de izquierda a derecha, antes de la principal.
  final List<Widget> secondary;

  /// Acción que destruye algo. Fila propia, debajo y separada.
  final Widget? destructive;

  final double topPadding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: topPadding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (primary != null || secondary.isNotEmpty)
          Wrap(
            spacing: 20,
            runSpacing: 14,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [...secondary, ?primary],
          ),
        if (destructive != null) ...[
          const SizedBox(height: 26),
          Align(alignment: Alignment.centerLeft, child: destructive),
        ],
      ],
    ),
  );
}
