import 'package:flutter/material.dart';

/// Pareja de acciones al pie de un formulario: cancelar y guardar.
class FormActions extends StatelessWidget {
  const FormActions({
    super.key,
    required this.busy,
    required this.onSave,
    this.label = 'Guardar',
  });

  final bool busy;
  final VoidCallback onSave;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 30),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 24,
      runSpacing: 14,
      children: [
        OutlinedButton.icon(
          onPressed: busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          label: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: busy ? null : onSave,
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
      ],
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
