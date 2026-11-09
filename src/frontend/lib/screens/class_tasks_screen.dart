import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/domain.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'task_editor_screen.dart';

/// Tareas de un aula completa: consultar, crear, modificar y eliminar
/// (SCRUM-321, 336, 337 y 338).
class ClassTasksScreen extends StatefulWidget {
  const ClassTasksScreen({super.key, required this.classroom});

  final Classroom classroom;

  @override
  State<ClassTasksScreen> createState() => _ClassTasksScreenState();
}

class _ClassTasksScreenState extends State<ClassTasksScreen> {
  int revision = 0;
  bool ocupado = false;
  String? aviso;
  String? error;

  /// Las tareas del aula se guardan a través de un alumno matriculado.
  AppUser? get _alumnoDeReferencia => widget.classroom.students.firstOrNull;

  Future<void> editar([AgendaTask? tarea]) async {
    final alumno = _alumnoDeReferencia;
    if (alumno == null) {
      setState(() => error = 'Matricula al menos un alumno antes de asignar tareas.');
      return;
    }
    final guardada = await openPage<bool>(
      context,
      TaskEditorScreen(
        student: alumno,
        date: tarea?.date ?? DateTime.now(),
        classroom: widget.classroom.name,
        task: tarea,
      ),
    );
    if (guardada == true && mounted) {
      setState(() {
        revision++;
        aviso = 'Tarea del aula guardada.';
      });
    }
  }

  Future<void> eliminar(AgendaTask tarea) async {
    final confirmado = await confirmDelete(
      context,
      'Eliminar tarea del aula',
      'Se retirará «${tarea.title}» de las agendas de esta aula.',
    );
    if (!confirmado || !mounted) return;
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      await AppScope.of(context).repository.deleteTask(
        _alumnoDeReferencia?.username ?? '',
        tarea,
        classroom: widget.classroom.name,
      );
      if (mounted) {
        setState(() {
          revision++;
          aviso = 'Tarea del aula eliminada.';
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Tareas de ${widget.classroom.name}',
    subtitle: 'Se asignan a todos los alumnos del aula',
    footer: const AppFooter(),
    child: Column(
      children: [
        if (error != null) Notice(error!, error: true),
        if (aviso != null) Notice(aviso!),
        LoadPanel<List<AgendaTask>>(
          key: ValueKey(revision),
          load: () =>
              AppScope.of(context).repository.classTasks(widget.classroom.name),
          builder: (tareas) => PagedItems<AgendaTask>(
            items: tareas,
            empty: 'Todavía no hay tareas de aula.',
            builder: _ficha,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: ocupado ? null : () => editar(),
          icon: const Icon(Icons.add),
          label: const Text('Crear tarea para toda el aula'),
        ),
      ],
    ),
  );

  Widget _ficha(AgendaTask tarea) => ActionTile(
    title: tarea.title,
    subtitle:
        '${tarea.startHour?.substring(0, 5) ?? 'Sin hora fija'} · '
        '${tarea.duration} min · Toca para modificarla',
    icon: taskIcon(tarea.title),
    badges: [
      if (sameDay(tarea.date, DateTime.now()))
        const StatusBadge('Hoy', tone: BadgeTone.attention, icon: Icons.today_outlined),
      StatusBadge(
        DateFormat('d MMM', 'es').format(tarea.date),
        tone: BadgeTone.main,
        icon: Icons.event_outlined,
      ),
    ],
    onTap: ocupado ? null : () => editar(tarea),
    trailing: IconAction(
      icon: Icons.delete_outline,
      label: 'Eliminar la tarea ${tarea.title}',
      onPressed: ocupado ? null : () => eliminar(tarea),
    ),
  );
}
