import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/domain.dart';
import '../services/repository.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'days_screen.dart';
import 'task_detail_screen.dart';
import 'task_editor_screen.dart';
import 'task_modify_screen.dart';

/// Agenda de un alumno para un día: la ve él mismo o quien le acompaña.
///
/// Las tareas ocupan el centro de la pantalla. Todo lo demás ---elegir día,
/// la foto, inicio, ajustes y salir--- vive en la única barra de arriba.
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
  String? aula;
  bool aulaPedida = false;

  /// La sesión es la del propio alumno (y no la de quien le acompaña).
  bool get esSuPropiaAgenda => AppScope.of(context).student;

  /// La sesión pertenece a un tutor familiar consultando un alumno a su cargo.
  bool get esTutor => AppScope.of(context).user?.role == UserRole.parent;

  AccessSettings get ajustes => esSuPropiaAgenda
      ? AppScope.of(context).access
      : widget.student.access;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (aulaPedida) return;
    aulaPedida = true;
    // El aula acompaña al título en vez de ocupar una etiqueta propia, que
    // parecía un botón y no llevaba a ninguna parte.
    AppScope.of(context).repository.classOf(widget.student.username).then((
      nombre,
    ) {
      if (mounted) setState(() => aula = nombre);
    });
  }

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

  Future<void> abrirTarea(AgendaTask tarea, List<AgendaTask> delDia) async {
    await openPage<bool>(
      context,
      TaskDetailScreen(
        student: widget.student,
        task: tarea,
        dayTasks: delDia,
      ),
    );
    if (mounted) _recargar();
  }

  Future<void> modificarTarea(AgendaTask tarea) async {
    final guardada = await openPage<bool>(
      context,
      TaskModifyScreen(student: widget.student, task: tarea),
    );
    if (mounted && guardada == true) {
      _recargar(mensaje: 'La tarea se ha modificado.');
    }
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

  bool get _puedeElegirDia =>
      !esSuPropiaAgenda || ajustes.number('ndays_visible') > 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PageShell(
      title: esSuPropiaAgenda
          ? 'Mis tareas'
          : 'Tareas de ${widget.student.displayName}',
      subtitle: _subtitulo,
      // La foto va delante, pegada al título: así los botones de la barra
      // quedan todos seguidos y no hay nada entre medias que parezca uno.
      actions: [
        UserAvatar(user: widget.student, size: 64),
        if (_puedeElegirDia)
          BarAction(
            icon: Icons.calendar_month_outlined,
            label: 'Elegir día',
            onPressed: elegirDia,
          ),
      ],
      child: Column(
        children: [
          // Los filtros son una herramienta de quien acompaña al alumno; en su
          // propia agenda solo añaden ruido.
          if (!esSuPropiaAgenda) _filtrosDeEstado(),
          if (aviso != null) Notice(aviso!),
          const SizedBox(height: 12),
          if (state.repository.canReadAgenda)
            _listaDeTareas(state)
          else
            const Notice(_servidorSinAgenda),
          const SizedBox(height: 16),
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

  String get _subtitulo {
    final fecha = DateFormat('EEEE d MMMM', 'es').format(dia);
    return aula == null ? fecha : '$fecha · $aula';
  }

  Widget _filtrosDeEstado() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Wrap(
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
    ),
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
        builder: (tarea) => _ficha(tarea, tareas),
      );
    },
  );

  int _tareasPorPagina(int total) {
    final configuradas = ajustes.number('ntasks_visible');
    if (configuradas > 0) return configuradas;
    return total == 0 ? 1 : total;
  }

  Widget _ficha(AgendaTask tarea, List<AgendaTask> delDia) {
    final esSuya = tarea.creator == widget.student.username;
    return ActionTile(
      title: tarea.title,
      subtitle:
          '${tarea.startHour?.substring(0, 5) ?? 'Sin hora fija'} · ${tarea.duration} min',
      icon: taskIcon(tarea.title),
      edge: tarea.finished ? Paleta.bosque : Paleta.terracota,
      badges: taskBadges(
        tarea,
        own: esSuya,
        viewerIsStudent: esSuPropiaAgenda,
      ),
      leading: ajustes.flag('pictograms')
          ? ContentPicture(
              bytes: tarea.image,
              icon: taskIcon(tarea.title),
              size: 120,
            )
          : null,
      trailing: esTutor ? _botonModificar(tarea) : null,
      onTap: () => abrirTarea(tarea, delDia),
    );
  }

  /// Botón táctil pensado para tablet: objetivo amplio de 72 × 72 dp, icono
  /// nítido y contorno de alto contraste separado del área principal de la
  /// ficha para evitar pulsaciones accidentales.
  Widget _botonModificar(AgendaTask tarea) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final oscuro = esquema.brightness == Brightness.dark;
    final bordeBase = oscuro ? esquema.outline : Paleta.trazoControl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: IconButton.outlined(
        tooltip: 'Modificar la tarea ${tarea.title}',
        onPressed: () => modificarTarea(tarea),
        icon: const Icon(Icons.edit_outlined, size: 30),
        style: IconButton.styleFrom(
          minimumSize: const Size(72, 72),
          padding: const EdgeInsets.all(18),
          backgroundColor: oscuro ? esquema.surface : Paleta.blanco,
          foregroundColor: esquema.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Medidas.radioControl),
          ),
        ).copyWith(
          side: WidgetStateProperty.resolveWith(
            (estados) => estados.contains(WidgetState.focused)
                ? BorderSide(color: tema.focusColor, width: Medidas.anilloFoco)
                : BorderSide(color: bordeBase, width: Medidas.trazoGrueso),
          ),
        ),
      ),
    );
  }
}
