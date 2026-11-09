import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/domain.dart';
import '../services/repository.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'days_screen.dart';
import 'task_detail_screen.dart';
import 'task_editor_screen.dart';

/// Agenda de un alumno para un día: la ve él mismo o quien le acompaña.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key, required this.student});

  final AppUser student;

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  static const _filtros = ['Todas', 'Pendientes', 'Completadas'];

  DateTime dia = DateTime.now();
  String filtro = _filtros.first;
  int revision = 0;
  String? aviso;

  /// La sesión es la del propio alumno (y no la de quien le acompaña).
  bool get esSuPropiaAgenda => AppScope.of(context).student;

  AccessSettings get ajustes => esSuPropiaAgenda
      ? AppScope.of(context).access
      : widget.student.access;

  void _recargar({String? mensaje}) => setState(() {
    revision++;
    aviso = mensaje;
  });

  Future<void> crearTarea() async {
    final guardada = await openPage<bool>(
      context,
      TaskEditorScreen(student: widget.student, date: dia),
    );
    if (mounted && guardada == true) {
      _recargar(mensaje: 'La tarea se ha guardado.');
    }
  }

  Future<void> abrirTarea(AgendaTask tarea) async {
    await openPage<bool>(
      context,
      TaskDetailScreen(student: widget.student, task: tarea),
    );
    if (mounted) _recargar();
  }

  Future<void> elegirDia() async {
    final elegido = await openPage<DateTime>(context, DaysScreen(selected: dia));
    if (elegido != null && mounted) {
      setState(() {
        dia = elegido;
        revision++;
      });
    }
  }

  List<AgendaTask> _filtrar(List<AgendaTask> tareas) => switch (filtro) {
    'Pendientes' => tareas.where((t) => !t.finished).toList(),
    'Completadas' => tareas.where((t) => t.finished).toList(),
    _ => tareas,
  };

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PageShell(
      title: esSuPropiaAgenda
          ? 'Mis tareas'
          : 'Tareas de ${widget.student.displayName}',
      subtitle: DateFormat('EEEE d MMMM', 'es').format(dia),
      actions: [UserAvatar(user: widget.student, size: 60)],
      footer: const AppFooter(),
      child: Column(
        children: [
          _ClaseDelAlumno(student: widget.student),
          _barraDeDia(),
          const SizedBox(height: 22),
          if (!esSuPropiaAgenda || ajustes.flag('filters')) _filtrosDeEstado(),
          if (aviso != null) Notice(aviso!),
          const SizedBox(height: 20),
          if (state.repository.canReadAgenda)
            _listaDeTareas(state)
          else
            const Notice(_servidorSinAgenda),
          const SizedBox(height: 26),
          if (!esSuPropiaAgenda || ajustes.flag('task_mod'))
            FilledButton.icon(
              onPressed: crearTarea,
              icon: const Icon(Icons.add),
              label: Text(esSuPropiaAgenda ? 'Añadir mi tarea' : 'Crear tarea'),
            ),
        ],
      ),
    );
  }

  Widget _barraDeDia() => Wrap(
    alignment: WrapAlignment.center,
    spacing: 16,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (!esSuPropiaAgenda || ajustes.number('ndays_visible') > 0)
        OutlinedButton.icon(
          onPressed: elegirDia,
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Elegir día'),
        ),
      if (!esSuPropiaAgenda || ajustes.flag('talkback'))
        SpeechButton(
          text: 'Tareas del ${DateFormat('EEEE d MMMM', 'es').format(dia)}',
        ),
    ],
  );

  Widget _filtrosDeEstado() => Wrap(
    spacing: 12,
    runSpacing: 12,
    alignment: WrapAlignment.center,
    children: [
      for (final opcion in _filtros)
        ChoiceChip(
          label: Text(opcion),
          selected: filtro == opcion,
          onSelected: (_) => setState(() => filtro = opcion),
        ),
    ],
  );

  static const _servidorSinAgenda =
      'Este servidor todavía no permite consultar la lista de tareas de un '
      'alumno. Puedes crear tareas nuevas y se guardarán en su agenda.';

  Widget _listaDeTareas(AppState state) => LoadPanel<List<AgendaTask>>(
    key: ValueKey('$revision/${isoDate(dia)}'),
    load: () => state.repository.agenda(widget.student.username, dia),
    builder: (tareas) {
      final visibles = _filtrar(tareas);
      return PagedItems<AgendaTask>(
        items: visibles,
        pageSize: _tareasPorPagina(visibles.length),
        empty: tareas.isEmpty
            ? 'No hay actividades para esta fecha.'
            : 'No hay tareas con este filtro.',
        builder: (tarea) => _ficha(tarea, state),
      );
    },
  );

  int _tareasPorPagina(int total) {
    final configuradas = ajustes.number('ntasks_visible');
    if (configuradas > 0) return configuradas;
    return total == 0 ? 1 : total;
  }

  Widget _ficha(AgendaTask tarea, AppState state) {
    final esSuya = esSuPropiaAgenda && tarea.creator == state.user!.username;
    return ActionTile(
      title: tarea.title,
      subtitle:
          '${tarea.startHour?.substring(0, 5) ?? 'Sin hora fija'} · ${tarea.duration} min',
      icon: taskIcon(tarea.title),
      edge: tarea.finished ? Paleta.bosque : Paleta.terracota,
      badges: taskBadges(tarea, own: esSuya),
      leading: ajustes.flag('pictograms')
          ? ContentPicture(
              bytes: tarea.image,
              icon: taskIcon(tarea.title),
              size: 80,
            )
          : null,
      onTap: () => abrirTarea(tarea),
    );
  }
}

/// Aula a la que pertenece el alumno (SCRUM-325). Si no consta, no ocupa sitio.
class _ClaseDelAlumno extends StatelessWidget {
  const _ClaseDelAlumno({required this.student});

  final AppUser student;

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: AppScope.of(context).repository.classOf(student.username),
    builder: (context, snapshot) {
      final aula = snapshot.data;
      if (aula == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: StatusBadge(
          'Mi clase · $aula',
          tone: BadgeTone.main,
          icon: Icons.school_outlined,
        ),
      );
    },
  );
}
