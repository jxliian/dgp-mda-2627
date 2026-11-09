import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/validation.dart';
import '../state/app_state.dart';
import '../ui/components.dart';
import '../ui/navigation.dart';
import 'student_screens.dart';
import 'task_editor_screen.dart';

class StaffClassesScreen extends StatefulWidget {
  const StaffClassesScreen({super.key});
  @override
  State<StaffClassesScreen> createState() => _StaffClassesScreenState();
}

class _StaffClassesScreenState extends State<StaffClassesScreen> {
  String search = '';
  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Mis aulas',
    subtitle: 'Personal del centro · ${AppScope.of(context).user!.displayName}',
    showBack: false,
    footer: const AppFooter(),
    child: Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar un aula',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => search = v.toLowerCase()),
        ),
        const SizedBox(height: 24),
        LoadPanel<List<Classroom>>(
          load: AppScope.of(context).repository.classes,
          builder: (classes) => PagedItems(
            items: classes
                .where((c) => c.name.toLowerCase().contains(search))
                .toList(),
            empty: 'No hay aulas asignadas que coincidan con la búsqueda.',
            builder: (c) => ActionTile(
              title: c.name,
              subtitle: '${c.students.length} alumnos',
              icon: Icons.school_outlined,
              onTap: () =>
                  openPage(context, ClassStudentsScreen(className: c.name)),
            ),
          ),
        ),
      ],
    ),
  );
}

class FamilyStudentsScreen extends StatelessWidget {
  const FamilyStudentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PageShell(
      title: 'Mi familia',
      subtitle: state.user!.displayName,
      showBack: false,
      footer: const AppFooter(),
      child: LoadPanel<List<AppUser>>(
        load: () => state.repository.linkedStudents(state.user!),
        builder: (students) => StudentGrid(students: students),
      ),
    );
  }
}

class StudentGrid extends StatelessWidget {
  const StudentGrid({super.key, required this.students, this.onChanged});
  final List<AppUser> students;
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) => PagedItems<AppUser>(
    items: students,
    pageSize: 8,
    grid: true,
    empty: 'No hay alumnos asociados a esta cuenta.',
    builder: (u) => ActionTile(
      title: u.displayName,
      subtitle: 'Consultar tareas',
      icon: Icons.person_outline,
      vertical: true,
      leading: UserAvatar(user: u, size: 105),
      onTap: () async {
        await openPage(context, AgendaScreen(student: u));
        onChanged?.call();
      },
    ),
  );
}

class ClassStudentsScreen extends StatefulWidget {
  const ClassStudentsScreen({super.key, required this.className});
  final String className;
  @override
  State<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends State<ClassStudentsScreen> {
  int revision = 0;
  String? message, error;
  final username = TextEditingController();
  bool managing = false, busy = false;
  @override
  void dispose() {
    username.dispose();
    super.dispose();
  }

  Future<void> enroll({String? remove}) async {
    if (remove == null && usernameError(username.text) != null) {
      setState(() => error = 'Escribe un nombre de usuario válido.');
      return;
    }
    final state = AppScope.of(context);
    if (remove != null) {
      final confirm = await confirmDelete(
        context,
        'Retirar alumno del aula',
        'Se retirará al alumno y sus tareas de esta aula. Su cuenta y sus tareas personales se conservarán.',
      );
      if (!confirm || !mounted) return;
    }
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      await state.repository.enroll(
        widget.className,
        remove ?? username.text.trim(),
        remove: remove != null,
      );
      if (mounted) {
        setState(() {
          revision++;
          username.clear();
          message = remove == null
              ? 'Alumno matriculado.'
              : 'Alumno retirado del aula.';
        });
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
    return PageShell(
      title: widget.className,
      subtitle: 'Alumnos del aula',
      footer: const AppFooter(),
      child: LoadPanel<Classroom>(
        key: ValueKey(revision),
        load: () => state.repository.classDetail(widget.className),
        builder: (classroom) => Column(
          children: [
            StudentGrid(students: classroom.students),
            const SizedBox(height: 24),
            Wrap(
              spacing: 20,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      openPage(context, ClassTasksScreen(classroom: classroom)),
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Tareas de toda el aula'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() => managing = !managing),
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(
                    managing ? 'Cerrar matrículas' : 'Gestionar matrículas',
                  ),
                ),
              ],
            ),
            if (managing) ...[
              const SizedBox(height: 24),
              TextField(
                controller: username,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Usuario del alumno para matricular',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : () => enroll(),
                icon: const Icon(Icons.add),
                label: const Text('Matricular alumno'),
              ),
              for (final u in classroom.students)
                ListTile(
                  title: Text(u.displayName),
                  subtitle: Text(u.username),
                  trailing: IconButton(
                    tooltip: 'Retirar a ${u.displayName} del aula',
                    onPressed: busy ? null : () => enroll(remove: u.username),
                    icon: const Icon(Icons.person_remove_outlined),
                  ),
                ),
            ],
            if (error != null) Notice(error!, error: true),
            if (message != null) Notice(message!),
          ],
        ),
      ),
    );
  }
}

class ClassTasksScreen extends StatefulWidget {
  const ClassTasksScreen({super.key, required this.classroom});
  final Classroom classroom;
  @override
  State<ClassTasksScreen> createState() => _ClassTasksScreenState();
}

class _ClassTasksScreenState extends State<ClassTasksScreen> {
  int revision = 0;
  String? error, message;
  bool busy = false;
  Future<void> edit([AgendaTask? task]) async {
    if (widget.classroom.students.isEmpty) {
      setState(
        () => error = 'Matricula al menos un alumno antes de asignar tareas.',
      );
      return;
    }
    final result = await openPage<bool>(
      context,
      TaskEditorScreen(
        student: widget.classroom.students.first,
        date: task?.date ?? DateTime.now(),
        classroom: widget.classroom.name,
        task: task,
      ),
    );
    if (result == true && mounted) {
      setState(() {
        revision++;
        message = 'Tarea del aula guardada.';
      });
    }
  }

  Future<void> remove(AgendaTask task) async {
    final state = AppScope.of(context);
    if (!await confirmDelete(
      context,
      'Eliminar tarea del aula',
      'Se retirará «${task.title}» de las agendas de esta aula.',
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
        widget.classroom.students.firstOrNull?.username ?? '',
        task,
        classroom: widget.classroom.name,
      );
      if (mounted) {
        setState(() {
          revision++;
          message = 'Tarea del aula eliminada.';
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Tareas de ${widget.classroom.name}',
    footer: const AppFooter(),
    child: Column(
      children: [
        if (error != null) Notice(error!, error: true),
        if (message != null) Notice(message!),
        LoadPanel<List<AgendaTask>>(
          key: ValueKey(revision),
          load: () =>
              AppScope.of(context).repository.classTasks(widget.classroom.name),
          builder: (tasks) => PagedItems(
            items: tasks,
            empty: 'Todavía no hay tareas de aula.',
            builder: (t) => ActionTile(
              title: t.title,
              subtitle:
                  '${t.dateKey} · ${t.startHour?.substring(0, 5)} · ${t.duration} min',
              icon: taskIcon(t.title),
              onTap: busy ? null : () => edit(t),
              trailing: IconButton(
                tooltip: 'Eliminar tarea del aula',
                onPressed: busy ? null : () => remove(t),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: busy ? null : () => edit(),
          icon: const Icon(Icons.add),
          label: const Text('Crear tarea para toda el aula'),
        ),
      ],
    ),
  );
}
