import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'login_screen.dart';

/// Entrada del alumno: elige su aula y después su foto.
///
/// El directorio de fotos es una función opcional del servidor. Si no la
/// ofrece, esta pantalla no deja al alumno en un error: le explica la
/// situación y le ofrece entrar escribiendo su usuario.
class StudentClassesScreen extends StatelessWidget {
  const StudentClassesScreen({super.key});

  @override
  Widget build(BuildContext context) => PageShell(
    title: '¿A qué clase perteneces?',
    subtitle: 'Busca el nombre de tu aula.',
    child: LoadPanel<List<Classroom>>(
      load: () => _aulas(context),
      builder: (aulas) => aulas.isEmpty
          ? const _EntrarConUsuario(motivo: _sinDirectorio)
          : PagedItems<Classroom>(
              items: aulas,
              empty: 'Todavía no hay aulas disponibles.',
              builder: (aula) => _ficha(context, aula),
            ),
    ),
  );

  /// Devuelve la lista vacía cuando el servidor no tiene directorio, para
  /// poder ofrecer la alternativa en lugar de un mensaje de error.
  Future<List<Classroom>> _aulas(BuildContext context) async {
    try {
      return await AppScope.of(context).repository.directory();
    } on Object {
      return const [];
    }
  }

  Widget _ficha(BuildContext context, Classroom aula) => ActionTile(
    title: aula.name,
    icon: Icons.school_outlined,
    badges: const [StatusBadge('Aula', tone: BadgeTone.main)],
    onTap: () => openPage(context, StudentSelectionScreen(classroom: aula)),
  );

  static const _sinDirectorio =
      'Este servidor no muestra las fotos de las aulas. Puedes entrar '
      'escribiendo tu usuario y tu contraseña.';
}

/// Rejilla de fotos de un aula: el alumno se reconoce y pasa a su contraseña.
class StudentSelectionScreen extends StatelessWidget {
  const StudentSelectionScreen({super.key, required this.classroom});

  final Classroom classroom;

  @override
  Widget build(BuildContext context) => PageShell(
    title: classroom.name,
    subtitle: 'Busca tu foto',
    child: PagedItems<AppUser>(
      items: classroom.students,
      grid: true,
      pageSize: 8,
      empty: 'No hay alumnos en esta aula.',
      builder: (alumno) => ActionTile(
        title: alumno.displayName,
        icon: Icons.person_outline,
        vertical: true,
        edge: Paleta.terracota,
        leading: UserAvatar(user: alumno, size: 110),
        onTap: () => openPage(context, LoginScreen(student: alumno)),
      ),
    ),
  );
}

/// Alternativa cuando no hay directorio de fotos.
class _EntrarConUsuario extends StatelessWidget {
  const _EntrarConUsuario({required this.motivo});

  final String motivo;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Notice(motivo),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => openPage(
          context,
          const LoginScreen(roles: [UserRole.student]),
        ),
        icon: const Icon(Icons.keyboard_outlined),
        label: const Text('Entrar con mi usuario'),
      ),
    ],
  );
}
