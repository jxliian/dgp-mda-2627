import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autovida/app.dart';
import 'package:autovida/models/domain.dart';
import 'package:autovida/services/demo_repository.dart';
import 'package:autovida/state/app_state.dart';
import 'package:autovida/screens/settings_screen.dart';

void main() {
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
      expect(find.text('Explorar demostración'), findsNothing);
      expect(find.text('Conexión al servidor'), findsNothing);
      await tester.tap(find.text('Soy alumno'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aula de la autonomía'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pablo García'));
      await tester.pumpAndSettle();
      for (final label in [
        'Corazón · 1',
        'Estrella · 2',
        'Animal · 3',
        'Flor · 4',
      ]) {
        await tester.tap(find.text(label));
        await tester.pump();
      }
      await tester.ensureVisible(find.text('Entrar'));
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Mis tareas'), findsOneWidget);
      expect(find.text('Preparar la mochila'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

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
        steps: [],
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

  testWidgets(
    'opening a task starts the first step and the last confirmation returns to the agenda',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = DemoRepository();
      await repository.login('pablo', '1234', UserRole.student);
      final state = AppState(repository: repository);
      await tester.pumpWidget(AutovidaApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preparar la mochila'));
      await tester.pumpAndSettle();
      expect(find.text('Buscar la mochila'), findsOneWidget);
      expect(find.text('Empezar'), findsNothing);
      await tester.ensureVisible(find.text('He terminado · Siguiente paso'));
      await tester.tap(find.text('He terminado · Siguiente paso'));
      await tester.pumpAndSettle();
      expect(find.text('Guardar el material'), findsOneWidget);
      await tester.ensureVisible(find.text('He terminado · Siguiente paso'));
      await tester.tap(find.text('He terminado · Siguiente paso'));
      await tester.pumpAndSettle();
      expect(find.text('Cerrar la mochila'), findsOneWidget);
      await tester.ensureVisible(find.text('He terminado · Finalizar tarea'));
      await tester.tap(find.text('He terminado · Finalizar tarea'));
      await tester.pumpAndSettle();
      expect(find.text('Mis tareas'), findsOneWidget);
      final task = (await repository.agenda(
        'pablo',
        DateTime.now(),
      )).firstWhere((t) => t.title == 'Preparar la mochila');
      expect(task.finished, true);
      expect(task.steps.every((s) => s.finished), true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets(
    'student settings use named palettes and cannot change the password',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repository = DemoRepository();
      await repository.login('pablo', '1234', UserRole.student);
      final state = AppState(repository: repository);
      await tester.pumpWidget(AutovidaApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Cambiar contraseña'), findsNothing);
      expect(find.byType(ColorPalette), findsNWidgets(2));
      expect(find.textContaining('#RRGGBB'), findsNothing);
      await tester.ensureVisible(find.text('Azul claro'));
      await tester.tap(find.text('Azul claro'));
      await tester.pump();
      await tester.ensureVisible(find.text('Guardar mis ajustes'));
      await tester.tap(find.text('Guardar mis ajustes'));
      await tester.pumpAndSettle();
      expect(state.access.color('main_col'), '#e3f2fd');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets(
    'account editor has the screen-flow name fields and no email for any role',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = DemoRepository();
      await repository.login('admin', '1234', UserRole.admin);
      final state = AppState(repository: repository);
      await tester.pumpWidget(AutovidaApp(state: state));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Eliminar a Administración'), findsNothing);
      expect(find.text('Tu cuenta'), findsOneWidget);
      await tester.ensureVisible(find.text('Crear usuario'));
      await tester.tap(find.text('Crear usuario'));
      await tester.pumpAndSettle();
      for (final field in [
        'Nombre *',
        'Primer apellido *',
        'Segundo apellido *',
      ]) {
        expect(find.text(field), findsOneWidget);
      }
      for (final role in [UserRole.parent, UserRole.staff, UserRole.admin]) {
        final dropdown = find.byType(DropdownButtonFormField<UserRole>);
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text(role.label).last);
        await tester.pumpAndSettle();
        expect(find.textContaining('Correo'), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
}
