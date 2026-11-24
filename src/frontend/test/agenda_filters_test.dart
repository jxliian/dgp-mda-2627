import 'dart:convert';
import 'package:autovida/models/domain.dart';
import 'package:autovida/screens/agenda_screen.dart';
import 'package:autovida/services/api_client.dart';
import 'package:autovida/services/repository.dart';
import 'package:autovida/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api {
  _Api(this.viewer);
  final UserRole viewer;
  final requests = <http.Request>[];
  bool offline = false;
  bool invalid = false;
  final date = DateTime.now();

  List<Json> get tasks =>
      [
            {
              'task_id': 1,
              'task_title': 'Tarea del aula',
              'task_creator': 'docente',
              'creator_role': 'staff',
              'task_finished': false,
              'class_name_fk': '1 A',
            },
            {
              'task_id': 2,
              'task_title': 'Tarea familiar',
              'task_creator': 'tutor',
              'creator_role': 'parent',
              'task_finished': true,
            },
            {
              'task_id': 3,
              'task_title': 'Tarea propia',
              'task_creator': 'ana#1',
              'creator_role': 'student',
              'task_finished': false,
            },
          ]
          .map(
            (task) => <String, dynamic>{
              ...task,
              'task_date': isoDate(date),
              'task_duration': 10,
            },
          )
          .toList();

  LiveRepository repository() => LiveRepository(
    ApiClient(
      'https://centro/',
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        Json response;
        if (path == '/auth/login') {
          response = {
            'access_token': 'token',
            'user': {
              'username': viewer == UserRole.student ? 'ana#1' : viewer.name,
              'role': viewer.name,
            },
          };
        } else if (path == '/openapi.json') {
          return http.Response(
            jsonEncode({
              'paths': {
                '/student-tasks/students/{student_username}': {'get': {}},
                '/student-tasks/me': {'get': {}},
                '/classes': {'get': {}},
              },
            }),
            200,
          );
        } else if (path == '/') {
          if (offline) throw http.ClientException('Sin conexión');
          response = {};
        } else if (path == '/classes') {
          response = {
            'classes': [
              {'class_name': '1 A'},
            ],
          };
        } else if (path == '/classes/1%20A' ||
            request.url.pathSegments.last == '1 A') {
          response = {
            'class_name': '1 A',
            'students': [
              {'username': 'ana#1', 'full_name': 'Ana'},
            ],
          };
        } else if (path.endsWith('/avatar-image') || path.endsWith('/avatar')) {
          return http.Response(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"></svg>',
            200,
          );
        } else if (path.startsWith('/student-tasks/')) {
          expect(request.headers['authorization'], 'Bearer token');
          if (offline) throw http.ClientException('Sin conexión');
          if (invalid) {
            return http.Response(
              '{"errorCode":1005,"details":"Filtros no válidos"}',
              422,
            );
          }
          final query = request.url.queryParameters;
          final result = tasks
              .where(
                (task) =>
                    (!query.containsKey('class_name') ||
                        task['class_name_fk'] == query['class_name']) &&
                    (!query.containsKey('finished') ||
                        task['task_finished'].toString() ==
                            query['finished']) &&
                    (!query.containsKey('creator_role') ||
                        task['creator_role'] == query['creator_role']),
              )
              .toList();
          response = {'tasks': result};
        } else {
          fail('Unexpected request: $path');
        }
        return http.Response(
          jsonEncode({'errorCode': 0, ...response}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    ),
  );
}

Future<void> _choose(WidgetTester tester, String label, String option) async {
  final field = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.decoration.labelText == label,
  );
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('es');
  });

  for (final viewer in [UserRole.staff, UserRole.parent]) {
    test(
      '${viewer.name}: filters combine on the existing route and false is sent',
      () async {
        final api = _Api(viewer);
        final repo = api.repository();
        addTearDown(repo.close);
        await repo.login(viewer.name, '1234', viewer);
        expect(await repo.agenda('ana#1', api.date), hasLength(3));
        expect(api.requests.last.url.queryParameters, {
          'task_date': isoDate(api.date),
        });
        final result = await repo.agenda(
          'ana#1',
          api.date,
          filters: const AgendaFilters(
            className: '1 A',
            finished: false,
            creatorRole: UserRole.staff,
          ),
        );
        expect(api.requests.last.url.pathSegments.last, 'ana#1');
        expect(api.requests.last.url.queryParameters, {
          'task_date': isoDate(api.date),
          'class_name': '1 A',
          'finished': 'false',
          'creator_role': 'staff',
        });
        expect(result.single.id, 1);
        expect(result.single.creatorRole, UserRole.staff);
        expect(
          result.single.withProgress([], done: true).toJson()['creator_role'],
          'staff',
        );
      },
    );
  }

  test(
    'filtered caches do not reuse unfiltered tasks and 422 remains an error',
    () async {
      final api = _Api(UserRole.staff);
      final repo = api.repository();
      addTearDown(repo.close);
      await repo.login('staff', '1234', UserRole.staff);
      await repo.agenda('ana#1', api.date);
      const filters = AgendaFilters(finished: true);
      api.offline = true;
      await expectLater(
        repo.agenda('ana#1', api.date, filters: filters),
        throwsA(isA<ApiException>()),
      );
      api.offline = false;
      expect(
        (await repo.agenda('ana#1', api.date, filters: filters)).single.id,
        2,
      );
      api.offline = true;
      expect(
        (await repo.agenda('ana#1', api.date, filters: filters)).single.id,
        2,
      );
      api.offline = false;
      api.invalid = true;
      await expectLater(
        repo.agenda('ana#1', api.date, filters: filters),
        throwsA(
          isA<ApiException>().having((error) => error.status, 'status', 422),
        ),
      );
    },
  );

  test(
    'own agenda uses /me with only task_date and filters its cached results locally',
    () async {
      final api = _Api(UserRole.student);
      final repo = api.repository();
      addTearDown(repo.close);
      await repo.login('ana#1', '1234', UserRole.student);
      final result = await repo.agenda(
        'ana#1',
        api.date,
        filters: const AgendaFilters(finished: true),
      );
      expect(result.single.id, 2);
      expect(api.requests.last.url.path, '/student-tasks/me');
      expect(api.requests.last.url.queryParameters, {
        'task_date': isoDate(api.date),
      });
      api.offline = true;
      expect(
        await repo.agenda(
          'ana#1',
          api.date,
          filters: const AgendaFilters(finished: false),
        ),
        hasLength(2),
      );
    },
  );

  for (final viewer in [UserRole.staff, UserRole.parent]) {
    for (final viewport in [const Size(1280, 1100), const Size(390, 844)]) {
      testWidgets(
        '${viewer.name} $viewport: agenda combines controls, empty results and clearing filters',
        (tester) async {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final api = _Api(viewer);
          final repo = api.repository();
          await repo.login(viewer.name, '1234', viewer);
          final state = AppState(repository: repo);
          await tester.pumpWidget(
            AppScope(
              state: state,
              child: MaterialApp(
                home: AgendaScreen(
                  student: AppUser(
                    username: 'ana#1',
                    fullName: 'Ana',
                    role: UserRole.student,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Tarea del aula'), findsOneWidget);
          expect(find.text('Creada por · Personal'), findsOneWidget);
          await tester.ensureVisible(find.text('Completadas'));
          await tester.tap(find.text('Completadas'));
          await tester.pumpAndSettle();
          expect(find.text('Tarea familiar'), findsOneWidget);
          expect(find.text('Tarea del aula'), findsNothing);
          await _choose(tester, 'Tareas de clase', 'Solo la clase 1 A');
          expect(find.text('No hay tareas con estos filtros.'), findsOneWidget);
          await tester.ensureVisible(find.text('Todas'));
          await tester.tap(find.text('Todas'));
          await tester.pumpAndSettle();
          expect(find.text('Tarea del aula'), findsOneWidget);
          await _choose(tester, 'Quién creó la tarea', 'Familia');
          expect(find.text('No hay tareas con estos filtros.'), findsOneWidget);
          await _choose(tester, 'Tareas de clase', 'Todas las tareas');
          expect(find.text('Tarea familiar'), findsOneWidget);
          await _choose(tester, 'Quién creó la tarea', 'Cualquier creador');
          expect(find.text('Tarea del aula'), findsOneWidget);
          expect(
            api.requests
                .lastWhere((r) => r.url.path.startsWith('/student-tasks/'))
                .url
                .queryParameters,
            {'task_date': isoDate(api.date)},
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          state.dispose();
        },
      );
    }
  }
}
