import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'class_tasks_screen.dart';
import 'student_grid.dart';

/// Alumnos de un aula y gestión de sus matrículas (SCRUM-327 y SCRUM-328).
class ClassStudentsScreen extends StatefulWidget {
  const ClassStudentsScreen({super.key, required this.className});

  final String className;

  @override
  State<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends State<ClassStudentsScreen> {
  int revision = 0;
  bool gestionando = false;
  bool ocupado = false;
  String? aviso;
  String? error;

  Future<void> _retirarAlumno(String username) async {
    setState(() {
      ocupado = true;
      error = null;
      aviso = null;
    });
    try {
      await AppScope.of(
        context,
      ).repository.enroll(widget.className, username, remove: true);
      if (mounted) {
        setState(() {
          revision++;
          aviso = 'Alumno retirado del aula.';
        });
        AppScope.of(context).classroomsChanged();
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> retirar(AppUser alumno) async {
    final confirmado = await confirmDelete(
      context,
      'Retirar alumno del aula',
      'Se retirará a ${alumno.displayName} y las tareas de esta aula. '
          'Su cuenta y sus tareas personales se conservan.',
    );
    if (!confirmado || !mounted) return;
    await _retirarAlumno(alumno.username);
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: widget.className,
    subtitle: 'Alumnos del aula',
    footer: const AppFooter(),
    child: LoadPanel<Classroom>(
      key: ValueKey(revision),
      load: () => AppScope.of(context).repository.classDetail(widget.className),
      builder: (aula) => Column(
        children: [
          Text(
            'Total: ${aula.studentCount} alumnos',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          StudentGrid(
            students: aula.students,
            empty: 'Todavía no hay alumnos en esta aula.',
          ),
          const SizedBox(height: 24),
          _accionesDelAula(aula),
          if (gestionando) _gestionDeMatriculas(aula),
          if (error != null) Notice(error!, error: true),
          if (aviso != null) Notice(aviso!),
        ],
      ),
    ),
  );

  Widget _accionesDelAula(Classroom aula) => Wrap(
    spacing: 20,
    runSpacing: 12,
    alignment: WrapAlignment.center,
    children: [
      FilledButton.icon(
        onPressed: () => openPage(context, ClassTasksScreen(classroom: aula)),
        icon: const Icon(Icons.groups_outlined),
        label: const Text('Tareas de toda el aula'),
      ),
      if (AppScope.of(context).repository.canEnrollStudents)
        OutlinedButton.icon(
          onPressed: () {
            setState(() => gestionando = !gestionando);
          },
          icon: const Icon(Icons.manage_accounts_outlined),
          label: Text(
            gestionando ? 'Cerrar matrículas' : 'Gestionar matrículas',
          ),
        ),
    ],
  );

  Widget _gestionDeMatriculas(Classroom aula) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionTitle(
        'Matrículas del aula',
        hint: 'Consulta o retira alumnos ya matriculados en esta clase.',
      ),
      const SizedBox(height: 20),
      const SectionTitle('Alumnos matriculados'),
      for (final alumno in aula.students)
        ListTile(
          title: Text(alumno.displayName),
          subtitle: Text(alumno.username),
          trailing: IconAction(
            icon: Icons.person_remove_outlined,
            label: 'Retirar a ${alumno.displayName} del aula',
            onPressed: ocupado ? null : () => retirar(alumno),
          ),
        ),
    ],
  );
}
