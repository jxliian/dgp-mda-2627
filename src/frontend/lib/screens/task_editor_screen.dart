import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/domain.dart';
import '../models/validation.dart';
import '../state/app_state.dart';
import '../ui/components.dart';

Future<Uint8List?> pickPicture() async {
  final file = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(
        label: 'Imágenes',
        extensions: ['png', 'jpg', 'jpeg', 'webp'],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > 5 * 1024 * 1024) {
    throw StateError('La imagen no puede superar los 5 MB.');
  }
  return file.readAsBytes();
}

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
  final AgendaTask? task;
  final String? classroom;
  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final duration = TextEditingController();
  final alternative = TextEditingController();
  late DateTime date;
  TimeOfDay? hour;
  final Set<int> weekdays = {};
  final List<TaskStep> steps = [];
  final Set<String> savedDates = {};
  Uint8List? image;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final task = widget.task;
    title.text = task?.title ?? '';
    duration.text = '${task?.duration ?? 15}';
    alternative.text = task?.alternativeId?.toString() ?? '';
    date = task?.date ?? widget.date;
    weekdays.add(date.weekday);
    if (task?.startHour != null) {
      final parts = task!.startHour!.split(':');
      hour = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    steps.addAll(task?.steps ?? []);
    image = task?.image;
  }

  @override
  void dispose() {
    title.dispose();
    duration.dispose();
    alternative.dispose();
    super.dispose();
  }

  String? get hourValue => hour == null
      ? null
      : '${hour!.hour.toString().padLeft(2, '0')}:${hour!.minute.toString().padLeft(2, '0')}:00';
  Future<void> chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value != null && mounted) {
      setState(() {
        date = value;
        weekdays
          ..clear()
          ..add(value.weekday);
        savedDates.clear();
      });
    }
  }

  Future<void> addStep([int? index]) async {
    final result = await openPage<TaskStep>(
      context,
      StepEditorScreen(
        taskTitle: title.text.trim().isEmpty
            ? 'Nueva tarea'
            : title.text.trim(),
        step: index == null ? null : steps[index],
        nextIndex: steps.length,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index != null) steps.removeAt(index);
      steps.insert(result.index.clamp(0, steps.length), result);
      for (var i = 0; i < steps.length; i++) {
        steps[i] = steps[i].atIndex(i);
      }
    });
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final state = AppScope.of(context);
    final validation = scheduleError(
      state.user!.role,
      hourValue,
      int.parse(duration.text),
    );
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    if (weekdays.isEmpty) {
      setState(() => error = 'Elige al menos un día.');
      return;
    }
    final monday = DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - 1));
    final dates = widget.task != null
        ? [date]
        : (weekdays.toList()..sort())
              .map((d) => monday.add(Duration(days: d - 1)))
              .toList();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      for (final selected in dates) {
        if (savedDates.contains(isoDate(selected))) continue;
        await state.repository.saveTask(
          widget.student.username,
          TaskDraft(
            title: title.text.trim(),
            date: selected,
            duration: int.parse(duration.text),
            startHour: hourValue,
            alternativeId: int.tryParse(alternative.text),
            steps: steps,
            image: image,
          ),
          previous: widget.task,
          classroom: widget.classroom,
        );
        savedDates.add(isoDate(selected));
      }
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => error =
              '${e.toString()}${savedDates.isEmpty ? '' : '\nYa se ha guardado en: ${savedDates.join(', ')}. Al reintentar se omitirán esos días.'}',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove() async {
    final state = AppScope.of(context);
    if (!await confirmDelete(
      context,
      'Eliminar tarea',
      'Se retirará «${widget.task!.title}» de la agenda${widget.classroom == null ? '' : ' de toda el aula'}.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await state.repository.deleteTask(
        widget.student.username,
        widget.task!,
        classroom: widget.classroom,
      );
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final staff = state.user!.role == UserRole.staff;
    final locked = busy || savedDates.isNotEmpty;
    return PageShell(
      title: widget.task == null ? 'Crear tarea' : 'Modificar tarea',
      subtitle: widget.classroom == null
          ? 'Para ${widget.student.displayName}'
          : 'Para toda el aula: ${widget.classroom}',
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!state.repository.supportsTaskContent)
              const Notice(
                'El servidor admite el título, la fecha, la hora y la duración. El guardado de pasos e imágenes requiere la ampliación de la API.',
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    ContentPicture(
                      bytes: image,
                      icon: taskIcon(title.text),
                      size: 100,
                    ),
                    IconButton(
                      tooltip: 'Elegir imagen de la tarea',
                      onPressed: locked
                          ? null
                          : () async {
                              try {
                                final value = await pickPicture();
                                if (mounted && value != null) {
                                  setState(() => image = value);
                                }
                              } on Object catch (e) {
                                if (mounted) {
                                  setState(() => error = e.toString());
                                }
                              }
                            },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: TextFormField(
                    controller: title,
                    enabled: !locked,
                    maxLength: 100,
                    validator: requiredText,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la tarea *',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 20,
              runSpacing: 18,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: locked ? null : chooseDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy').format(date)}',
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: duration,
                    enabled: !locked,
                    keyboardType: TextInputType.number,
                    validator: positiveInteger,
                    decoration: const InputDecoration(
                      labelText: 'Duración (minutos) *',
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: locked
                      ? null
                      : () async {
                          final value = await showTimePicker(
                            context: context,
                            initialTime:
                                hour ??
                                TimeOfDay(hour: staff ? 9 : 17, minute: 0),
                            builder: (context, child) => MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            ),
                          );
                          if (value != null && mounted) {
                            setState(() => hour = value);
                          }
                        },
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    hourValue == null
                        ? 'Elegir hora de inicio'
                        : 'Inicio: ${hourValue!.substring(0, 5)}',
                  ),
                ),
                if (!staff && hour != null)
                  TextButton(
                    onPressed: locked
                        ? null
                        : () => setState(() => hour = null),
                    child: const Text('Sin hora fija'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              staff
                  ? 'La tarea debe quedar entre las 09:00 y las 15:00.'
                  : 'La tarea debe quedar fuera del horario escolar (09:00–15:00). También puede no tener hora fija.',
            ),
            if (widget.task == null) ...[
              const SizedBox(height: 24),
              const Text(
                'Días de esta semana *',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 1; i <= 7; i++)
                    FilterChip(
                      label: Text(
                        const [
                          'Lunes',
                          'Martes',
                          'Miércoles',
                          'Jueves',
                          'Viernes',
                          'Sábado',
                          'Domingo',
                        ][i - 1],
                      ),
                      selected: weekdays.contains(i),
                      onSelected: locked
                          ? null
                          : (v) => setState(
                              () => v ? weekdays.add(i) : weekdays.remove(i),
                            ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 26),
            const Text(
              'Pasos de la tarea',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < steps.length; i++)
              ActionTile(
                title: '${i + 1}. ${steps[i].title}',
                subtitle:
                    '${steps[i].duration} min · ${steps[i].required ? 'Obligatorio' : 'Guiado'}',
                icon: Icons.format_list_numbered,
                onTap: locked ? null : () => addStep(i),
                trailing: IconButton(
                  tooltip: 'Quitar paso',
                  onPressed: locked
                      ? null
                      : () => setState(() {
                          steps.removeAt(i);
                          for (var j = 0; j < steps.length; j++) {
                            steps[j] = steps[j].atIndex(j);
                          }
                        }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            OutlinedButton.icon(
              onPressed: locked ? null : () => addStep(),
              icon: const Icon(Icons.add),
              label: const Text('Añadir paso'),
            ),
            if (error != null) Notice(error!, error: true),
            FormActions(
              busy: busy,
              onSave: save,
              label: savedDates.isEmpty
                  ? 'Guardar tarea'
                  : 'Reintentar días pendientes',
            ),
            if (widget.task != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: OutlinedButton.icon(
                  onPressed: busy ? null : remove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar tarea'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class StepEditorScreen extends StatefulWidget {
  const StepEditorScreen({
    super.key,
    required this.taskTitle,
    required this.nextIndex,
    this.step,
  });
  final String taskTitle;
  final int nextIndex;
  final TaskStep? step;
  @override
  State<StepEditorScreen> createState() => _StepEditorScreenState();
}

class _StepEditorScreenState extends State<StepEditorScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final duration = TextEditingController();
  final order = TextEditingController();
  Uint8List? image;
  bool required = true;
  String? error;
  @override
  void initState() {
    super.initState();
    final step = widget.step;
    title.text = step?.title ?? '';
    description.text = step?.description ?? '';
    duration.text = '${step?.duration ?? 1}';
    order.text = step == null ? '' : '${step.index + 1}';
    image = step?.image;
    required = step?.required ?? true;
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    duration.dispose();
    order.dispose();
    super.dispose();
  }

  void save() {
    if (!form.currentState!.validate()) return;
    Navigator.pop(
      context,
      TaskStep(
        id: widget.step?.id ?? -DateTime.now().microsecondsSinceEpoch,
        title: title.text.trim(),
        description: description.text.trim(),
        index: order.text.isEmpty
            ? widget.nextIndex
            : int.parse(order.text) - 1,
        duration: int.parse(duration.text),
        required: required,
        image: image,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: widget.step == null ? 'Crear paso' : 'Modificar paso',
    subtitle: 'Paso para la tarea: ${widget.taskTitle}',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ContentPicture(
              bytes: image,
              icon: Icons.image_outlined,
              size: 150,
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                try {
                  final value = await pickPicture();
                  if (mounted && value != null) setState(() => image = value);
                } on Object catch (e) {
                  if (mounted) setState(() => error = e.toString());
                }
              },
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Elegir imagen'),
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: title,
            maxLength: 100,
            validator: requiredText,
            decoration: const InputDecoration(labelText: 'Nombre del paso *'),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 20,
            runSpacing: 18,
            children: [
              SizedBox(
                width: 260,
                child: TextFormField(
                  controller: duration,
                  validator: positiveInteger,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duración (minutos) *',
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextFormField(
                  controller: order,
                  validator: (v) => v!.isEmpty ? null : positiveInteger(v),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Orden (opcional)',
                    helperText: 'Vacío: añadir al final',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: description,
            minLines: 5,
            maxLines: 10,
            maxLength: 5000,
            validator: requiredText,
            decoration: const InputDecoration(
              labelText: 'Descripción *',
              helperText: 'Usa frases cortas y una instrucción por línea.',
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Paso obligatorio'),
            subtitle: const Text(
              'Debe completarse antes de terminar la tarea.',
            ),
            value: required,
            onChanged: (v) => setState(() => required = v),
          ),
          if (error != null) Notice(error!, error: true),
          FormActions(busy: false, onSave: save, label: 'Guardar paso'),
        ],
      ),
    ),
  );
}
