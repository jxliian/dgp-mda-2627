import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autovida/app.dart';
import 'package:autovida/models/domain.dart';
import 'package:autovida/services/demo_repository.dart';
import 'package:autovida/state/app_state.dart';

void main() {
  testWidgets('the welcome screen offers the two ways in', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(repository: DemoRepository());
    await tester.pumpWidget(AutovidaApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué tipo de usuario eres?'), findsOneWidget);
    expect(find.text('Soy alumno'), findsOneWidget);
    expect(find.text('Trabajo en el centro'), findsOneWidget);

    // Personal, familias y dirección comparten pantalla de credenciales.
    await tester.tap(find.text('Trabajo en el centro'));
    await tester.pumpAndSettle();
    expect(find.text(UserRole.staff.label), findsOneWidget);
    expect(find.text(UserRole.parent.label), findsOneWidget);
    expect(find.text(UserRole.admin.label), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'lucia');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.ensureVisible(find.text('Iniciar sesión').last);
    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pumpAndSettle();
    expect(find.text('Mis aulas'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('administration enters through the same credentials screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = AppState(repository: DemoRepository());
    await tester.pumpWidget(AutovidaApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trabajo en el centro'));
    await tester.pumpAndSettle();
    // Un único acceso: dirección es un perfil más de la misma pantalla.
    await tester.tap(find.text(UserRole.admin.label));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'admin');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.ensureVisible(find.text('Iniciar sesión').last);
    await tester.tap(find.text('Iniciar sesión').last);
    await tester.pumpAndSettle();
    expect(find.text('Gestión de usuarios y aulas'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets(
    'student follows classroom, own photo, visual password and agenda',
    (tester) async {
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
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Escribir la contraseña con el teclado'), findsNothing);
      final erase = find.widgetWithText(
        OutlinedButton,
        'Borrar el último dibujo',
      );
      expect(tester.getSize(erase).height, greaterThanOrEqualTo(88));
      expect(tester.getSize(erase).width, greaterThan(900));
      await tester.tap(find.text('Sol · 0'));
      await tester.pump();
      await tester.ensureVisible(erase);
      await tester.tap(erase);
      await tester.pump();
      expect(tester.widget<OutlinedButton>(erase).onPressed, isNull);
      for (final label in [
        'Corazón · 1',
        'Estrella · 2',
        'Animal · 3',
        'Flor · 4',
      ]) {
        await tester.tap(find.text(label));
        await tester.pump();
      }
      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Mis tareas'), findsOneWidget);
      expect(find.text('Preparar la mochila'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets('sprint 1 handles a task as a unit, with no steps or timer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = DemoRepository();
    await repo.login('pablo', '1234', UserRole.student);
    // De base un alumno no crea tareas: se lo habilita quien le acompaña.
    repo.currentUser!.access.values['stud_access_task_mod'] = true;
    final state = AppState(repository: repo);
    await tester.pumpWidget(AutovidaApp(state: state));
    await tester.pumpAndSettle();

    // El detalle muestra la tarea completa, sin pasos ni cronómetro.
    await tester.tap(find.text('Preparar la mochila').first);
    await tester.pumpAndSettle();
    expect(find.text('¿Qué hay que hacer?'), findsOneWidget);
    expect(find.textContaining('Cierra la cremallera'), findsOneWidget);
    expect(find.text('Empezar'), findsNothing);
    expect(find.textContaining('Paso 1 de'), findsNothing);
    expect(find.text('He terminado la tarea'), findsOneWidget);
    await tester.tap(find.text('He terminado la tarea'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Has completado tu tarea'), findsOneWidget);
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    // El editor maneja título, descripción, fecha, hora y duración.
    await tester.ensureVisible(find.text('Añadir mi tarea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir mi tarea'));
    await tester.pumpAndSettle();
    expect(find.text('Crear tarea'), findsOneWidget);
    expect(find.text('Añadir paso'), findsNothing);
    expect(find.text('Pasos de la tarea'), findsNothing);
    expect(find.text('Descripción de la tarea'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('staff manages its classes, enrolments and group tasks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = DemoRepository();
    await repo.login('lucia', '1234', UserRole.staff);
    final state = AppState(repository: repo);
    await tester.pumpWidget(AutovidaApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aula de la autonomía'));
    await tester.pumpAndSettle();
    expect(find.text('Pablo García'), findsOneWidget);
    await tester.tap(find.text('Gestionar matrículas'));
    await tester.pumpAndSettle();
    expect(find.text('Matrículas del aula'), findsOneWidget);
    await tester.tap(find.text('Tareas de toda el aula'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear tarea para toda el aula'));
    await tester.pumpAndSettle();
    expect(find.text('Crear tarea'), findsOneWidget);
    expect(find.text('Añadir paso'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('administration opens the user and classroom editors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = DemoRepository();
    await repo.login('admin', '1234', UserRole.admin);
    final state = AppState(repository: repo);
    await tester.pumpWidget(AutovidaApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lucía Martín'));
    await tester.pumpAndSettle();
    expect(find.text('Modificar usuario'), findsOneWidget);
    await tester.ensureVisible(find.text('Gestionar asociaciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gestionar asociaciones'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Asociaciones de'), findsOneWidget);
    await tester.tap(find.text('Volver').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aulas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aula de la autonomía'));
    await tester.pumpAndSettle();
    expect(find.text('Modificar aula'), findsOneWidget);
    expect(find.text('Personal del aula'), findsOneWidget);
    expect(find.text('Alumnos del aula'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  for (final role in [
    UserRole.student,
    UserRole.parent,
    UserRole.staff,
    UserRole.admin,
  ]) {
    testWidgets('${role.name} home fits a phone with enlarged system text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = DemoRepository();
      await repo.login(
        switch (role) {
          UserRole.student => 'pablo',
          UserRole.parent => 'familia',
          UserRole.staff => 'lucia',
          UserRole.admin => 'admin',
        },
        '1234',
        role,
      );
      final state = AppState(repository: repo);
      await tester.pumpWidget(AutovidaApp(state: state));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Salir'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });
  }

  testWidgets('a student only creates tasks when it has been enabled', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = DemoRepository();
    await repo.login('pablo', '1234', UserRole.student);
    final state = AppState(repository: repo);
    await tester.pumpWidget(AutovidaApp(state: state));
    await tester.pumpAndSettle();

    // De base el permiso está apagado: no hay por dónde crear.
    expect(repo.currentUser!.access.flag('task_mod'), false);
    expect(find.text('Añadir mi tarea'), findsNothing);

    // Al habilitarlo, el botón aparece.
    repo.currentUser!.access.values['stud_access_task_mod'] = true;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(AutovidaApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('Añadir mi tarea'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  test('every accessibility support starts switched off', () {
    final ajustes = AccessSettings();
    for (final apoyo in [
      'pictograms',
      'contrast',
      'filters',
      'timebar',
      'talkback',
      'prof_mod',
      'profile_mod',
      'task_mod',
    ]) {
      expect(
        ajustes.flag(apoyo),
        false,
        reason: '$apoyo debería nacer apagado',
      );
    }
  });

  test('demo group progress stays independent between students', () async {
    final repo = DemoRepository();
    await repo.login('lucia', '1234', UserRole.staff);
    final task = await repo.saveTask(
      'pablo',
      TaskDraft(
        title: 'Trabajo común',
        date: DateTime.now(),
        duration: 10,
        startHour: '10:00:00',
        description: 'Trabajamos todos juntos en la mesa grande.',
      ),
      classroom: 'Aula de la autonomía',
    );
    await repo.logout();
    await repo.login('pablo', '1234', UserRole.student);
    await repo.progress('pablo', task, complete: true);
    await repo.logout();
    await repo.login('ana', '1234', UserRole.student);
    final other = (await repo.agenda(
      'ana',
      DateTime.now(),
    )).firstWhere((t) => t.id == task.id);
    expect(other.finished, false);
    repo.close();
  });
}
