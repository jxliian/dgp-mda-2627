import 'package:flutter/material.dart';
import '../theme.dart';

/// Acción secundaria compacta, para cuando un botón con texto no cabe.
///
/// El texto descriptivo es obligatorio: es el nombre que anuncian los lectores
/// de pantalla y el que aparece al mantener el puntero encima. Conserva el
/// objetivo táctil mínimo de 56 dp.
class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: label,
    onPressed: onPressed,
    icon: Icon(icon),
    style: IconButton.styleFrom(
      minimumSize: const Size(
        Medidas.alturaBotonMenor,
        Medidas.alturaBotonMenor,
      ),
      side: const BorderSide(
        color: Paleta.trazoControl,
        width: Medidas.trazoGrueso,
      ),
    ),
  );
}
