import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../ui/ui.dart';

/// Lista de pasos de una tarea, detrás del botón «Ver los pasos».
///
/// No se muestra al entrar en la tarea: el alumno empieza por el primer paso y
/// consulta la lista solo si quiere situarse. Al tocar un paso se vuelve a la
/// tarea colocado en él.
class TaskStepsScreen extends StatelessWidget {
  const TaskStepsScreen({super.key, required this.task, required this.current});

  final AgendaTask task;

  /// Paso en el que está el alumno ahora mismo.
  final int current;

  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Pasos de la tarea',
    subtitle: task.title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < task.steps.length; i++) _ficha(context, i),
      ],
    ),
  );

  Widget _ficha(BuildContext context, int i) {
    final paso = task.steps[i];
    final esElActual = i == current;
    return ActionTile(
      title: 'Paso ${i + 1}: ${paso.title}',
      subtitle: paso.description.isEmpty
          ? 'Sin explicación añadida'
          : paso.description,
      icon: paso.finished
          ? Icons.check_circle_outline
          : Icons.radio_button_unchecked,
      edge: paso.finished ? Paleta.bosque : Paleta.terracota,
      badges: [
        if (esElActual)
          const StatusBadge(
            'Estás aquí',
            tone: BadgeTone.attention,
            icon: Icons.place_outlined,
          ),
        if (paso.finished)
          const StatusBadge(
            'Hecho',
            tone: BadgeTone.done,
            icon: Icons.check_circle_outline,
          ),
      ],
      onTap: () => Navigator.pop(context, i),
    );
  }
}
