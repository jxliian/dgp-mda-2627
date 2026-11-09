import 'package:flutter/material.dart';
import '../../screens/settings_screen.dart';
import '../../state/app_state.dart';
import '../routes.dart';
import 'notice.dart';

/// Barra de navegación de una sesión iniciada: inicio, ajustes y salir.
class AppFooter extends StatefulWidget {
  const AppFooter({super.key});

  @override
  State<AppFooter> createState() => _AppFooterState();
}

class _AppFooterState extends State<AppFooter> {
  bool saliendo = false;
  String? error;

  Future<void> cerrarSesion() async {
    setState(() {
      saliendo = true;
      error = null;
    });
    try {
      await AppScope.of(context).logout();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          saliendo = false;
          error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (error != null) Notice(error!, error: true),
      Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: 24,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => goHome(context),
            icon: const Icon(Icons.home_outlined),
            label: const Text('Inicio'),
          ),
          TextButton.icon(
            onPressed: () => openPage(context, const SettingsScreen()),
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Ajustes'),
          ),
          OutlinedButton.icon(
            onPressed: saliendo ? null : cerrarSesion,
            icon: const Icon(Icons.logout),
            label: Text(saliendo ? 'Saliendo…' : 'Salir'),
          ),
        ],
      ),
    ],
  );
}
