import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'models/domain.dart';
import 'screens/admin_screen.dart';
import 'screens/agenda_screen.dart';
import 'screens/staff_classes_screen.dart';
import 'screens/staff_students_screen.dart';
import 'screens/welcome_screen.dart';
import 'state/app_state.dart';
import 'ui/ui.dart';

/// Aplicación Autovida. La pantalla de inicio depende de quién haya entrado.
class AutovidaApp extends StatefulWidget {
  const AutovidaApp({super.key, this.state});

  /// Estado inyectado en las pruebas; en producción se crea aquí.
  final AppState? state;

  @override
  State<AutovidaApp> createState() => _AutovidaAppState();
}

class _AutovidaAppState extends State<AutovidaApp> {
  late final AppState state;

  bool get _estadoPropio => widget.state == null;

  @override
  void initState() {
    super.initState();
    state = widget.state ?? AppState();
    if (_estadoPropio && const bool.fromEnvironment('DEMO')) {
      state.setDemo(true);
    }
  }

  @override
  void dispose() {
    if (_estadoPropio) state.dispose();
    super.dispose();
  }

  /// El alumno puede agrandar la letra desde sus ajustes; se multiplica por el
  /// tamaño que ya tenga configurado el sistema operativo.
  Widget _conTamanoDeLetra(BuildContext context, Widget? child) {
    final media = MediaQuery.of(context);
    final factorDelPerfil = state.student
        ? (state.access.number('fontsize') / 16).clamp(1.0, 2.5)
        : 1.0;
    return MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(
          media.textScaler.scale(1) * factorDelPerfil,
        ),
      ),
      child: child!,
    );
  }

  Widget get _inicio => switch (state.user?.role) {
    // La portada pregunta primero qué tipo de usuario entra.
    null => const WelcomeScreen(),
    UserRole.student => AgendaScreen(student: state.user!),
    UserRole.staff => const StaffClassesScreen(),
    UserRole.parent => const FamilyStudentsScreen(),
    UserRole.admin => const AdminScreen(),
  };

  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: AnimatedBuilder(
      animation: state,
      builder: (context, _) => MaterialApp(
        // Al cerrar sesión se descarta toda la pila de pantallas anterior.
        key: ValueKey(state.sessionVersion),
        title: 'Autovida',
        debugShowCheckedModeBanner: false,
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: appTheme(state.access, student: state.student),
        builder: _conTamanoDeLetra,
        home: _inicio,
      ),
    ),
  );
}
