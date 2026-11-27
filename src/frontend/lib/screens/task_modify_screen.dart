import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/domain.dart';
import '../models/validation.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';

/// Pantalla para modificar los datos de una tarea existente de un alumno.
class TaskModifyScreen extends StatefulWidget {
  const TaskModifyScreen({
    super.key,
    required this.student,
    required this.task,
  });

  final AppUser student;
  final AgendaTask task;

  @override
  State<TaskModifyScreen> createState() => _TaskModifyScreenState();
}

class _TaskModifyScreenState extends State<TaskModifyScreen> {
  final form = GlobalKey<FormState>();
  final titulo = TextEditingController();
  final duracion = TextEditingController();
  late DateTime fecha;
  TimeOfDay? hora;
  bool guardando = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final tarea = widget.task;
    titulo.text = tarea.title;
    duracion.text = '${tarea.duration}';
    fecha = tarea.date;
    hora = _leerHora(tarea.startHour);
  }

  @override
  void dispose() {
    titulo.dispose();
    duracion.dispose();
    super.dispose();
  }

  static TimeOfDay? _leerHora(String? valor) {
    if (valor == null) return null;
    final partes = valor.split(':');
    if (partes.length < 2) return null;
    final h = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
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
      initialTime: hora ?? const TimeOfDay(hour: 17, minute: 0),
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
          alternativeId: widget.task.alternativeId,
        ),
        previous: widget.task,
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
    title: 'Modificar tarea',
    subtitle: 'Para ${widget.student.displayName}',
    actions: [UserAvatar(user: widget.student, size: 56)],
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
          const SectionTitle('Cuándo se hace'),
          _camposDeHorario(),
          const SizedBox(height: 14),
          Text(
            _fueraDelHorario,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (error != null) Notice(error!, error: true),
          FormActions(
            busy: guardando,
            onSave: guardar,
            label: 'Guardar cambios',
          ),
        ],
      ),
    ),
  );

  Widget _insignias() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      if (widget.task.className != null)
        StatusBadge(
          'Aula · ${widget.task.className}',
          tone: BadgeTone.main,
          icon: Icons.groups_outlined,
        )
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
      StatusBadge(
        widget.task.finished ? 'Completada' : 'Pendiente',
        tone: widget.task.finished ? BadgeTone.done : BadgeTone.neutral,
        icon: widget.task.finished
            ? Icons.check_circle_outline
            : Icons.radio_button_unchecked,
      ),
    ],
  );

  Widget _campoTitulo() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ContentPicture(
        bytes: widget.task.image,
        icon: taskIcon(titulo.text),
        size: 86,
      ),
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
      if (hora != null)
        TextButton(
          onPressed: guardando ? null : () => setState(() => hora = null),
          child: const Text('Sin hora fija'),
        ),
    ],
  );

  static const _fueraDelHorario =
      'La tarea debe quedar fuera del horario escolar (09:00–15:00). '
      'También puede no tener hora fija.';
}
