import 'package:flutter/material.dart';
import '../theme.dart';

/// Encabezado de sección con una regla corta de acento debajo.
///
/// Se anuncia como cabecera para que un lector de pantalla pueda saltar de
/// sección en sección.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.hint, this.centered = false});

  final String text;
  final String? hint;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final alineacion = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 16),
      child: Column(
        crossAxisAlignment: alineacion,
        children: [
          Semantics(
            header: true,
            child: Text(
              text,
              textAlign: centered ? TextAlign.center : TextAlign.start,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: Paleta.terracota,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                hint!,
                textAlign: centered ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
