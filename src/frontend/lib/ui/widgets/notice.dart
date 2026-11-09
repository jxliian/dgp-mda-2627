import 'package:flutter/material.dart';
import '../theme.dart';

/// Mensaje de información o de error.
///
/// Es una región activa: cuando aparece, el lector de pantalla lo anuncia sin
/// que el usuario tenga que buscarlo.
class Notice extends StatelessWidget {
  const Notice(this.message, {super.key, this.error = false, this.action});

  final String message;
  final bool error;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final fondo = error ? Paleta.alertaSuave : Paleta.bosqueSuave;
    final tinta = error ? Paleta.alertaTinta : Paleta.bosqueTinta;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(Medidas.radioControl),
        border: Border.all(color: tinta, width: Medidas.trazo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Solo el texto es región activa: la acción sigue siendo un botón
          // normal para el lector de pantalla.
          Semantics(
            liveRegion: true,
            label: error ? 'Error. $message' : message,
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  error ? Icons.error_outline : Icons.info_outline,
                  color: tinta,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: tinta, fontSize: 16, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 14), child: action),
        ],
      ),
    );
  }
}
