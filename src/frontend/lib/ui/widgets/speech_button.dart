import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Botón para escuchar un texto en voz alta.
///
/// Lleva nombre accesible propio y avisa si el dispositivo no tiene voz
/// instalada, en lugar de quedarse en silencio sin explicación.
class SpeechButton extends StatefulWidget {
  const SpeechButton({super.key, required this.text});

  final String text;

  @override
  State<SpeechButton> createState() => _SpeechButtonState();
}

class _SpeechButtonState extends State<SpeechButton> {
  final FlutterTts tts = FlutterTts();
  String? error;

  Future<void> leer() async {
    try {
      await tts.setLanguage('es-ES');
      await tts.setSpeechRate(.42);
      final resultado = await tts.speak(widget.text);
      if (resultado == 0) throw StateError('Sin voz disponible');
      if (mounted) setState(() => error = null);
    } on Object {
      if (mounted) setState(() => error = _sinVoz);
    }
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      OutlinedButton.icon(
        onPressed: leer,
        icon: const Icon(Icons.volume_up_outlined),
        label: const Text('Escuchar'),
      ),
      if (error != null)
        SizedBox(
          width: 200,
          child: Text(error!, style: const TextStyle(fontSize: 13)),
        ),
    ],
  );

  static const _sinVoz =
      'La lectura en voz no está disponible en este dispositivo.';
}
