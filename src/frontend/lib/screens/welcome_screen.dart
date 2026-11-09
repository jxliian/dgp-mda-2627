import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'connection_screen.dart';
import 'login_screen.dart';
import 'student_classes_screen.dart';

/// Portada: la primera pregunta es qué tipo de usuario entra.
///
/// Sigue el boceto del centro: dos fichas grandes, alumno y profesorado o
/// tutor, y debajo el acceso de administración.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => PageShell(
    title: '¿Qué tipo de usuario eres?',
    subtitle: 'Elige cómo quieres entrar.',
    footer: const _EnlacesDeApoyo(),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            const Brand(large: true),
            const SizedBox(height: 36),
            ActionTile(
              title: 'Soy alumno',
              subtitle: 'Busca tu clase y tu foto',
              icon: Icons.backpack_outlined,
              edge: Paleta.terracota,
              onTap: () => openPage(context, const StudentClassesScreen()),
            ),
            ActionTile(
              title: 'Soy tutor o personal del centro',
              subtitle: 'Entra con tu usuario y tu contraseña',
              icon: Icons.supervisor_account_outlined,
              onTap: () => openPage(
                context,
                const LoginScreen(roles: LoginScreen.perfilesDelCentro),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => openPage(
                context,
                const LoginScreen(roles: [UserRole.admin]),
              ),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Administración'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Enlaces secundarios del pie: servidor y modo de demostración.
class _EnlacesDeApoyo extends StatelessWidget {
  const _EnlacesDeApoyo();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        TextButton.icon(
          onPressed: () => openPage(context, const ConnectionScreen()),
          icon: const Icon(Icons.dns_outlined),
          label: const Text('Conexión al servidor'),
        ),
        TextButton(
          onPressed: () => state.setDemo(!state.demo),
          child: Text(
            state.demo ? 'Conectar con datos reales' : 'Ver demostración',
          ),
        ),
      ],
    );
  }
}
