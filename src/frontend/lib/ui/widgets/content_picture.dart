import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Apoyo visual de una tarea: su imagen o, si no tiene, un icono.
///
/// Es decorativo: el título de la tarea ya dice lo mismo, así que se oculta a
/// los lectores de pantalla para no repetir información.
class ContentPicture extends StatelessWidget {
  const ContentPicture({
    super.key,
    required this.icon,
    this.bytes,
    this.size = 90,
  });

  final IconData icon;
  final Uint8List? bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Medidas.radioControl),
          border: Border.all(color: scheme.outlineVariant, width: Medidas.trazo),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            Medidas.radioControl - Medidas.trazo,
          ),
          child: SizedBox(
            width: size,
            height: size,
            child: bytes != null
                ? Image.memory(bytes!, fit: BoxFit.cover)
                : ColoredBox(
                    color: scheme.primaryContainer,
                    child: Icon(
                      icon,
                      size: size * .52,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Icono que acompaña a una tarea, deducido de su título.
IconData taskIcon(String title) {
  final texto = title.toLowerCase();
  const porPalabra = {
    'mochila': Icons.backpack_outlined,
    'planta': Icons.local_florist_outlined,
    'regar': Icons.local_florist_outlined,
    'leer': Icons.menu_book_outlined,
    'cuento': Icons.menu_book_outlined,
    'comer': Icons.restaurant_outlined,
    'comedor': Icons.restaurant_outlined,
    'copia': Icons.print_outlined,
  };
  for (final entrada in porPalabra.entries) {
    if (texto.contains(entrada.key)) return entrada.value;
  }
  return Icons.checklist_outlined;
}
