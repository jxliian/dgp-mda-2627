import 'package:autovida/models/domain.dart';
import 'package:autovida/screens/task_detail_screen.dart';
import 'package:autovida/services/demo_repository.dart';
import 'package:autovida/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Una tarea con varios pasos se abre en el primero y la lista completa se
/// queda detrás de un botón.
void main() {
  AgendaTask tareaConPasos(String creador) => AgendaTask(
    id: 900,
    title: 'Poner la mesa',
    date: DateTime.now(),
    duration: 15,
    creator: creador,
    startHour: '13:00:00',
    steps: [
      TaskStep(
        id: 1,
        title: 'Saca los platos',
        description: 'Coge tres platos del armario.',
        index: 0,
      ),
      TaskStep(
        id: 2,
        title: 'Pon los cubiertos',
        description: 'Tenedor a la izquierda, cuchillo a la derecha.',
        index: 1,
      ),
      TaskStep(
        id: 3,
        title: 'Pon los vasos',
        description: 'Un vaso para cada sitio.',
        index: 2,
      ),
    ],
  );

  Future<AppState> abrir(WidgetTester tester, AgendaTask tarea) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = DemoRepository();
    await repo.login('pablo', '1234', UserRole.student);
    final state = AppState(repository: repo);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          locale: const Locale('es', 'ES'),
          supportedLocales: const [Locale('es', 'ES')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: TaskDetailScreen(student: repo.currentUser!, task: tarea),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('se entra por el primer paso y la lista está detrás del botón', (
    tester,
  ) async {
    final state = await abrir(tester, tareaConPasos('lucia'));

    expect(find.textContaining('Paso 1 de 3'), findsOneWidget);
    expect(find.text('Coge tres platos del armario.'), findsOneWidget);
    // Los demás pasos no se enseñan de entrada.
    expect(find.textContaining('Tenedor a la izquierda'), findsNothing);
    expect(find.text('Ver los pasos'), findsOneWidget);

    await tester.tap(find.byTooltip('Paso siguiente'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
    expect(find.textContaining('Tenedor a la izquierda'), findsOneWidget);

    await tester.tap(find.text('Ver los pasos'));
    await tester.pumpAndSettle();
    expect(find.text('Pasos de la tarea'), findsOneWidget);
    await tester.tap(find.text('Paso 3: Pon los vasos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paso 3 de 3'), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('la insignia dice quién ha puesto la tarea', (tester) async {
    var state = await abrir(tester, tareaConPasos('lucia'));
    expect(find.text('Creada por el profesor'), findsOneWidget);
    expect(find.text('Hoy'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();

    state = await abrir(tester, tareaConPasos('pablo'));
    expect(find.text('Creada por mí'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
