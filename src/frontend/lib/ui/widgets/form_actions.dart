import 'package:flutter/material.dart';
import 'screen_actions.dart';

/// Cierre de un formulario: cancelar, guardar y, si la hay, la acción que
/// destruye lo que se está editando.
///
/// Es el caso particular de [ScreenActions] para formularios, y sigue su misma
/// regla: guardar a la derecha del todo, cancelar a su izquierda y la acción
/// destructiva sola en una fila debajo.
class FormActions extends StatelessWidget {
  const FormActions({
    super.key,
    required this.busy,
    required this.onSave,
    this.label = 'Guardar',
    this.onDelete,
    this.deleteLabel = 'Eliminar',
    this.topPadding = 30,
    this.canSave = true,
  });

  final bool busy;
  final VoidCallback onSave;
  final String label;
  final bool canSave;

  /// Acción destructiva de la pantalla; `null` si no la hay.
  final VoidCallback? onDelete;
  final String deleteLabel;

  /// Separación con el contenido de arriba. Se reduce en los formularios que
  /// van justos de alto en la tablet.
  final double topPadding;

  @override
  Widget build(BuildContext context) => ScreenActions(
    topPadding: topPadding,
    secondary: [
      OutlinedButton.icon(
        onPressed: busy ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.close),
        label: const Text('Cancelar'),
      ),
    ],
    primary: FilledButton.icon(
      onPressed: busy || !canSave ? null : onSave,
      icon: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: 'Guardando',
              ),
            )
          : const Icon(Icons.check),
      label: Text(busy ? 'Guardando…' : label),
    ),
    destructive: onDelete == null
        ? null
        : OutlinedButton.icon(
            onPressed: busy ? null : onDelete,
            icon: const Icon(Icons.delete_outline),
            label: Text(deleteLabel),
          ),
  );
}

/// Pide confirmación antes de borrar. Devuelve `true` solo si se confirma.
Future<bool> confirmDelete(
  BuildContext context,
  String title,
  String message,
) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return confirmado ?? false;
}
