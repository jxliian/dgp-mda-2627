import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/validation.dart';
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
  final nuevoAlumno = TextEditingController();
  int revision = 0;

  /// Alumnos que el personal puede matricular, para no tener que saberse el
  /// nombre de usuario. Se cargan una vez al abrir la gestión.
  List<AppUser>? candidatos;
  bool cargandoCandidatos = false;
  bool gestionando = false;
  bool ocupado = false;
  String? aviso;
  String? error;

  @override
  void dispose() {
    nuevoAlumno.dispose();
    super.dispose();
  }

  Future<void> _matricular({required String username, required bool retirar}) async {
    setState(() {
      ocupado = true;
      error = null;
      aviso = null;
    });
    try {
      await AppScope.of(context).repository.enroll(
        widget.className,
        username,
        remove: retirar,
      );
      if (mounted) {
        setState(() {
          revision++;
          candidatos = null; // Al matricular cambia quién sigue sin aula.
          nuevoAlumno.clear();
          aviso = retirar ? 'Alumno retirado del aula.' : 'Alumno matriculado.';
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => ocupado = false);
      if (mounted && candidatos == null && gestionando) {
        await cargarCandidatos();
      }
    }
  }

  /// Carga los alumnos que todavía no tienen aula, que son los únicos que el
  /// servidor deja matricular: al resto responde «ya pertenece a otra clase».
  Future<void> cargarCandidatos() async {
    if (candidatos != null || cargandoCandidatos) return;
    setState(() => cargandoCandidatos = true);
    final state = AppScope.of(context);
    try {
      final lista = await state.repository.studentsWithoutClass();
      if (mounted) setState(() => candidatos = lista);
    } on Object {
      // Sin listado seguimos adelante: queda el usuario escrito a mano.
      if (mounted) setState(() => candidatos = const []);
    } finally {
      if (mounted) setState(() => cargandoCandidatos = false);
    }
  }

  Future<void> apuntar() async {
    if (usernameError(nuevoAlumno.text) != null) {
      setState(() => error = 'Escribe un nombre de usuario válido.');
      return;
    }
    await _matricular(username: nuevoAlumno.text.trim(), retirar: false);
  }

  Future<void> retirar(AppUser alumno) async {
    final confirmado = await confirmDelete(
      context,
      'Retirar alumno del aula',
      'Se retirará a ${alumno.displayName} y las tareas de esta aula. '
          'Su cuenta y sus tareas personales se conservan.',
    );
    if (!confirmado || !mounted) return;
    await _matricular(username: alumno.username, retirar: true);
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
            if (gestionando) cargarCandidatos();
          },
          icon: const Icon(Icons.person_add_alt),
          label: Text(
            gestionando ? 'Cerrar matrículas' : 'Gestionar matrículas',
          ),
        ),
    ],
  );

  /// Quita de la búsqueda a quien ya está en el aula.
  List<AppUser> _sinMatricular(Classroom aula) {
    final dentro = aula.students.map((a) => a.username).toSet();
    return (candidatos ?? const <AppUser>[])
        .where((alumno) => !dentro.contains(alumno.username))
        .toList();
  }

  Widget _gestionDeMatriculas(Classroom aula) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionTitle(
        'Matrículas del aula',
        hint: 'Solo aparecen los alumnos que aún no tienen aula: cada alumno '
            'pertenece a una sola.',
      ),
      if (cargandoCandidatos)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: LinearProgressIndicator(),
        )
      else
        StudentPicker(
          students: _sinMatricular(aula),
          enabled: !ocupado,
          empty: 'Todos los alumnos que ves tienen ya un aula asignada.',
          onPick: (alumno) =>
              _matricular(username: alumno.username, retirar: false),
        ),
      const SizedBox(height: 16),
      const SectionTitle(
        'Por nombre de usuario',
        hint: 'Si el alumno no sale en la búsqueda, escribe su usuario.',
      ),
      TextField(
        controller: nuevoAlumno,
        enabled: !ocupado,
        decoration: const InputDecoration(
          labelText: 'Usuario del alumno para matricular',
        ),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: ocupado ? null : apuntar,
        icon: const Icon(Icons.add),
        label: const Text('Matricular alumno'),
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
