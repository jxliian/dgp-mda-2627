import 'package:flutter/material.dart';
import '../theme.dart';

/// Tono de una insignia. Describe su significado, no su color.
enum BadgeTone { neutral, main, warm, attention, done }

/// Etiqueta de texto con icono para estados y roles: «Aula», «Hoy», «Mi tarea».
///
/// Sin bordes ni relleno de fondo para que no parezca un botón pulsable.
/// El texto se reparte en varias líneas antes que recortarse, para que nunca
/// se pierda información al ampliar la letra del sistema.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.neutral, this.icon});

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  Color get _color => switch (tone) {
    BadgeTone.main => Paleta.bosqueTinta,
    BadgeTone.done => Paleta.bosqueTinta,
    BadgeTone.warm => Paleta.terracotaTinta,
    BadgeTone.attention => Paleta.ambarTinta,
    BadgeTone.neutral => Paleta.tintaSuave,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final oscuro = scheme.brightness == Brightness.dark;
    final color = oscuro ? scheme.onSurface : _color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
              height: 1.25,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
