import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'class_students_screen.dart';
import 'staff_students_screen.dart';

/// Inicio del personal del centro: sus aulas y el acceso a sus alumnos.
class StaffClassesScreen extends StatefulWidget {
  const StaffClassesScreen({super.key});

  @override
  State<StaffClassesScreen> createState() => _StaffClassesScreenState();
}

class _StaffClassesScreenState extends State<StaffClassesScreen> {
  String busqueda = '';

  List<Classroom> _filtrar(List<Classroom> aulas) => aulas
      .where((aula) => aula.name.toLowerCase().contains(busqueda))
      .toList();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PageShell(
      title: 'Mis aulas',
      subtitle: 'Personal del centro · ${state.user!.displayName}',
      footer: const AppFooter(),
      child: Column(
        children: [
          FilledButton.icon(
            onPressed: () => openPage(context, const StaffStudentsScreen()),
            icon: const Icon(Icons.groups_2_outlined),
            label: const Text('Ver todos mis alumnos'),
          ),
          const SizedBox(height: 24),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Buscar un aula',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (valor) =>
                setState(() => busqueda = valor.toLowerCase()),
          ),
          const SizedBox(height: 24),
          LoadPanel<List<Classroom>>(
            load: state.repository.classes,
            builder: (aulas) => PagedItems<Classroom>(
              items: _filtrar(aulas),
              empty: 'No hay aulas asignadas que coincidan con la búsqueda.',
              builder: _ficha,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ficha(Classroom aula) => ActionTile(
    title: aula.name,
    subtitle: 'Alumnos y tareas del aula',
    icon: Icons.school_outlined,
    badges: [
      const StatusBadge('Aula', tone: BadgeTone.main, icon: Icons.groups_outlined),
      StatusBadge(
        '${aula.students.length} alumnos',
        icon: Icons.person_outline,
      ),
    ],
    onTap: () => openPage(context, ClassStudentsScreen(className: aula.name)),
  );
}
