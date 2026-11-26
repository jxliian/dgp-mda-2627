import 'dart:convert';
import 'package:autovida/app.dart';
import 'package:autovida/models/domain.dart';
import 'package:autovida/services/api_client.dart';
import 'package:autovida/services/repository.dart';
import 'package:autovida/state/app_state.dart';
import 'package:autovida/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Respuestas con el formato del backend de main, sin base de datos real.
class _MainApi {
  _MainApi(this.role, {this.profileMod = false});

  final UserRole role;
  final bool profileMod;
  final requests = <http.Request>[];
  final students = <String>[];
  final settings = <String, dynamic>{};
  bool staffAssigned = false;
  bool otherClass = false;

  String get username => role == UserRole.student ? 'pablo' : role.name;

  Map<String, dynamic> get profile => {
    'username': username,
    'full_name': username,
    'role': role.name,
    if (role == UserRole.student) ...{
      ...AccessSettings.defaults,
      'stud_access_profile_mod': profileMod,
      'stud_access_ntasks_visible': 3,
      ...settings,
    },
  };

  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = Uri.decodeComponent(request.url.path);
    Map<String, dynamic> data = {};
    if (path == '/auth/login') {
      data = {
        'access_token': 'token',
        'user': {'username': username, 'role': role.name},
      };
    } else if (path == '/openapi.json') {
      return http.Response(
        jsonEncode({
          'paths': {
            '/users/me': {'get': {}},
            '/student-links/students/{student_username}': {'get': {}},
            '/classes/{class_name}/students/{student_username}': {
              'post': {},
              'delete': {},
            },
            '/classes/{class_name}/staff/{staff_username}': {
              'post': {},
              'delete': {},
            },
          },
        }),
        200,
      );
    } else if (path == '/users/me') {
      data = profile;
    } else if (path == '/users') {
      data = {
        'users': [
          {'username': 'lucia', 'full_name': 'Lucía', 'role': 'staff'},
          {'username': 'pablo', 'full_name': 'Pablo', 'role': 'student'},
          if (otherClass) ...[
            {'username': 'ana', 'full_name': 'Ana', 'role': 'student'},
            {'username': 'hugo', 'full_name': 'Hugo', 'role': 'student'},
          ],
        ],
      };
    } else if (path == '/classes') {
      data = {
        'classes': [
          {
            'class_name': 'Aula 1',
            'student_count': students.length,
            'students': [
              for (final name in students)
                {'username': name, 'full_name': 'Pablo'},
            ],
          },
          if (otherClass)
            {
              'class_name': 'Otra aula',
              'students': [
                {'username': 'ana', 'full_name': 'Ana'},
              ],
              'student_count': 1,
            },
        ],
      };
    } else if (path == '/classes/Aula 1') {
      data = {
        'class_name': 'Aula 1',
        'students': [
          for (final student in students)
            {'username': student, 'full_name': 'Pablo'},
        ],
      };
    } else if (path == '/classes/Aula 1/staff/lucia') {
      expect(request.method, anyOf('POST', 'DELETE'));
      staffAssigned = request.method == 'POST';
      data = {'class_name': 'Aula 1', 'staff_username': 'lucia'};
    } else if (path == '/student-links/students/pablo') {
      data = {
        'staff': [
          if (staffAssigned)
            {
              'username': 'lucia',
              'full_name': 'Lucía',
              'email': 'lucia@example.com',
            },
        ],
      };
    } else if (path == '/student-links/staff/lucia/students') {
      data = {
        'students': [
          if (staffAssigned) {'username': 'pablo', 'full_name': 'Pablo'},
        ],
      };
    } else if (path == '/classes/Aula 1/students/pablo') {
      if (request.method == 'POST') {
        students.add('pablo');
      } else {
        expect(request.method, 'DELETE');
        students.remove('pablo');
      }
    } else if (path == '/users/student/pablo' && request.method == 'PUT') {
      final changes = jsonDecode(request.body) as Map<String, dynamic>;
      expect(changes.keys, everyElement(startsWith('stud_access_')));
      expect(changes.containsKey('stud_access_profile_mod'), false);
      expect(changes.containsKey('stud_access_prof_mod'), false);
      expect(changes.containsKey('stud_access_task_mod'), false);
      settings.addAll(changes);
    } else if (path == '/auth/logout') {
      // Sin datos adicionales.
    } else {
      fail('Petición inesperada: ${request.method} $path');
    }
    return http.Response(
      jsonEncode({'errorCode': 0, ...data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  LiveRepository repository() => LiveRepository(
    ApiClient('http://localhost:8000', client: MockClient(respond)),
  );
}

Future<AppState> _open(WidgetTester tester, _MainApi server) async {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = server.repository();
  await repository.login(server.username, '1234', server.role);
  final state = AppState(repository: repository);
  await tester.pumpWidget(AutovidaApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Future<void> _close(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(const SizedBox.shrink());
  state.dispose();
}

Future<void> _choose(WidgetTester tester, String label, String name) async {
  final field = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.decoration.labelText == label,
  );
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('unassigned pupils exclude enrolments in every class', () async {
    final server = _MainApi(UserRole.admin)..otherClass = true;
    server.students.add('pablo');
    final repo = server.repository();
    await repo.login('admin', '1234', UserRole.admin);
    expect((await repo.unassignedStudents()).map((s) => s.username), ['hugo']);
    repo.close();
  });

  testWidgets(
    'admin assigns staff and enrols/removes students using main routes',
    (tester) async {
      final server = _MainApi(UserRole.admin);
      final state = await _open(tester, server);
      expect(state.user!.role, UserRole.admin);
      expect(state.repository.canEnrollStudents, true);
      await tester.tap(find.text('Aulas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aula 1'));
      await tester.pumpAndSettle();

      await _choose(tester, 'Añadir personal', 'Lucía');
      final assign = find.widgetWithText(OutlinedButton, 'Asignar personal');
      expect(tester.widget<OutlinedButton>(assign).onPressed, isNotNull);
      await tester.ensureVisible(assign);
      await tester.tap(assign);
      await tester.pumpAndSettle();
      expect(find.text('Personal del aula actualizado.'), findsOneWidget);
      expect(find.text('Personal asociado al aula'), findsOneWidget);
      expect(find.text('Lucía'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Lucía')).dy,
        greaterThan(
          tester.getBottomLeft(find.text('Personal asociado al aula')).dy,
        ),
      );
      expect(
        server.requests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/staff/lucia'),
        ),
        hasLength(1),
      );

      // Las matrículas son dos listas: se pasa al alumno de una a la otra.
      final enrol = find.byTooltip('Matricular a Pablo');
      await tester.ensureVisible(enrol);
      await tester.tap(enrol);
      await tester.pumpAndSettle();
      expect(server.students, ['pablo']);
      expect(find.text('Total: 1 alumnos'), findsOneWidget);
      final remove = find.byTooltip('Retirar a Pablo');
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar').last);
      await tester.pumpAndSettle();
      expect(server.students, isEmpty);
      expect(find.text('Total: 0 alumnos'), findsOneWidget);
      await tester.ensureVisible(find.text('Volver'));
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('0 alumnos'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _close(tester, state);
    },
  );

  testWidgets(
    'admin reloads existing staff using the pupil association route',
    (tester) async {
      final server = _MainApi(UserRole.admin)..staffAssigned = true;
      server.students.add('pablo');
      final state = await _open(tester, server);
      await tester.tap(find.text('Aulas'));
      await tester.pumpAndSettle();
      expect(find.text('1 del personal'), findsOneWidget);
      await tester.tap(find.text('Aula 1'));
      await tester.pumpAndSettle();
      expect(find.text('Lucía'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Retirar a Lucía'));
      await tester.tap(find.byTooltip('Retirar a Lucía'));
      await tester.pumpAndSettle();
      expect(server.staffAssigned, false);
      expect(
        find.text('No hay personal asociado a esta aula.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await _close(tester, state);
    },
  );

  testWidgets(
    'staff cannot add pupils through the UI or send an enrolment POST',
    (tester) async {
      final server = _MainApi(UserRole.staff);
      final state = await _open(tester, server);
      await tester.tap(find.text('Aula 1'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Gestionar matrículas'));
      await tester.tap(find.text('Gestionar matrículas'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Matricular por usuario'), findsNothing);
      await expectLater(
        state.repository.enroll('Aula 1', 'pablo'),
        throwsA(isA<ApiException>()),
      );
      expect(
        server.requests.where(
          (r) => r.method == 'POST' && r.url.path.contains('/students/'),
        ),
        isEmpty,
      );
      expect(server.requests.where((r) => r.url.path == '/users'), isEmpty);
      expect(tester.takeException(), isNull);
      await _close(tester, state);
    },
  );

  testWidgets('admin assigns an aula from the staff associations screen', (
    tester,
  ) async {
    final server = _MainApi(UserRole.admin);
    final state = await _open(tester, server);
    await tester.tap(find.text('Lucía'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gestionar asociaciones'));
    await tester.tap(find.text('Gestionar asociaciones'));
    await tester.pumpAndSettle();
    // El aula se elige en su propia pantalla, no en un desplegable.
    await tester.tap(find.text('Asignar personal al aula'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aula 1').first);
    await tester.pumpAndSettle();
    expect(server.staffAssigned, true);
    expect(find.text('Personal asignado al aula Aula 1.'), findsOneWidget);
    expect(find.text('Pablo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester, state);
  });

  testWidgets(
    'admin cannot give a student a password unavailable on the picture pad',
    (tester) async {
      final server = _MainApi(UserRole.admin);
      final state = await _open(tester, server);
      await tester.tap(find.text('Pablo'));
      await tester.pumpAndSettle();
      for (final label in [
        'Nueva contraseña (opcional)',
        'Confirmar contraseña',
      ]) {
        final field = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == label,
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, 'letras');
      }
      final save = find.text('Guardar usuario');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        find.text('Usa solo números del 0 al 9 para el acceso con dibujos.'),
        findsOneWidget,
      );
      expect(server.requests.where((r) => r.method == 'PUT'), isEmpty);
      await _close(tester, state);
    },
  );

  for (final permitted in [false, true]) {
    testWidgets('student profile_mod=$permitted controls settings access', (
      tester,
    ) async {
      final server = _MainApi(UserRole.student, profileMod: permitted);
      final state = await _open(tester, server);
      expect(state.access.number('ntasks_visible'), 3);
      expect(find.byType(UserAvatar), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(UserAvatar)).dx,
        lessThan(tester.getTopLeft(find.text('Inicio')).dx),
      );
      expect(find.text('Ajustes'), findsNothing);
      expect(
        find.byTooltip('Ajustes'),
        permitted ? findsOneWidget : findsNothing,
      );
      if (!permitted) {
        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();
        expect(find.text('Mis ajustes'), findsNothing);
      }
      if (permitted) {
        await tester.tap(find.byTooltip('Ajustes'));
        await tester.pumpAndSettle();
        expect(find.text('Cambiar contraseña'), findsNothing);
        expect(find.textContaining('Nueva contraseña'), findsNothing);

        // La accesibilidad vive en su propia pantalla, no dentro de los
        // ajustes: desde aquí solo se entra.
        expect(find.text('Alto contraste'), findsNothing);
        await tester.tap(find.text('Abrir mis opciones de accesibilidad'));
        await tester.pumpAndSettle();
        expect(find.text('Tamaño de letra'), findsOneWidget);
        await tester.ensureVisible(find.text('Alto contraste'));
        await tester.tap(find.text('Alto contraste'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Guardar accesibilidad'));
        await tester.tap(find.text('Guardar accesibilidad'));
        await tester.pumpAndSettle();
        expect(server.settings, {'stud_access_contrast': true});
        expect(state.access.flag('contrast'), true);
        expect(find.text('Los ajustes se han guardado.'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await _close(tester, state);
    });
  }
}
