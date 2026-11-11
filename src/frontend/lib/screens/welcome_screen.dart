import 'package:flutter/material.dart';
import '../ui/ui.dart';
import 'login_screen.dart';
import 'student_classes_screen.dart';

/// Portada: la primera pregunta es qué tipo de usuario entra.
///
/// Sigue el boceto del centro: dos fichas grandes, alumno y profesorado o
/// tutor, y debajo el acceso de administración.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  /// Las entradas llenan la pantalla: son lo único que hay que decidir aquí,
  /// y el alumnado las encuentra antes cuanto más grandes sean.
  static const _alturaDeLaEntrada = 240.0;

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
            const SizedBox(height: 28),
            // Dos entradas, lo más grandes posible: el alumnado por un lado
            // y, por otro, quien entra con credenciales (personal, familias y
            // administración, que comparten pantalla de acceso).
            ActionTile(
              height: _alturaDeLaEntrada,
              title: 'Soy alumno',
              subtitle: 'Busca tu clase y tu foto',
              icon: Icons.backpack_outlined,
              edge: Paleta.terracota,
              onTap: () => openPage(context, const StudentClassesScreen()),
            ),
            ActionTile(
              height: _alturaDeLaEntrada,
              title: 'Trabajo en el centro',
              subtitle: 'Personal, familias y administración',
              icon: Icons.supervisor_account_outlined,
              onTap: () => openPage(
                context,
                const LoginScreen(roles: LoginScreen.perfilesDelCentro),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
