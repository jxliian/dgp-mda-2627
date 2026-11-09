import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../ui/ui.dart';
import 'agenda_screen.dart';

/// Rejilla de alumnos con su foto. Al pulsar uno se abre su agenda.
class StudentGrid extends StatelessWidget {
  const StudentGrid({
    super.key,
    required this.students,
    this.onReturn,
    this.empty = 'No hay alumnos asociados a esta cuenta.',
  });

  final List<AppUser> students;

  /// Se avisa al volver de la agenda, por si la pantalla debe recargarse.
  final VoidCallback? onReturn;
  final String empty;

  @override
  Widget build(BuildContext context) => PagedItems<AppUser>(
    items: students,
    pageSize: 8,
    grid: true,
    empty: empty,
    builder: (alumno) => ActionTile(
      title: alumno.displayName,
      subtitle: 'Consultar su agenda',
      icon: Icons.person_outline,
      vertical: true,
      edge: Paleta.terracota,
      leading: UserAvatar(user: alumno, size: 105),
      onTap: () async {
        await openPage(context, AgendaScreen(student: alumno));
        onReturn?.call();
      },
    ),
  );
}
