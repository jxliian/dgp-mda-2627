import 'package:flutter/material.dart';
import '../../models/domain.dart';
import 'status_badge.dart';

/// Insignias que resumen una tarea de un vistazo: de quién es y en qué estado
/// está.
///
/// No se marca el día: la agenda ya es la de un día concreto y la etiqueta
/// «Hoy» repetida en cada tarea no aportaba nada. Lo que sí hace falta saber
/// es quién puso la tarea ahí, porque no es lo mismo una que se ha puesto el
/// propio alumno que una que le manda su profesor.
List<Widget> taskBadges(
  AgendaTask task, {
  required bool own,
  bool viewerIsStudent = true,
  bool showCreator = false,
}) => [
  if (task.className != null)
    StatusBadge(
      'Aula · ${task.className}',
      tone: BadgeTone.main,
      icon: Icons.groups_outlined,
    )
  else if (own)
    StatusBadge(
      viewerIsStudent ? 'Creada por mí' : 'Creada por el alumno',
      tone: BadgeTone.warm,
      icon: Icons.push_pin_outlined,
    )
  else
    const StatusBadge(
      'Creada por el profesor',
      tone: BadgeTone.main,
      icon: Icons.school_outlined,
    ),
  if (showCreator && task.creatorRole != null)
    StatusBadge(
      'Creada por · ${switch (task.creatorRole!) {
        UserRole.staff => 'Personal',
        UserRole.parent => 'Familia',
        UserRole.student => 'Alumno',
        UserRole.admin => 'Administración',
      }}',
      icon: Icons.person_outline,
    ),
  StatusBadge(
    task.finished ? 'Completada' : 'Pendiente',
    tone: task.finished ? BadgeTone.done : BadgeTone.neutral,
    icon: task.finished
        ? Icons.check_circle_outline
        : Icons.radio_button_unchecked,
  ),
];
