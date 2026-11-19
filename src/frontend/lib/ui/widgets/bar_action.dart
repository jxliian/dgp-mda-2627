import 'package:flutter/material.dart';
import '../theme.dart';

/// Botón de la barra superior.
///
/// Todos los de la barra son este mismo widget ---volver, las acciones de la
/// pantalla, inicio, ajustes y salir---, así que tienen idéntico contorno,
/// altura y tipografía. Mezclar botones de contorno con botones de texto hacía
/// que unos parecieran más importantes que otros sin que lo fueran.
///
/// Es más bajo que un botón de contenido porque una barra con botones de 84 dp
/// se come la pantalla; sigue muy por encima del objetivo táctil mínimo.
class BarAction extends StatelessWidget {
  const BarAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, Medidas.alturaBotonMenor),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  );
}
