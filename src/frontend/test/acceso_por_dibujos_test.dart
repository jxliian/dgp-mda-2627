import 'package:autovida/app.dart';
import 'package:autovida/services/demo_repository.dart';
import 'package:autovida/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La contraseña de dibujos son cuatro, y si falla se vacía sola.
void main() {
  Future<AppState> abrirTeclado(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(repository: DemoRepository());
    await tester.pumpWidget(AutovidaApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soy alumno'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aula de la autonomía'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pablo García'));
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> pulsar(WidgetTester tester, List<String> dibujos) async {
    for (final dibujo in dibujos) {
      await tester.ensureVisible(find.text(dibujo));
      await tester.tap(find.text(dibujo));
      await tester.pump();
    }
  }

  testWidgets('no se pueden pulsar más de cuatro dibujos', (tester) async {
    final state = await abrirTeclado(tester);
    await pulsar(tester, [
      'Corazón · 1',
      'Estrella · 2',
      'Animal · 3',
      'Flor · 4',
    ]);
    expect(
      find.bySemanticsLabel('4 de 4 dibujos introducidos'),
      findsOneWidget,
    );
    expect(find.text('Ya están tus cuatro dibujos.'), findsOneWidget);

    // El quinto dibujo ya no se puede pulsar.
    final quinto = find.widgetWithText(OutlinedButton, 'Coche · 5');
    expect(tester.widget<OutlinedButton>(quinto).onPressed, isNull);
    await pulsar(tester, ['Sol · 0']);
    expect(
      find.bySemanticsLabel('4 de 4 dibujos introducidos'),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('al equivocarse se vacían los dibujos y se puede reintentar', (
    tester,
  ) async {
    final state = await abrirTeclado(tester);
    await pulsar(tester, ['Sol · 0', 'Sol · 0', 'Sol · 0', 'Sol · 0']);
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Vuelve a pulsar tus dibujos'), findsOneWidget);
    expect(
      find.bySemanticsLabel('0 de 4 dibujos introducidos'),
      findsOneWidget,
    );
    final borrar = find.widgetWithText(
      OutlinedButton,
      'Borrar el último dibujo',
    );
    expect(tester.widget<OutlinedButton>(borrar).onPressed, isNull);

    // Y con la correcta se entra sin tener que borrar nada antes.
    await pulsar(tester, [
      'Corazón · 1',
      'Estrella · 2',
      'Animal · 3',
      'Flor · 4',
    ]);
    await tester.ensureVisible(find.text('Iniciar sesión'));
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Mis tareas'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
