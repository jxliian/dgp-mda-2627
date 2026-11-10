import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/domain.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';

/// Selector de día de la semana, con fichas grandes y nombres completos.
class DaysScreen extends StatefulWidget {
  const DaysScreen({super.key, required this.selected});

  final DateTime selected;

  @override
  State<DaysScreen> createState() => _DaysScreenState();
}

class _DaysScreenState extends State<DaysScreen> {
  late DateTime lunes;

  @override
  void initState() {
    super.initState();
    lunes = widget.selected.subtract(Duration(days: widget.selected.weekday - 1));
  }

  void cambiarSemana(int dias) =>
      setState(() => lunes = lunes.add(Duration(days: dias)));

  /// El alumno puede tener limitado cuántos días ve de una vez.
  int get diasVisibles {
    final state = AppScope.of(context);
    return state.student ? state.access.number('ndays_visible').clamp(1, 7) : 7;
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Elige un día',
    subtitle: 'Semana del ${DateFormat('d MMMM', 'es').format(lunes)}',
    footer: const AppFooter(),
    child: Column(
      children: [
        const SizedBox(height: 16),
        Wrap(
          spacing: 18,
          runSpacing: 18,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < diasVisibles; i++)
              SizedBox(width: 210, child: _ficha(lunes.add(Duration(days: i)))),
          ],
        ),
        const SizedBox(height: 30),
        _navegacionDeSemana(),
      ],
    ),
  );

  Widget _ficha(DateTime dia) {
    final esHoy = sameDay(dia, DateTime.now());
    return ActionTile(
      title: DateFormat('EEEE', 'es').format(dia),
      subtitle: DateFormat('d MMM', 'es').format(dia),
      icon: Icons.today_outlined,
      vertical: true,
      edge: esHoy ? Paleta.ambar : Paleta.bosque,
      badges: esHoy
          ? const [StatusBadge('Hoy', tone: BadgeTone.attention)]
          : const [],
      onTap: () => Navigator.pop(context, dia),
    );
  }

  Widget _navegacionDeSemana() => Wrap(
    spacing: 24,
    runSpacing: 14,
    alignment: WrapAlignment.center,
    children: [
      OutlinedButton.icon(
        onPressed: () => cambiarSemana(-7),
        icon: const Icon(Icons.chevron_left),
        label: const Text('Semana anterior'),
      ),
      OutlinedButton(
        onPressed: () => Navigator.pop(context, DateTime.now()),
        child: const Text('Hoy'),
      ),
      OutlinedButton.icon(
        onPressed: () => cambiarSemana(7),
        icon: const Icon(Icons.chevron_right),
        label: const Text('Semana siguiente'),
      ),
    ],
  );
}
