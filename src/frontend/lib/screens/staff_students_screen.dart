import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/student_search.dart';
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
  String busqueda = '';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PageShell(
      title: 'Mis alumnos',
      subtitle: 'Alumnado de todas tus aulas',
      footer: const AppFooter(),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Buscar alumno por nombre o usuario',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (valor) => setState(() => busqueda = valor),
          ),
          const SizedBox(height: 16),
          LoadPanel<List<AppUser>>(
            key: ValueKey(revision),
            load: () => state.repository.linkedStudents(state.user!),
            builder: (alumnos) => StudentGrid(
              key: ValueKey(busqueda),
              students: filterStudents(alumnos, busqueda),
              grid: false,
              pageSize: 3,
              empty: alumnos.isEmpty
                  ? 'Todavía no tienes alumnos asignados.'
                  : 'Ningún alumno coincide con «${busqueda.trim()}».',
              onReturn: () => setState(() => revision++),
            ),
          ),
        ],
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
