import 'package:flutter/material.dart';
import '../theme.dart';

/// Tono de una insignia. Describe su significado, no su color.
enum BadgeTone { neutral, main, warm, attention, done }

/// Insignia redondeada para estados y roles: «Aula», «Hoy», «Mi tarea».
///
/// El texto se reparte en varias líneas antes que recortarse, para que nunca
/// se pierda información al ampliar la letra del sistema.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.neutral, this.icon});

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  (Color, Color, Color) get _colores => switch (tone) {
    BadgeTone.main => (Paleta.bosqueSuave, Paleta.bosqueTinta, Paleta.bosque),
    BadgeTone.done => (Paleta.bosqueSuave, Paleta.bosqueTinta, Paleta.bosque),
    BadgeTone.warm => (
      Paleta.terracotaSuave,
      Paleta.terracotaTinta,
      Paleta.terracota,
    ),
    BadgeTone.attention => (Paleta.ambarSuave, Paleta.ambarTinta, Paleta.ambar),
    BadgeTone.neutral => (Paleta.papel, Paleta.tintaSuave, Paleta.trazo),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final oscuro = scheme.brightness == Brightness.dark;
    final (fondo, texto, filo) = _colores;
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 12 : 10, 7, 12, 7),
      decoration: BoxDecoration(
        color: oscuro ? scheme.surfaceContainer : fondo,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: oscuro ? scheme.outline : filo,
          width: Medidas.trazo,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: oscuro ? scheme.onSurface : texto),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: .4,
                height: 1.25,
                color: oscuro ? scheme.onSurface : texto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
