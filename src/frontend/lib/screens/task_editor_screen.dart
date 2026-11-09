import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/domain.dart';
import '../models/validation.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';

/// Alta y edición de una tarea.
///
/// La Iteración 1 la trata como una unidad: título, descripción, fecha, hora
/// de inicio, duración y destinatario (un alumno o un aula entera).
class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({
    super.key,
    required this.student,
    required this.date,
    this.task,
    this.classroom,
  });

  final AppUser student;
  final DateTime date;

  /// Tarea existente que se edita; `null` al crear una nueva.
  final AgendaTask? task;

  /// Aula destinataria cuando la tarea es para toda la clase.
  final String? classroom;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final form = GlobalKey<FormState>();
  final titulo = TextEditingController();
  final descripcion = TextEditingController();
  final duracion = TextEditingController();
  late DateTime fecha;
  TimeOfDay? hora;
  bool guardando = false;
  String? error;

  bool get esNueva => widget.task == null;
  bool get esDeAula => widget.classroom != null;
  bool get esPersonalDelCentro =>
      AppScope.of(context).user!.role == UserRole.staff;

  /// Algunos servidores solo guardan los datos básicos de la tarea.
  bool get guardaDescripcion =>
      AppScope.of(context).repository.supportsTaskContent;

  @override
  void initState() {
    super.initState();
    final tarea = widget.task;
    titulo.text = tarea?.title ?? '';
    descripcion.text = tarea?.description ?? '';
    duracion.text = '${tarea?.duration ?? 15}';
    fecha = tarea?.date ?? widget.date;
    hora = _leerHora(tarea?.startHour);
  }

  @override
  void dispose() {
    titulo.dispose();
    descripcion.dispose();
    duracion.dispose();
    super.dispose();
  }

  static TimeOfDay? _leerHora(String? valor) {
    if (valor == null) return null;
    final partes = valor.split(':');
    return TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]));
  }

  String? get horaComoTexto => hora == null
      ? null
      : '${hora!.hour.toString().padLeft(2, '0')}:'
            '${hora!.minute.toString().padLeft(2, '0')}:00';

  Future<void> elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida != null && mounted) setState(() => fecha = elegida);
  }

  Future<void> elegirHora() async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: hora ?? TimeOfDay(hour: esPersonalDelCentro ? 9 : 17, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (elegida != null && mounted) setState(() => hora = elegida);
  }

  Future<void> guardar() async {
    if (!form.currentState!.validate()) return;
    final state = AppScope.of(context);
    final minutos = int.parse(duracion.text);
    final problema = scheduleError(state.user!.role, horaComoTexto, minutos);
    if (problema != null) {
      setState(() => error = problema);
      return;
    }
    setState(() {
      guardando = true;
      error = null;
    });
    try {
      await state.repository.saveTask(
        widget.student.username,
        TaskDraft(
          title: titulo.text.trim(),
          date: fecha,
          duration: minutos,
          startHour: horaComoTexto,
          description: descripcion.text,
          alternativeId: widget.task?.alternativeId,
        ),
        previous: widget.task,
        classroom: widget.classroom,
      );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  Future<void> eliminar() async {
    final alcance = esDeAula ? ' de toda el aula' : '';
    final confirmado = await confirmDelete(
      context,
      'Eliminar tarea',
      'Se retirará «${widget.task!.title}» de la agenda$alcance.',
    );
    if (!confirmado || !mounted) return;
    setState(() {
      guardando = true;
      error = null;
    });
    try {
      await AppScope.of(context).repository.deleteTask(
        widget.student.username,
        widget.task!,
        classroom: widget.classroom,
      );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: esNueva ? 'Crear tarea' : 'Modificar tarea',
    subtitle: esDeAula
        ? 'Para toda el aula: ${widget.classroom}'
        : 'Para ${widget.student.displayName}',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _insignias(),
          const SectionTitle(
            'Datos de la tarea',
            hint: 'Usa frases cortas y claras para el alumno.',
          ),
          _campoTitulo(),
          if (guardaDescripcion) ...[
            const SizedBox(height: 10),
            _campoDescripcion(),
          ],
          const SectionTitle('Cuándo se hace'),
          _camposDeHorario(),
          const SizedBox(height: 14),
          Text(
            esPersonalDelCentro ? _horarioDelCentro : _fueraDelHorario,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (error != null) Notice(error!, error: true),
          FormActions(busy: guardando, onSave: guardar, label: 'Guardar tarea'),
          if (!esNueva)
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: OutlinedButton.icon(
                onPressed: guardando ? null : eliminar,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar tarea'),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _insignias() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      if (esDeAula)
        const StatusBadge('Aula', tone: BadgeTone.main, icon: Icons.groups_outlined)
      else
        const StatusBadge(
          'Tarea individual',
          tone: BadgeTone.warm,
          icon: Icons.person_outline,
        ),
      StatusBadge(
        DateFormat('EEEE d MMMM', 'es').format(fecha),
        tone: BadgeTone.attention,
        icon: Icons.event_outlined,
      ),
    ],
  );

  Widget _campoTitulo() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ContentPicture(icon: taskIcon(titulo.text), size: 86),
      const SizedBox(width: 20),
      Expanded(
        child: TextFormField(
          controller: titulo,
          enabled: !guardando,
          maxLength: 100,
          validator: requiredText,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Nombre de la tarea *'),
        ),
      ),
    ],
  );

  Widget _campoDescripcion() => TextFormField(
    controller: descripcion,
    enabled: !guardando,
    minLines: 4,
    maxLines: 8,
    maxLength: 5000,
    decoration: const InputDecoration(
      labelText: 'Descripción de la tarea',
      helperText:
          'Opcional. Explica qué hay que hacer, una indicación por línea.',
    ),
  );

  Widget _camposDeHorario() => Wrap(
    spacing: 20,
    runSpacing: 18,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      OutlinedButton.icon(
        onPressed: guardando ? null : elegirFecha,
        icon: const Icon(Icons.calendar_month_outlined),
        label: Text('Fecha: ${DateFormat('dd/MM/yyyy').format(fecha)}'),
      ),
      OutlinedButton.icon(
        onPressed: guardando ? null : elegirHora,
        icon: const Icon(Icons.schedule),
        label: Text(
          horaComoTexto == null
              ? 'Elegir hora de inicio'
              : 'Inicio: ${horaComoTexto!.substring(0, 5)}',
        ),
      ),
      SizedBox(
        width: 230,
        child: TextFormField(
          controller: duracion,
          enabled: !guardando,
          keyboardType: TextInputType.number,
          validator: positiveInteger,
          decoration: const InputDecoration(labelText: 'Duración (minutos) *'),
        ),
      ),
      if (!esPersonalDelCentro && hora != null)
        TextButton(
          onPressed: guardando ? null : () => setState(() => hora = null),
          child: const Text('Sin hora fija'),
        ),
    ],
  );

  static const _horarioDelCentro =
      'La tarea debe quedar entre las 09:00 y las 15:00.';
  static const _fueraDelHorario =
      'La tarea debe quedar fuera del horario escolar (09:00–15:00). '
      'También puede no tener hora fija.';
}
