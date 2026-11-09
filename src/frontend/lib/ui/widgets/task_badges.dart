import 'package:flutter/material.dart';
import '../../models/domain.dart';
import 'status_badge.dart';

/// Insignias que resumen una tarea de un vistazo: cuándo es, de quién es y en
/// qué estado está.
List<Widget> taskBadges(AgendaTask task, {required bool own}) => [
  if (sameDay(task.date, DateTime.now()))
    const StatusBadge('Hoy', tone: BadgeTone.attention, icon: Icons.today_outlined),
  if (task.className != null)
    StatusBadge(
      'Aula · ${task.className}',
      tone: BadgeTone.main,
      icon: Icons.groups_outlined,
    ),
  if (own && task.className == null)
    const StatusBadge(
      'Mi tarea',
      tone: BadgeTone.warm,
      icon: Icons.push_pin_outlined,
    ),
  StatusBadge(
    task.finished ? 'Completada' : 'Pendiente',
    tone: task.finished ? BadgeTone.done : BadgeTone.neutral,
    icon: task.finished
        ? Icons.check_circle_outline
        : Icons.radio_button_unchecked,
  ),
];
