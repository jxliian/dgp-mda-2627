import 'package:flutter/material.dart';
import '../../screens/settings_screen.dart';
import '../../state/app_state.dart';
import '../routes.dart';
import 'bar_action.dart';
import 'icon_action.dart';

/// Acciones de la sesión iniciada: inicio, ajustes y salir.
///
/// Viven en la barra superior, junto a las acciones de cada pantalla, para que
/// no haya una segunda barra abajo repitiendo la navegación.
class SessionActions extends StatefulWidget {
  const SessionActions({super.key, this.compact = false});

  /// En pantalla estrecha las tres acciones se quedan en iconos con nombre
  /// accesible: con la letra muy ampliada, tres botones con texto ocupaban
  /// media pantalla de alto.
  final bool compact;

  @override
  State<SessionActions> createState() => _SessionActionsState();
}

class _SessionActionsState extends State<SessionActions> {
  bool saliendo = false;

  Future<void> cerrarSesion() async {
    setState(() => saliendo = true);
    try {
      await AppScope.of(context).logout();
    } on Object catch (e) {
      if (mounted) {
        setState(() => saliendo = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se ha podido salir: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: widget.compact ? _iconos(context) : _botones(context),
  );

  List<Widget> _iconos(BuildContext context) => [
    IconAction(
      icon: Icons.home_outlined,
      label: 'Inicio',
      onPressed: () => goHome(context),
    ),
    if (AppScope.of(context).canEditOwnSettings)
      IconAction(
        icon: Icons.settings_outlined,
        label: 'Ajustes',
        onPressed: () => openPage(context, const SettingsScreen()),
      ),
    IconAction(
      icon: Icons.logout,
      label: 'Salir',
      onPressed: saliendo ? null : cerrarSesion,
    ),
  ];

  List<Widget> _botones(BuildContext context) => [
    BarAction(
      icon: Icons.home_outlined,
      label: 'Inicio',
      onPressed: () => goHome(context),
    ),
    if (AppScope.of(context).canEditOwnSettings)
      BarAction(
        icon: Icons.settings_outlined,
        label: 'Ajustes',
        onPressed: () => openPage(context, const SettingsScreen()),
      ),
    BarAction(
      icon: Icons.logout,
      label: saliendo ? 'Saliendo…' : 'Salir',
      onPressed: saliendo ? null : cerrarSesion,
    ),
  ];
}
