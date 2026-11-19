import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/domain.dart';
import '../services/repository.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'task_steps_screen.dart';

/// La tarea, vista como la hace el alumno: se entra directamente en el primer
/// paso y se avanza de uno en uno.
///
/// La lista completa de pasos no se enseña de entrada ---abruma--- sino detrás
/// del botón «Ver los pasos». Cuando una tarea tiene un único paso, que es lo
/// habitual, no hay navegación de pasos y la pantalla es la tarea entera.
///
/// El botón de escuchar va dentro de la tarjeta que lee, no arriba en la
/// barra, donde se confundía con la navegación.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.student,
    required this.task,
    this.dayTasks = const [],
  });

  final AppUser student;
  final AgendaTask task;

  /// Tareas del día, en orden. Sirven para encadenar con la siguiente al
  /// terminar y para localizar la tarea alternativa.
  final List<AgendaTask> dayTasks;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late AgendaTask task;
  int paso = 0;
  bool ocupado = false;
  String? error;

  @override
  void initState() {
    super.initState();
    task = widget.task;
  }

  bool get esSuPropiaAgenda => AppScope.of(context).student;
  bool get laCreoElAlumno => task.creator == widget.student.username;
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

  /// Pasos reales de la tarea. Una tarea sin pasos guardados se maneja como un
  /// paso único con su descripción.
  List<TaskStep> get pasos => task.steps.isEmpty ? const [] : task.steps;
  bool get porPasos => pasos.length > 1;
  TaskStep? get pasoActual => porPasos ? pasos[paso] : null;

  /// La tarea alternativa, si está puesta y es una de las del día.
  AgendaTask? get alternativa {
    final id = task.alternativeId;
    if (id == null) return null;
    for (final otra in widget.dayTasks) {
      if (otra.id == id) return otra;
    }
    return null;
  }

  /// Siguiente tarea pendiente del día, para encadenar al terminar.
  AgendaTask? get siguientePendiente {
    final pendientes = widget.dayTasks
        .where((otra) => otra.id != task.id && !otra.finished)
        .toList();
    if (pendientes.isEmpty) return null;
    final posicion = widget.dayTasks.indexWhere((otra) => otra.id == task.id);
    for (final otra in pendientes) {
      if (widget.dayTasks.indexOf(otra) > posicion) return otra;
    }
    return pendientes.first;
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
    if (!mounted) return;
    setState(() => task = actualizada);
    final siguiente = siguientePendiente;
    await showCelebration(
      context,
      message: siguiente == null
          ? 'Has terminado «${task.title}». No te queda ninguna tarea para este día.'
          : 'Has terminado «${task.title}». Ahora toca «${siguiente.title}».',
      continueLabel: siguiente == null
          ? 'Volver a mis tareas'
          : 'Ir a la siguiente tarea',
    );
    if (!mounted) return;
    // Al terminar, el alumno va derecho a donde está la siguiente tarea en
    // lugar de volver a la lista y tener que buscarla.
    if (siguiente == null) {
      Navigator.pop(context, true);
    } else {
      _irA(siguiente);
    }
  });

  void _irA(AgendaTask otra) => Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => TaskDetailScreen(
        student: widget.student,
        task: otra,
        dayTasks: widget.dayTasks,
      ),
    ),
  );

  Future<void> verLosPasos() async {
    final elegido = await openPage<int>(
      context,
      TaskStepsScreen(task: task, current: paso),
    );
    if (elegido != null && mounted) setState(() => paso = elegido);
  }

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
    return PageShell(
      title: task.title,
      subtitle: _cuando,
      actions: [UserAvatar(user: widget.student, size: 56)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null) Notice(error!, error: true),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: taskBadges(
              task,
              own: laCreoElAlumno,
              viewerIsStudent: esSuPropiaAgenda,
            ),
          ),
          const SizedBox(height: 22),
          _contenido(state),
          if (!esSuPropiaAgenda) const Notice(_loMarcaElAlumno),
          if (esDeAula) Notice(_seGestionaEnElAula(task.className!)),
          const SizedBox(height: 24),
          _acciones(),
        ],
      ),
    );
  }

  /// El paso actual entre sus flechas, o la tarea entera si no tiene pasos.
  Widget _contenido(AppState state) {
    final conPictograma =
        !esSuPropiaAgenda || state.access.flag('pictograms');
    final puedeEscuchar = !esSuPropiaAgenda || state.access.flag('talkback');
    final tarjeta = _TarjetaDeInstrucciones(
      titulo: pasoActual == null
          ? '¿Qué hay que hacer?'
          : 'Paso ${paso + 1} de ${pasos.length}: ${pasoActual!.title}',
      texto: _textoDelContenido,
      imagen: pasoActual?.image ?? task.image,
      icono: taskIcon(task.title),
      conPictograma: conPictograma,
      escuchar: puedeEscuchar ? _textoParaEscuchar : null,
    );
    if (!porPasos) return tarjeta;
    // Las flechas de paso ocupan el mismo lugar que las de la lista de tareas.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _flechaDePaso(anterior: true),
        Expanded(child: tarjeta),
        _flechaDePaso(anterior: false),
      ],
    );
  }

  static const _anchoDeFlecha = 72.0;

  Widget _flechaDePaso({required bool anterior}) {
    final puede = anterior ? paso > 0 : paso < pasos.length - 1;
    return SizedBox(
      width: _anchoDeFlecha,
      child: Align(
        child: IconAction(
          icon: anterior ? Icons.chevron_left : Icons.chevron_right,
          label: anterior ? 'Paso anterior' : 'Paso siguiente',
          onPressed: puede
              ? () => setState(() => anterior ? paso-- : paso++)
              : null,
        ),
      ),
    );
  }

  String get _textoDelContenido {
    final texto = pasoActual?.description ?? task.description;
    if (texto.trim().isNotEmpty) return texto;
    return 'Realiza la actividad indicada en el título: ${task.title}.';
  }

  String get _cuando {
    final fecha = DateFormat('EEEE d MMMM', 'es').format(task.date);
    final hora = task.startHour?.substring(0, 5) ?? 'Sin hora fija';
    return '$fecha · $hora · ${task.duration} min';
  }

  String get _textoParaEscuchar {
    final titulo = pasoActual == null ? task.title : pasoActual!.title;
    return '$titulo. $_textoDelContenido';
  }

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
      if (porPasos)
        OutlinedButton.icon(
          onPressed: ocupado ? null : verLosPasos,
          icon: const Icon(Icons.list_alt_outlined),
          label: const Text('Ver los pasos'),
        ),
      // La alternativa es de la tarea, no de cada paso: por eso vive aquí.
      if (alternativa != null)
        OutlinedButton.icon(
          onPressed: ocupado ? null : () => _irA(alternativa!),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Hacer la tarea alternativa'),
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
  const _TarjetaDeInstrucciones({
    required this.titulo,
    required this.texto,
    required this.icono,
    required this.conPictograma,
    this.imagen,
    this.escuchar,
  });

  final String titulo;
  final String texto;
  final IconData icono;
  final bool conPictograma;
  final Uint8List? imagen;

  /// Texto que lee el botón de escuchar; `null` si la sesión no lo tiene.
  final String? escuchar;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (conPictograma) ...[
            ContentPicture(bytes: imagen, icon: icono, size: 150),
            const SizedBox(width: 22),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 10),
                Text(texto, style: const TextStyle(fontSize: 19, height: 1.6)),
                if (escuchar != null) ...[
                  const SizedBox(height: 18),
                  SpeechButton(text: escuchar!),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
