import 'package:flutter/material.dart';
import '../screens/settings_screen.dart';
import '../state/app_state.dart';
import 'components.dart';

class AppFooter extends StatefulWidget {
  const AppFooter({super.key});
  @override
  State<AppFooter> createState() => _AppFooterState();
}

class _AppFooterState extends State<AppFooter> {
  bool busy = false;
  String? error;
  Future<void> logout() async {
    setState(() {
      busy = true;
      error = null;
    });
    final state = AppScope.of(context);
    try {
      await state.logout();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
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
        spacing: 30,
        runSpacing: 8,
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
          TextButton.icon(
            onPressed: busy ? null : logout,
            icon: const Icon(Icons.logout),
            label: Text(busy ? 'Saliendo…' : 'Salir'),
          ),
        ],
      ),
    ],
  );
}
