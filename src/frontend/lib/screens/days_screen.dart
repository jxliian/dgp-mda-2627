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

  static const _separacion = 14.0;
  static const _anchoMinimoFicha = 140.0;

  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Elige un día',
    subtitle: 'Semana del ${DateFormat('d MMMM', 'es').format(lunes)}',
    child: Column(
      children: [
        const SizedBox(height: 16),
        // La semana entera cabe en una fila cuando hay sitio. Con fichas de
        // ancho fijo se partía en dos o tres filas y había que desplazar para
        // ver el viernes.
        LayoutBuilder(
          builder: (context, restricciones) {
            // El mínimo no crece con la letra: siete fichas estrechas con el
            // nombre en dos líneas ocupan menos alto que cuatro anchas en dos
            // filas, que es lo que salía al escalarlo.
            const minimo = _anchoMinimoFicha;
            var columnas = diasVisibles;
            double anchoDe(int n) =>
                (restricciones.maxWidth - _separacion * (n - 1)) / n;
            while (columnas > 1 && anchoDe(columnas) < minimo) {
              columnas = (columnas / 2).ceil();
            }
            final ancho = anchoDe(columnas);
            return Wrap(
              spacing: _separacion,
              runSpacing: _separacion,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < diasVisibles; i++)
                  SizedBox(
                    width: ancho,
                    child: _ficha(lunes.add(Duration(days: i))),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
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
      onTap: () => Navigator.pop(context, dia),
    );
  }

  Widget _navegacionDeSemana() => Pantalla.letraGrande(context)
      ? Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconAction(
              icon: Icons.chevron_left,
              label: 'Semana anterior',
              onPressed: () => cambiarSemana(-7),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, DateTime.now()),
              child: const Text('Hoy'),
            ),
            IconAction(
              icon: Icons.chevron_right,
              label: 'Semana siguiente',
              onPressed: () => cambiarSemana(7),
            ),
          ],
        )
      : Wrap(
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
