import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'student_grid.dart';

/// Alumnos asignados al personal del centro, reunidos de todas sus aulas
/// (SCRUM-21).
class StaffStudentsScreen extends StatefulWidget {
  const StaffStudentsScreen({super.key});

  @override
  State<StaffStudentsScreen> createState() => _StaffStudentsScreenState();
}

class _StaffStudentsScreenState extends State<StaffStudentsScreen> {
  int revision = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PageShell(
      title: 'Mis alumnos',
      subtitle: 'Alumnado de todas tus aulas',
      footer: const AppFooter(),
      child: LoadPanel<List<AppUser>>(
        key: ValueKey(revision),
        load: () => state.repository.linkedStudents(state.user!),
        builder: (alumnos) => StudentGrid(
          students: alumnos,
          empty: 'Todavía no tienes alumnos asignados.',
          onReturn: () => setState(() => revision++),
        ),
      ),
    );
  }
}

/// Inicio de una cuenta de tutor o familia: los alumnos a su cargo.
class FamilyStudentsScreen extends StatefulWidget {
  const FamilyStudentsScreen({super.key});

  @override
  State<FamilyStudentsScreen> createState() => _FamilyStudentsScreenState();
}

class _FamilyStudentsScreenState extends State<FamilyStudentsScreen> {
  int revision = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PageShell(
      title: 'Mi familia',
      subtitle: state.user!.displayName,
      footer: const AppFooter(),
      child: LoadPanel<List<AppUser>>(
        key: ValueKey(revision),
        load: () => state.repository.linkedStudents(state.user!),
        builder: (alumnos) => StudentGrid(
          students: alumnos,
          onReturn: () => setState(() => revision++),
        ),
      ),
    );
  }
}
