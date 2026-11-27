import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:autovida/app.dart';
import 'package:autovida/models/domain.dart';
import 'package:autovida/services/api_client.dart';
import 'package:autovida/services/demo_repository.dart';
import 'package:autovida/services/repository.dart';
import 'package:autovida/state/app_state.dart';

class _TrackingDemoRepository extends DemoRepository {
  int saveTaskCalls = 0;
  AgendaTask? lastPrevious;

  @override
  bool get isDemo => false;

  @override
  Future<AgendaTask> saveTask(
    String student,
    TaskDraft draft, {
    AgendaTask? previous,
    String? classroom,
  }) {
    saveTaskCalls++;
    lastPrevious = previous;
    return super.saveTask(
      student,
      draft,
      previous: previous,
      classroom: classroom,
    );
  }
}

void main() {
  testWidgets(
    'tutor edits a task without description field and sees changes reflected',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _TrackingDemoRepository();
      await repo.login('familia', '1234', UserRole.parent);
      final state = AppState(repository: repo);

      await tester.pumpWidget(AutovidaApp(state: state));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pablo García'));
      await tester.pumpAndSettle();

      expect(find.text('Tareas de Pablo García'), findsOneWidget);

      // En la primera página caben 2 tareas; cada una debe tener su botón con lápiz.
      final editIcons = find.byIcon(Icons.edit_outlined);
      expect(editIcons, findsNWidgets(2));

      final firstEditButton = find.byTooltip(
        'Modificar la tarea Preparar la mochila',
      );
      expect(firstEditButton, findsOneWidget);
      final size = tester.getSize(firstEditButton);
      expect(size.width, greaterThanOrEqualTo(72));
      expect(size.height, greaterThanOrEqualTo(72));

      // Al pasar de página, la siguiente tarea también incluye su botón de edición.
      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      final thirdEditButton = find.byTooltip(
        'Modificar la tarea Leer mi cuento',
      );
      expect(thirdEditButton, findsOneWidget);

      // Pulsar el lápiz abre la pantalla de modificación sin campo de descripción.
      await tester.tap(thirdEditButton);
      await tester.pumpAndSettle();

      expect(find.text('Modificar tarea'), findsOneWidget);
      expect(find.text('Para Pablo García'), findsOneWidget);
      expect(find.text('Leer mi cuento'), findsOneWidget);
      expect(find.text('Descripción de la tarea'), findsNothing);
      expect(find.text('Inicio: 17:00'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);

      // Modificar campos y guardar persiste el cambio y actualiza la agenda.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la tarea *'),
        'Leer mi cuento favorito',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Duración (minutos) *'),
        '30',
      );
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(repo.saveTaskCalls, 1);
      expect(repo.lastPrevious?.title, 'Leer mi cuento');
      expect(find.text('Tareas de Pablo García'), findsOneWidget);
      expect(find.text('La tarea se ha modificado.'), findsOneWidget);

      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Leer mi cuento favorito'), findsOneWidget);
      expect(find.text('17:00 · 30 min'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets(
    'LiveRepository sends PUT for student task modification when supported',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final today = isoDate(DateTime.now());
      var currentTitle = 'Leer mi cuento';
      var currentDuration = 20;
      String? putPath;
      String? putQueryDate;
      Map<String, dynamic>? putBody;

      http.Response jsonResponse(Object body, [int status = 200]) =>
          http.Response.bytes(
            utf8.encode(jsonEncode(body)),
            status,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );

      final mock = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'POST' && path == '/auth/login') {
          return jsonResponse({
            'errorCode': 0,
            'details': 'successful',
            'access_token': 'tok',
            'user': {
              'username': 'familia',
              'full_name': 'Elena García',
              'role': 'parent',
            },
          });
        }
        if (request.method == 'GET' && path == '/openapi.json') {
          return jsonResponse({
            'paths': {
              '/student-tasks/students/{student_username}': {'get': {}},
              '/student-tasks/students/{student_username}/{task_id}': {
                'put': {},
              },
              '/student-tasks/me': {'post': {}},
            },
            'components': {'schemas': {}},
          });
        }
        if (request.method == 'GET' &&
            path == '/student-links/parents/familia/students') {
          return jsonResponse({
            'errorCode': 0,
            'details': 'successful',
            'students': [
              {'username': 'pablo', 'full_name': 'Pablo García'},
            ],
          });
        }
        if (request.method == 'GET' && path == '/student-tasks/students/pablo') {
          return jsonResponse({
            'errorCode': 0,
            'details': 'successful',
            'tasks': [
              {
                'task_id': 41,
                'task_title': currentTitle,
                'task_date': today,
                'task_start_hour': '17:00:00',
                'task_duration': currentDuration,
                'task_creator': 'familia',
                'task_finished': false,
                'task_index': 0,
                'alt_task_id_fk': null,
              },
            ],
          });
        }
        if (request.method == 'PUT' &&
            path == '/student-tasks/students/pablo/41') {
          putPath = path;
          putQueryDate = request.url.queryParameters['task_date'];
          putBody = jsonDecode(request.body) as Map<String, dynamic>;
          currentTitle = putBody!['task_title'] as String;
          currentDuration = putBody!['task_duration'] as int;
          return jsonResponse({
            'errorCode': 0,
            'details': 'successful',
            'task_id': 41,
            'task_title': currentTitle,
            'task_date': putBody!['task_date'],
            'task_start_hour': putBody!['task_start_hour'],
            'task_duration': currentDuration,
            'task_creator': 'familia',
            'task_finished': false,
            'task_index': 0,
            'alt_task_id_fk': putBody!['alt_task_id_fk'],
          });
        }
        return jsonResponse(
          {'errorCode': 1000, 'details': 'not found: $path'},
          404,
        );
      });

      final repo = LiveRepository(ApiClient('http://test.local', client: mock));
      await repo.login('familia', '1234', UserRole.parent);
      final state = AppState(repository: repo);

      await tester.pumpWidget(AutovidaApp(state: state));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pablo García'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Modificar la tarea Leer mi cuento'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la tarea *'),
        'Leer un cómic',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Duración (minutos) *'),
        '25',
      );
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(putPath, '/student-tasks/students/pablo/41');
      expect(putQueryDate, today);
      expect(putBody, {
        'task_title': 'Leer un cómic',
        'task_date': today,
        'task_duration': 25,
        'task_start_hour': '17:00:00',
        'alt_task_id_fk': null,
      });
      expect(find.text('La tarea se ha modificado.'), findsOneWidget);
      expect(find.text('Leer un cómic'), findsOneWidget);
      expect(find.text('17:00 · 25 min'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets('student and staff do not see the tutor pencil button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Sesión de alumno.
    final studentRepo = DemoRepository();
    await studentRepo.login('pablo', '1234', UserRole.student);
    final studentState = AppState(repository: studentRepo);
    await tester.pumpWidget(AutovidaApp(state: studentState));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    studentState.dispose();

    // Sesión de personal del centro consultando a un alumno.
    final staffRepo = DemoRepository();
    await staffRepo.login('lucia', '1234', UserRole.staff);
    final staffState = AppState(repository: staffRepo);
    await tester.pumpWidget(AutovidaApp(state: staffState));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aula de la autonomía'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pablo García'));
    await tester.pumpAndSettle();
    expect(find.text('Tareas de Pablo García'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    staffState.dispose();
  });

  testWidgets(
    'tutor agenda and modify screen satisfy tablet touch targets and 200% text scale',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final handle = tester.ensureSemantics();
      final repo = _TrackingDemoRepository();
      await repo.login('familia', '1234', UserRole.parent);
      final state = AppState(repository: repo);

      await tester.pumpWidget(AutovidaApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pablo García'));
      await tester.pumpAndSettle();

      void checkSemantics() {
        final problems = <String>[];
        void visit(SemanticsNode node) {
          final data = node.getSemanticsData();
          if (data.hasAction(SemanticsAction.tap) &&
              !data.flagsCollection.isTextField &&
              !data.flagsCollection.isHidden) {
            final name = [
              data.label,
              data.tooltip,
              data.value,
            ].where((t) => t.isNotEmpty).join(' ');
            if (name.trim().isEmpty) {
              problems.add('Sin nombre accesible en ${node.rect}');
            }
            if (math.min(node.rect.size.width, node.rect.size.height) < 48) {
              problems.add('Objetivo pequeño ${node.rect.size} en «$name»');
            }
          }
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(tester.binding.rootElement!.renderObject!.debugSemantics!);
        expect(problems, isEmpty, reason: problems.join('\n'));
      }

      checkSemantics();

      await tester.tap(
        find.byTooltip('Modificar la tarea Preparar la mochila'),
      );
      await tester.pumpAndSettle();
      checkSemantics();

      // Escala de texto al 200 % sin excepciones de maquetación.
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(1280, 2400);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      handle.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );

  testWidgets(
    'acceptance criteria: rejects invalid fields, blocks staff tasks, and student sees updated task',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = _TrackingDemoRepository();
      await repo.login('familia', '1234', UserRole.parent);
      final state = AppState(repository: repo);

      await tester.pumpWidget(AutovidaApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pablo García'));
      await tester.pumpAndSettle();

      // 1. Tarea creada por personal (lucia, 09:00): el tutor no puede modificarla.
      await tester.tap(
        find.byTooltip('Modificar la tarea Preparar la mochila'),
      );
      await tester.pumpAndSettle();

      // Si intenta guardarla manteniendo horario escolar, rechaza con mensaje descriptivo.
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'La tarea completa debe quedar fuera del horario escolar (09:00–15:00).',
        ),
        findsOneWidget,
      );
      expect(repo.saveTaskCalls, 0);

      // Incluso quitando la hora fija, el repositorio impide modificar tareas del personal.
      await tester.tap(find.text('Sin hora fija'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('creada por el personal del centro'),
        findsOneWidget,
      );

      // Volver a la agenda del alumno y abrir una tarea del tutor.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Modificar la tarea Leer mi cuento'));
      await tester.pumpAndSettle();

      // 2. Campos incorrectos: título vacío y duración inválida muestran mensajes descriptivos.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la tarea *'),
        '   ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Duración (minutos) *'),
        '0',
      );
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Completa este campo.'), findsOneWidget);
      expect(
        find.text('Escribe un número entero mayor que cero.'),
        findsOneWidget,
      );

      // 3. Modificación válida por el tutor.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la tarea *'),
        'Leer mi cuento ilustrado',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Duración (minutos) *'),
        '35',
      );
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('La tarea se ha modificado.'), findsOneWidget);

      // 4. El alumno inicia sesión y ve el cambio reflejado en su propia agenda.
      await state.logout();
      await state.login('pablo', '1234', UserRole.student);
      await tester.pumpAndSettle();
      expect(find.text('Mis tareas'), findsOneWidget);
      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Leer mi cuento ilustrado'), findsOneWidget);
      expect(find.text('17:00 · 35 min'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
}
