import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:autovida/models/domain.dart';
import 'package:autovida/services/api_client.dart';
import 'package:autovida/services/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('bearer and encoded usernames survive URI construction', () async {
    final api = ApiClient(
      'http://localhost:8000',
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer active-token');
        expect(request.url.pathSegments.last, 'ana#1');
        expect(request.url.queryParameters['task_date'], '2026-11-09');
        return http.Response('{"errorCode":0,"details":"successful"}', 200);
      }),
    )..token = 'active-token';
    await api.request(
      'GET',
      '/students/${segment('ana#1')}',
      query: {'task_date': '2026-11-09'},
    );
    api.close();
  });
  test(
    'expired sessions clear token, while invalid credentials do not expire the app',
    () async {
      var expired = 0;
      final api = ApiClient(
        'http://localhost:8000',
        client: MockClient(
          (request) async => http.Response(
            '{"errorCode":1002,"details":"Token invalido"}',
            401,
          ),
        ),
      )..token = 'old';
      api.onSessionExpired = () => expired++;
      await expectLater(
        api.request('GET', '/users'),
        throwsA(isA<ApiException>()),
      );
      expect(api.token, isNull);
      expect(expired, 1);
      api.close();
    },
  );
  test(
    'login sends username/password/role, profile comes from the authenticated endpoint',
    () async {
      final api = ApiClient(
        'http://localhost:8000',
        client: MockClient((request) async {
          if (request.url.path == '/auth/login') {
            expect(jsonDecode(request.body), {
              'username': 'pablo',
              'password': '1234',
              'role': 'student',
            });
            return http.Response(
              jsonEncode({
                'errorCode': 0,
                'access_token': 'token',
                'user': {'username': 'pablo', 'role': 'student'},
              }),
              200,
            );
          }
          if (request.url.path == '/openapi.json') {
            return http.Response('{"paths":{"/users/me":{"get":{}}}}', 200);
          }
          expect(request.url.path, '/users/me');
          return http.Response(
            jsonEncode({
              'errorCode': 0,
              'user': {
                'username': 'pablo',
                'full_name': 'Pablo',
                'role': 'student',
                'stud_access_task_mod': false,
              },
            }),
            200,
          );
        }),
      );
      final repository = LiveRepository(api);
      final user = await repository.login('pablo', '1234', UserRole.student);
      expect(user.fullName, 'Pablo');
      expect(user.access.flag('task_mod'), false);
      repository.close();
    },
  );
  test('invalid server responses never become successful operations', () async {
    final api = ApiClient(
      'http://localhost:8000',
      client: MockClient(
        (request) async => http.Response('<html>Bad gateway</html>', 502),
      ),
    );
    await expectLater(
      api.request('POST', '/users'),
      throwsA(isA<ApiException>()),
    );
    api.close();
  });

  test(
    'offline progress persists and replays idempotent confirmations in order',
    () async {
      var networkAvailable = true;
      var serverComplete = false;
      final calls = <Map<String, dynamic>>[];
      final task = {
        'task_id': 4,
        'task_title': 'Leer',
        'task_date': '2026-11-09',
        'task_duration': 10,
        'task_creator': 'lucia',
        'task_finished': false,
        'steps': [
          {
            'step_id': 9,
            'step_title': 'Leer',
            'step_description': 'Lee una pagina.',
            'step_duration': 10,
            'step_index': 0,
            'step_finished': false,
            'step_required': true,
          },
        ],
      };
      final api = ApiClient(
        'http://localhost:8000',
        client: MockClient((request) async {
          if (!networkAvailable) throw http.ClientException('offline');
          if (request.url.path == '/auth/login') {
            return http.Response(
              jsonEncode({
                'errorCode': 0,
                'access_token': 'token',
                'user': {'username': 'pablo', 'role': 'student'},
              }),
              200,
            );
          }
          if (request.url.path == '/openapi.json') {
            return http.Response(
              jsonEncode({
                'paths': {
                  '/student-tasks/me': {'get': {}},
                  '/student-tasks/me/{task_id}/progress': {'patch': {}},
                },
              }),
              200,
            );
          }
          if (request.method == 'PATCH') {
            final body = Map<String, dynamic>.from(
              jsonDecode(request.body) as Map,
            );
            calls.add(body);
            serverComplete = body['complete'] == true;
            return http.Response(
              jsonEncode({
                'errorCode': 0,
                ...task,
                'task_finished': serverComplete,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'errorCode': 0,
              'tasks': [task],
            }),
            200,
          );
        }),
      );
      final repository = LiveRepository(api);
      await repository.login('pablo', '1234', UserRole.student);
      final initial = (await repository.agenda(
        'pablo',
        DateTime(2026, 11, 9),
      )).single;
      networkAvailable = false;
      var updated = await repository.progress(
        'pablo',
        initial,
        stepId: 9,
        finished: true,
      );
      updated = await repository.progress('pablo', updated, complete: true);
      expect(updated.finished, true);
      expect(repository.pendingChanges, 2);
      expect(repository.offline, true);
      final cached = await repository.agenda('pablo', DateTime(2026, 11, 9));
      expect(cached.single.finished, true);
      final stored = await SharedPreferences.getInstance();
      expect(stored.getKeys(), isNotEmpty);
      networkAvailable = true;
      await repository.synchronize();
      expect(calls.map((c) => c['complete']), [false, true]);
      expect(serverComplete, true);
      expect(repository.pendingChanges, 0);
      repository.close();
    },
  );
}
