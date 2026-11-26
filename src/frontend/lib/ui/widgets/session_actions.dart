import 'package:flutter/material.dart';
import '../../screens/settings_screen.dart';
import '../../state/app_state.dart';
import '../routes.dart';
import '../theme.dart';
import 'bar_action.dart';
import 'icon_action.dart';
import 'user_avatar.dart';

/// Acciones de la sesión iniciada: inicio y salir.
///
/// Viven en la barra superior, junto a las acciones de cada pantalla, para que
/// no haya una segunda barra abajo repitiendo la navegación.
class SessionActions extends StatefulWidget {
  const SessionActions({super.key, this.compact = false});

  /// En pantalla estrecha las acciones se quedan en iconos con nombre
  /// accesible: con la letra muy ampliada, los botones con texto ocupaban
  /// demasiado alto.
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
  Widget build(BuildContext context) {
    if (AppScope.of(context).user == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: widget.compact ? _iconos(context) : _botones(context),
    );
  }

  List<Widget> _iconos(BuildContext context) => [
    IconAction(
      icon: Icons.home_outlined,
      label: 'Inicio',
      onPressed: () => goHome(context),
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
    BarAction(
      icon: Icons.logout,
      label: saliendo ? 'Saliendo…' : 'Salir',
      onPressed: saliendo ? null : cerrarSesion,
    ),
  ];
}

/// Foto del usuario conectado en la barra superior; cuando tiene permiso,
/// funciona como botón para abrir sus ajustes.
class SessionAvatar extends StatelessWidget {
  const SessionAvatar({super.key});

  static const _tamano = Medidas.alturaBotonMenor - Medidas.trazoGrueso * 2;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    if (user == null) return const SizedBox.shrink();
    final avatar = UserAvatar(user: user, size: _tamano);
    if (!state.canEditOwnSettings) return avatar;
    final radio = BorderRadius.circular(Medidas.radioTarjeta);
    return Tooltip(
      message: 'Ajustes',
      child: Semantics(
        button: true,
        label: 'Ajustes',
        child: Stack(
          children: [
            ExcludeSemantics(child: avatar),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => openPage(context, const SettingsScreen()),
                  borderRadius: radio,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
