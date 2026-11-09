import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'models/domain.dart';
import 'screens/admin_screens.dart';
import 'screens/auth_screens.dart';
import 'screens/student_screens.dart';
import 'screens/supervisor_screens.dart';
import 'state/app_state.dart';
import 'ui/components.dart';

class AutovidaApp extends StatefulWidget {
  const AutovidaApp({super.key, this.state});
  final AppState? state;
  @override
  State<AutovidaApp> createState() => _AutovidaAppState();
}

class _AutovidaAppState extends State<AutovidaApp> {
  late final AppState state;
  @override
  void initState() {
    super.initState();
    state = widget.state ?? AppState();
    if (widget.state == null && const bool.fromEnvironment('DEMO')) {
      state.setDemo(true);
    }
  }

  @override
  void dispose() {
    if (widget.state == null) state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: AnimatedBuilder(
      animation: state,
      builder: (context, _) => MaterialApp(
        key: ValueKey(state.sessionVersion),
        title: 'AUTOVIDA',
        debugShowCheckedModeBanner: false,
        locale: const Locale('es', 'ES'),
        supportedLocales: const [Locale('es', 'ES')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: appTheme(state.access, student: state.student),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          final profileScale = state.student
              ? (state.access.number('fontsize') / 16).clamp(1.0, 2.5)
              : 1.0;
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(
                media.textScaler.scale(1) * profileScale,
              ),
            ),
            child: child!,
          );
        },
        home: switch (state.user?.role) {
          null => const WelcomeScreen(),
          UserRole.student => AgendaScreen(student: state.user!),
          UserRole.staff => const StaffClassesScreen(),
          UserRole.parent => const FamilyStudentsScreen(),
          UserRole.admin => const AdminScreen(),
        },
      ),
    ),
  );
}
