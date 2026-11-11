import 'package:autovida/app.dart';
import 'package:autovida/models/domain.dart';
import 'package:autovida/services/demo_repository.dart';
import 'package:autovida/state/app_state.dart';
import 'package:autovida/ui/widgets/action_tile.dart';
import 'package:autovida/ui/widgets/student_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppState> _open(
  WidgetTester tester,
  Size size, {
  DemoRepository? repository,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = repository ?? DemoRepository();
  await repo.login('lucia', '1234', UserRole.staff);
  final state = AppState(repository: repo);
  await tester.pumpWidget(AutovidaApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(const SizedBox.shrink());
  state.dispose();
}

void main() {
  for (final size in [const Size(1280, 900), const Size(390, 844)]) {
    testWidgets('staff student search and arrows work at $size', (
      tester,
    ) async {
      final state = await _open(tester, size);
      await _tap(tester, find.text('Ver todos mis alumnos'));
      expect(find.text('Pablo García'), findsOneWidget);
      expect(find.text('Sofía García'), findsNothing);
      expect(find.text('Página 1 de 3'), findsOneWidget);
      if (size.width > 620) {
        final card = tester.getRect(
          find.widgetWithText(ActionTile, 'Pablo García'),
        );
        expect(
          tester.getRect(find.byTooltip('Página anterior')).right,
          lessThan(card.left),
        );
        expect(
          tester.getRect(find.byTooltip('Página siguiente')).left,
          greaterThan(card.right),
        );
      }

      await _tap(tester, find.byTooltip('Página siguiente'));
      expect(find.text('Página 2 de 3'), findsOneWidget);
      expect(find.text('Sofía García'), findsOneWidget);
      expect(find.text('Pablo García'), findsNothing);
      final search = find.widgetWithText(
        TextField,
        'Buscar alumno por nombre o usuario',
      );
      await tester.enterText(search, ' SOFIA ');
      await tester.pumpAndSettle();
      expect(find.text('Sofía García'), findsOneWidget);
      expect(find.text('Diego García'), findsNothing);
      expect(find.byTooltip('Página siguiente'), findsNothing);

      await tester.enterText(search, 'no-existe');
      await tester.pumpAndSettle();
      expect(find.textContaining('Ningún alumno coincide'), findsOneWidget);
      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      expect(find.text('Página 1 de 3'), findsOneWidget);
      await _tap(tester, find.byTooltip('Página siguiente'));
      await _tap(tester, find.byTooltip('Página anterior'));
      expect(find.text('Página 1 de 3'), findsOneWidget);

      await tester.enterText(search, 'pablo');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Pablo García'));
      expect(find.text('Preparar la mochila'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _close(tester, state);
    });
  }

  testWidgets(
    'staff only manages existing pupils and refreshes totals after removal',
    (tester) async {
      final state = await _open(tester, const Size(1280, 1000));
      await _tap(tester, find.text('Aula de la autonomía'));
      await _tap(tester, find.text('Gestionar matrículas'));
      expect(find.byType(StudentPicker), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Matricular por usuario'), findsNothing);
      expect(find.text('Alumnos matriculados'), findsOneWidget);
      await expectLater(
        state.repository.enroll('Aula de la autonomía', 'hugo'),
        throwsA(isA<Exception>()),
      );
      await _tap(tester, find.byTooltip('Retirar a Pablo García del aula'));
      await _tap(tester, find.text('Eliminar').last);
      expect(find.text('Total: 3 alumnos'), findsOneWidget);
      await _tap(tester, find.text('Volver'));
      expect(find.text('3 alumnos'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _close(tester, state);
    },
  );
}
