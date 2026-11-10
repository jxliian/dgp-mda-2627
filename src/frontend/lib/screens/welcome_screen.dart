import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../ui/ui.dart';
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
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Column(
          children: [
            const Brand(large: true),
            const SizedBox(height: 32),
            // Las tres entradas al mismo tamaño: ninguna es secundaria.
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
            ActionTile(
              title: 'Administración',
              subtitle: 'Gestión de cuentas y aulas del centro',
              icon: Icons.admin_panel_settings_outlined,
              edge: Paleta.ambar,
              onTap: () => openPage(
                context,
                const LoginScreen(roles: [UserRole.admin]),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
