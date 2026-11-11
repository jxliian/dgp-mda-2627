import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/domain.dart';
import '../services/repository.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';

/// Detalle de una tarea entendida como una unidad: qué hay que hacer, cuándo,
/// y las dos acciones de la Iteración 1 (darla por terminada o eliminarla).
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.student,
    required this.task,
  });

  final AppUser student;
  final AgendaTask task;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late AgendaTask task;
  bool ocupado = false;
  String? error;
  String? aviso;

  @override
  void initState() {
    super.initState();
    task = widget.task;
  }

  bool get esSuPropiaAgenda => AppScope.of(context).student;
  bool get laCreoElAlumno =>
      task.creator == AppScope.of(context).user?.username;
  bool get esDeAula => task.className != null;

  /// Marcar una tarea como hecha necesita que el servidor guarde el progreso.
  bool get puedeCompletar => AppScope.of(context).repository.canTrackProgress;

  /// Las tareas de aula se gestionan desde el aula. Las individuales las
  /// elimina su alumno (si tiene permiso) o quien le acompaña.
  bool get puedeEliminar {
    if (esDeAula) return false;
    if (!esSuPropiaAgenda) return true;
    return laCreoElAlumno && AppScope.of(context).access.flag('task_mod');
  }

  Future<void> _operar(
    Future<void> Function(AutovidaRepository repositorio) accion,
  ) async {
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      await accion(AppScope.of(context).repository);
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> darPorTerminada() => _operar((repositorio) async {
    final actualizada = await repositorio.completeTask(
      widget.student.username,
      task,
    );
    if (mounted) {
      setState(() {
        task = actualizada;
        aviso = '¡Muy bien! Has completado tu tarea.';
      });
    }
  });

  Future<void> eliminar() async {
    final confirmado = await confirmDelete(
      context,
      'Eliminar tarea',
      'Se retirará «${task.title}» de la agenda de ${widget.student.displayName}.',
    );
    if (!confirmado || !mounted) return;
    await _operar((repositorio) async {
      await repositorio.deleteTask(widget.student.username, task);
      if (mounted) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final puedeEscuchar = !esSuPropiaAgenda || state.access.flag('talkback');
    return PageShell(
      title: task.title,
      subtitle: _cuando,
      actions: [
        if (puedeEscuchar) SpeechButton(text: _textoParaEscuchar),
        const SizedBox(width: 12),
        UserAvatar(user: widget.student, size: 56),
      ],
      footer: const AppFooter(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (aviso != null) Notice(aviso!),
          if (error != null) Notice(error!, error: true),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: taskBadges(task, own: esSuPropiaAgenda && laCreoElAlumno),
          ),
          const SizedBox(height: 22),
          _TarjetaDeInstrucciones(
            task: task,
            conPictograma: !esSuPropiaAgenda || state.access.flag('pictograms'),
          ),
          if (!esSuPropiaAgenda) const Notice(_loMarcaElAlumno),
          if (esDeAula) Notice(_seGestionaEnElAula(task.className!)),
          const SizedBox(height: 24),
          _acciones(),
        ],
      ),
    );
  }

  String get _cuando {
    final fecha = DateFormat('EEEE d MMMM', 'es').format(task.date);
    final hora = task.startHour?.substring(0, 5) ?? 'Sin hora fija';
    return '$fecha · $hora · ${task.duration} min';
  }

  String get _textoParaEscuchar =>
      task.description.isEmpty ? task.title : '${task.title}. ${task.description}';

  Widget _acciones() => Wrap(
    spacing: 20,
    runSpacing: 14,
    children: [
      if (esSuPropiaAgenda && !task.finished && puedeCompletar)
        FilledButton.icon(
          onPressed: ocupado ? null : darPorTerminada,
          icon: const Icon(Icons.check),
          label: const Text('He terminado la tarea'),
        ),
      if (puedeEliminar)
        OutlinedButton.icon(
          onPressed: ocupado ? null : eliminar,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Eliminar tarea'),
        ),
    ],
  );

  static const _loMarcaElAlumno =
      'Puedes consultar la tarea. El alumno la marca como terminada desde su sesión.';
  static String _seGestionaEnElAula(String aula) =>
      'Es una tarea de toda el aula. Se modifica o elimina desde las tareas de $aula.';
}

class _TarjetaDeInstrucciones extends StatelessWidget {
  const _TarjetaDeInstrucciones({required this.task, required this.conPictograma});

  final AgendaTask task;
  final bool conPictograma;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (conPictograma) ...[
            ContentPicture(
              bytes: task.image,
              icon: taskIcon(task.title),
              size: 150,
            ),
            const SizedBox(width: 22),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    '¿Qué hay que hacer?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  task.description.isEmpty
                      ? 'Realiza la actividad indicada en el título: ${task.title}.'
                      : task.description,
                  style: const TextStyle(fontSize: 19, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
