import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/domain.dart';
import '../models/task_timer.dart';
import '../state/app_state.dart';
import '../ui/components.dart';
import '../ui/navigation.dart';
import 'task_editor_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key, required this.student});
  final AppUser student;
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime date = DateTime.now();
  int revision = 0;
  String filter = 'Todas';
  String? message;
  Future<void> edit([AgendaTask? task]) async {
    final result = await openPage<bool>(
      context,
      TaskEditorScreen(
        student: widget.student,
        date: date,
        task: task,
        classroom: task?.className,
      ),
    );
    if (mounted && result == true) {
      setState(() {
        revision++;
        message = 'La tarea se ha guardado.';
      });
    }
  }

  Future<void> selectDay() async {
    final selected = await openPage<DateTime>(
      context,
      DaysScreen(selected: date),
    );
    if (selected != null && mounted) {
      setState(() {
        date = selected;
        revision++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final own = state.student;
    final settings = own ? state.access : widget.student.access;
    return PageShell(
      title: own ? 'Mis tareas' : 'Tareas de ${widget.student.displayName}',
      subtitle: DateFormat('EEEE d MMMM', 'es').format(date),
      actions: [UserAvatar(user: widget.student, size: 56)],
      footer: const AppFooter(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!own || settings.number('ndays_visible') > 0)
                OutlinedButton.icon(
                  onPressed: selectDay,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Elegir día'),
                ),
              if (!own || settings.flag('talkback'))
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: SpeechButton(
                    text:
                        'Tareas del ${DateFormat('EEEE d MMMM', 'es').format(date)}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (!own || settings.flag('filters'))
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final value in ['Todas', 'Pendientes', 'Completadas'])
                  ChoiceChip(
                    label: Text(value),
                    selected: filter == value,
                    onSelected: (_) => setState(() => filter = value),
                  ),
              ],
            ),
          if (message != null) Notice(message!),
          const SizedBox(height: 20),
          LoadPanel<List<AgendaTask>>(
            key: ValueKey('$revision/${isoDate(date)}'),
            load: () => state.repository.agenda(widget.student.username, date),
            builder: (tasks) {
              final filtered = tasks
                  .where(
                    (t) =>
                        filter == 'Todas' ||
                        (filter == 'Completadas' ? t.finished : !t.finished),
                  )
                  .toList();
              return PagedItems<AgendaTask>(
                items: filtered,
                pageSize: settings.number('ntasks_visible') == 0
                    ? (filtered.isEmpty ? 1 : filtered.length)
                    : settings.number('ntasks_visible'),
                empty: tasks.isEmpty
                    ? 'No hay actividades para esta fecha.'
                    : 'No hay tareas con este filtro.',
                builder: (task) => ActionTile(
                  title: task.title,
                  subtitle:
                      '${task.startHour?.substring(0, 5) ?? 'Sin hora fija'} · ${task.duration} min · ${task.finished ? 'Completada' : 'Pendiente'}',
                  icon: taskIcon(task.title),
                  leading: settings.flag('pictograms')
                      ? ContentPicture(
                          bytes: task.image,
                          icon: taskIcon(task.title),
                          size: 170,
                        )
                      : null,
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        task.finished
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        semanticLabel: task.finished
                            ? 'Completada'
                            : 'Pendiente',
                      ),
                      if (!own || task.creator == state.user!.username)
                        IconButton(
                          tooltip: 'Editar tarea',
                          onPressed: () => edit(task),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                    ],
                  ),
                  onTap: () async {
                    await openPage(
                      context,
                      own && !task.finished && task.steps.isNotEmpty
                          ? TaskRunScreen(student: widget.student, task: task)
                          : TaskDetailScreen(
                              student: widget.student,
                              task: task,
                            ),
                    );
                    if (mounted) setState(() => revision++);
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          if (!own || settings.flag('task_mod'))
            FilledButton.icon(
              onPressed: () => edit(),
              icon: const Icon(Icons.add),
              label: Text(own ? 'Añadir mi tarea' : 'Crear tarea'),
            ),
        ],
      ),
    );
  }
}

class DaysScreen extends StatefulWidget {
  const DaysScreen({super.key, required this.selected});
  final DateTime selected;
  @override
  State<DaysScreen> createState() => _DaysScreenState();
}

class _DaysScreenState extends State<DaysScreen> {
  late DateTime monday;
  @override
  void initState() {
    super.initState();
    monday = widget.selected.subtract(
      Duration(days: widget.selected.weekday - 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final count = state.student
        ? state.access.number('ndays_visible').clamp(1, 7)
        : 7;
    return PageShell(
      title: 'Elige un día',
      subtitle: 'Semana del ${DateFormat('d MMMM', 'es').format(monday)}',
      footer: const AppFooter(),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                SizedBox(
                  width: 160,
                  child: ActionTile(
                    title: DateFormat(
                      'EEEE',
                      'es',
                    ).format(monday.add(Duration(days: i))),
                    subtitle: DateFormat(
                      'd MMM',
                      'es',
                    ).format(monday.add(Duration(days: i))),
                    icon: Icons.today_outlined,
                    vertical: true,
                    onTap: () =>
                        Navigator.pop(context, monday.add(Duration(days: i))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 30,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(
                  () => monday = monday.subtract(const Duration(days: 7)),
                ),
                icon: const Icon(Icons.chevron_left),
                label: const Text('Semana anterior'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, DateTime.now()),
                child: const Text('Hoy'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(
                  () => monday = monday.add(const Duration(days: 7)),
                ),
                icon: const Icon(Icons.chevron_right),
                label: const Text('Semana siguiente'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
  late final TaskTimer timer;
  String? error, message;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    task = widget.task;
    timer = TaskTimer(task.duration * 60);
  }

  @override
  void dispose() {
    timer.dispose();
    super.dispose();
  }

  Future<void> run(int index) async {
    final result = await openPage<AgendaTask>(
      context,
      TaskRunScreen(
        student: widget.student,
        task: task,
        initialIndex: index,
        timer: timer,
      ),
    );
    if (result != null && mounted) {
      if (result.finished) {
        Navigator.pop(context, result);
      } else {
        setState(() => task = result);
      }
    }
  }

  Future<void> complete() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await AppScope.of(
        context,
      ).repository.progress(widget.student.username, task, complete: true);
      timer.pause();
      if (mounted) {
        Navigator.pop(context, result);
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final own = state.student;
    final talk = !own || state.access.flag('talkback');
    return PageShell(
      title: task.title,
      subtitle:
          '${task.duration} minutos · ${task.finished ? 'Completada' : 'Paso a paso'}',
      actions: [
        if (talk) SpeechButton(text: task.title),
        UserAvatar(user: widget.student, size: 52),
      ],
      footer: const AppFooter(),
      child: Column(
        children: [
          if (message != null) Notice(message!),
          if (error != null) Notice(error!, error: true),
          if (!own)
            const Notice(
              'Puedes consultar los pasos. El alumno registra su progreso desde su sesión.',
            ),
          if (task.steps.isEmpty)
            const Notice(
              'Esta tarea no tiene pasos. Puedes realizarla y confirmar que has terminado.',
            ),
          PagedItems<TaskStep>(
            items: task.steps,
            empty: 'Realiza la actividad indicada en el título.',
            builder: (step) => ActionTile(
              title: step.title,
              subtitle: step.finished
                  ? 'Completado'
                  : step.required
                  ? 'Obligatorio · Pendiente'
                  : 'Guiado · Pendiente',
              icon: step.finished
                  ? Icons.check_circle_outline
                  : Icons.format_list_numbered,
              leading: state.access.flag('pictograms')
                  ? ContentPicture(
                      bytes: step.image,
                      icon: taskIcon(task.title),
                      size: 160,
                    )
                  : null,
              trailing: talk
                  ? SpeechButton(text: '${step.title}. ${step.description}')
                  : null,
              onTap: () => run(task.steps.indexOf(step)),
            ),
          ),
          const SizedBox(height: 20),
          if (own && !task.finished)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 22,
              runSpacing: 14,
              children: [
                if (task.steps.isNotEmpty)
                  FilledButton.icon(
                    onPressed: busy ? null : () => run(0),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Empezar'),
                  ),
                OutlinedButton.icon(
                  onPressed: busy ? null : complete,
                  icon: const Icon(Icons.check),
                  label: const Text('He terminado la tarea'),
                ),
              ],
            ),
          if (task.alternativeId != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Actividad alternativa asociada: ${task.alternativeId}',
              ),
            ),
        ],
      ),
    );
  }
}

class TaskRunScreen extends StatefulWidget {
  const TaskRunScreen({
    super.key,
    required this.student,
    required this.task,
    this.initialIndex = 0,
    this.timer,
  });
  final AppUser student;
  final AgendaTask task;
  final int initialIndex;
  final TaskTimer? timer;
  @override
  State<TaskRunScreen> createState() => _TaskRunScreenState();
}

class _TaskRunScreenState extends State<TaskRunScreen>
    with WidgetsBindingObserver {
  late AgendaTask task;
  late int index;
  late final TaskTimer timer;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    task = widget.task;
    index = widget.initialIndex;
    timer = widget.timer ?? TaskTimer(task.duration * 60);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && AppScope.of(context).student && !task.finished) {
        timer.start();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.timer == null) {
      timer.dispose();
    } else {
      timer.pause();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      timer.pause();
    }
  }

  Future<void> finishStep() async {
    final repository = AppScope.of(context).repository;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await repository.progress(
        widget.student.username,
        task,
        stepId: task.steps[index].id,
        finished: true,
        complete: index == task.steps.length - 1,
      );
      if (mounted) {
        if (result.finished) {
          timer.pause();
          Navigator.pop(context, result);
          return;
        }
        setState(() {
          task = result;
          if (index < task.steps.length - 1) index++;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void leave() {
    timer.pause();
    Navigator.pop(context, task);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final step = task.steps[index];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && !busy) leave();
      },
      child: PageShell(
        title: task.title,
        subtitle: 'Paso ${index + 1} de ${task.steps.length}',
        showBack: false,
        actions: [
          if (state.access.flag('talkback'))
            SpeechButton(text: '${step.title}. ${step.description}'),
        ],
        footer: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 24,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () {
                      timer.reset();
                      if (state.student && !task.finished) timer.start();
                    },
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reiniciar reloj'),
            ),
            if (state.student)
              ListenableBuilder(
                listenable: timer,
                builder: (context, _) => FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => timer.running ? timer.pause() : timer.start(),
                  icon: Icon(timer.running ? Icons.pause : Icons.play_arrow),
                  label: Text(timer.running ? 'Pausar' : 'Continuar'),
                ),
              ),
            OutlinedButton.icon(
              onPressed: busy ? null : leave,
              icon: const Icon(Icons.arrow_back),
              label: Text(
                state.student ? 'Volver a mis tareas' : 'Volver a los pasos',
              ),
            ),
          ],
        ),
        child: Column(
          children: [
            if (state.access.flag('timebar'))
              ListenableBuilder(
                listenable: timer,
                builder: (context, _) => Column(
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: timer.fraction,
                              strokeWidth: 12,
                              semanticsLabel: 'Tiempo restante: ${timer.label}',
                              semanticsValue:
                                  '${(timer.fraction * 100).round()}',
                            ),
                          ),
                          Text(
                            timer.label,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ListenableBuilder(
              listenable: timer,
              builder: (_, _) => timer.remainingSeconds == 0 && !task.finished
                  ? const Notice(
                      'El tiempo ha terminado. La tarea sigue pendiente. Puedes pedir ayuda o continuar con calma.',
                    )
                  : const SizedBox.shrink(),
            ),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (state.access.flag('pictograms')) ...[
                      ContentPicture(
                        bytes: step.image,
                        icon: taskIcon(task.title),
                        size: 280,
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      step.description,
                      style: const TextStyle(fontSize: 22, height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    if (step.finished)
                      const Notice('Este paso está completado.'),
                    if (state.student && !task.finished)
                      FilledButton.icon(
                        onPressed: busy ? null : finishStep,
                        icon: const Icon(Icons.check),
                        label: Text(
                          busy
                              ? 'Guardando…'
                              : index == task.steps.length - 1
                              ? 'He terminado · Finalizar tarea'
                              : 'He terminado · Siguiente paso',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (error != null) Notice(error!, error: true),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Paso anterior',
                  onPressed: busy || index == 0
                      ? null
                      : () => setState(() => index--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    'Paso ${index + 1} de ${task.steps.length}',
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: state.student
                      ? 'Completar paso y continuar'
                      : 'Paso siguiente',
                  onPressed: busy || index == task.steps.length - 1
                      ? null
                      : state.student
                      ? finishStep
                      : () => setState(() => index++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
