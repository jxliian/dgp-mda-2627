import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../ui/ui.dart';
import 'agenda_screen.dart';

/// Alumnos con foto en lista o rejilla. Al pulsar uno se abre su agenda.
class StudentGrid extends StatelessWidget {
  const StudentGrid({
    super.key,
    required this.students,
    this.onReturn,
    this.empty = 'No hay alumnos asociados a esta cuenta.',
    this.grid = true,
    this.pageSize = 8,
  });

  final List<AppUser> students;
  final bool grid;
  final int pageSize;

  /// Se avisa al volver de la agenda, por si la pantalla debe recargarse.
  final VoidCallback? onReturn;
  final String empty;

  @override
  Widget build(BuildContext context) => PagedItems<AppUser>(
    items: students,
    pageSize: pageSize,
    grid: grid,
    empty: empty,
    builder: (alumno) => ActionTile(
      title: alumno.displayName,
      subtitle: grid
          ? 'Consultar su agenda'
          : '${alumno.username} · Consultar su agenda',
      icon: Icons.person_outline,
      vertical: grid,
      edge: Paleta.terracota,
      leading: UserAvatar(user: alumno, size: grid ? 150 : 64),
      onTap: () async {
        await openPage(context, AgendaScreen(student: alumno));
        onReturn?.call();
      },
    ),
  );
}
