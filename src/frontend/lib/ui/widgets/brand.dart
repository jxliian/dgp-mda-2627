import 'package:flutter/material.dart';
import '../theme.dart';

/// Sello del centro: un distintivo sencillo con el nombre del programa y del
/// centro. Se lee como una sola unidad con los lectores de pantalla.
class Brand extends StatelessWidget {
  const Brand({super.key, this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Autovida, agenda del Centro CeRA',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(large ? 16 : 11),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(large ? 20 : 14),
              border: Border.all(
                color: scheme.onPrimaryContainer,
                width: Medidas.trazoGrueso,
              ),
            ),
            child: Icon(
              Icons.eco_outlined,
              size: large ? 40 : 26,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          // El rótulo cede ancho cuando la letra del sistema está muy ampliada.
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Autovida',
                  style: TextStyle(
                    fontSize: large ? 30 : 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: large ? 1 : .6,
                    height: 1.1,
                  ),
                ),
                Text(
                  'Centro CeRA',
                  style: TextStyle(
                    fontSize: large ? 15 : 13,
                    letterSpacing: large ? 2.4 : 1.8,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
