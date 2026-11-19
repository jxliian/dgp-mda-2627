import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

/// Refuerzo positivo al terminar una tarea: confeti, un icono grande y una
/// frase corta.
///
/// La celebración no se cierra sola: el alumno decide cuándo continuar, y el
/// botón dice a dónde va a ir. Si el sistema tiene las animaciones reducidas,
/// el confeti se dibuja quieto en lugar de caer.
Future<void> showCelebration(
  BuildContext context, {
  required String message,
  required String continueLabel,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) =>
      _Celebracion(message: message, continueLabel: continueLabel),
);

class _Celebracion extends StatefulWidget {
  const _Celebracion({required this.message, required this.continueLabel});

  final String message;
  final String continueLabel;

  @override
  State<_Celebracion> createState() => _CelebracionState();
}

class _CelebracionState extends State<_Celebracion>
    with SingleTickerProviderStateMixin {
  late final AnimationController control = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  final List<_Papelito> papelitos = _Papelito.generar(44);

  @override
  void initState() {
    super.initState();
    control.forward();
  }

  @override
  void dispose() {
    control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sinMovimiento = MediaQuery.of(context).disableAnimations;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: control,
                builder: (context, _) => CustomPaint(
                  painter: _ConfetiPainter(
                    papelitos,
                    avance: sinMovimiento ? .35 : control.value,
                  ),
                ),
              ),
            ),
          ),
          _tarjeta(context),
        ],
      ),
    );
  }

  Widget _tarjeta(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 560),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 96,
              color: Paleta.ambar,
            ),
            const SizedBox(height: 18),
            Semantics(
              liveRegion: true,
              child: Text(
                '¡Muy bien!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, height: 1.5),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_forward),
              label: Text(widget.continueLabel),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Un papelito de confeti con su trayectoria ya sorteada.
class _Papelito {
  const _Papelito({
    required this.x,
    required this.retraso,
    required this.giro,
    required this.ancho,
    required this.color,
    required this.deriva,
  });

  final double x;
  final double retraso;
  final double giro;
  final double ancho;
  final Color color;
  final double deriva;

  static const _colores = [
    Paleta.bosque,
    Paleta.terracota,
    Paleta.ambar,
    Paleta.bosqueTinta,
  ];

  static List<_Papelito> generar(int cuantos) {
    // Semilla fija: la celebración se ve igual en cada tarea terminada, que
    // es lo que la vuelve reconocible.
    final azar = Random(7);
    return [
      for (var i = 0; i < cuantos; i++)
        _Papelito(
          x: azar.nextDouble(),
          retraso: azar.nextDouble() * .45,
          giro: azar.nextDouble() * pi,
          ancho: 10 + azar.nextDouble() * 12,
          color: _colores[i % _colores.length],
          deriva: (azar.nextDouble() - .5) * .22,
        ),
    ];
  }
}

class _ConfetiPainter extends CustomPainter {
  const _ConfetiPainter(this.papelitos, {required this.avance});

  final List<_Papelito> papelitos;
  final double avance;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()..style = PaintingStyle.fill;
    for (final papelito in papelitos) {
      final recorrido = ((avance - papelito.retraso) / (1 - papelito.retraso))
          .clamp(0.0, 1.0);
      if (recorrido <= 0) continue;
      final y = recorrido * (size.height + 60) - 30;
      final x = (papelito.x + papelito.deriva * recorrido) * size.width;
      pincel.color = papelito.color.withValues(alpha: 1 - recorrido * .35);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(papelito.giro + recorrido * 5)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: papelito.ancho,
              height: papelito.ancho * .55,
            ),
            const Radius.circular(2),
          ),
          pincel,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfetiPainter oldDelegate) =>
      oldDelegate.avance != avance;
}
