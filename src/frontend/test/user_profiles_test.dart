import 'dart:convert';
import 'package:autovida/models/domain.dart';
import 'package:autovida/screens/admin_screen.dart';
import 'package:autovida/screens/settings_screen.dart';
import 'package:autovida/screens/user_editor_screen.dart';
import 'package:autovida/services/api_client.dart';
import 'package:autovida/services/demo_repository.dart';
import 'package:autovida/services/repository.dart';
import 'package:autovida/state/app_state.dart';
import 'package:autovida/ui/widgets/profile_photo_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class _Server {
  final requests = <http.Request>[];
  final photoUploads = <http.Request>[];
  bool failUpload = false;

  LiveRepository repository(UserRole role) => LiveRepository(
    ApiClient(
      'https://centro/',
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        final profile = {
          'username': role.name,
          'role': role.name,
          'full_name': 'Nombre ${role.name}',
          'email': 'cuenta@example.com',
          if (role == UserRole.student) ...{
            ...AccessSettings.defaults,
            'stud_access_profile_mod': true,
          },
        };
        if (path == '/auth/login') {
          return http.Response(
            jsonEncode({
              'errorCode': 0,
              'access_token': 'token',
              'user': profile,
            }),
            200,
          );
        }
        if (path == '/openapi.json') {
          return http.Response(
            jsonEncode({
              'paths': {
                '/users/me': {'get': {}},
                '/users/{role}/{username}/avatar': {'put': {}},
                '/users/me/avatar': {'put': {}, 'get': {}},
              },
            }),
            200,
          );
        }
        if (path == '/users/me') {
          return http.Response(jsonEncode({'errorCode': 0, ...profile}), 200);
        }
        if (request.method == 'GET' &&
            (path.endsWith('/avatar') || path.endsWith('/avatar-image'))) {
          return http.Response.bytes(_photo, 200);
        }
        if (path.endsWith('/avatar') && request.method == 'PUT') {
          photoUploads.add(request);
          return http.Response(
            '{"errorCode":${failUpload ? 1507 : 0}}',
            failUpload ? 500 : 200,
          );
        }
        if (request.method == 'POST' && path == '/users' ||
            request.method == 'PUT' && path.startsWith('/users/')) {
          return http.Response('{"errorCode":0}', 200);
        }
        fail('Unexpected request: ${request.method} $path');
      }),
    ),
  );
}

Future<void> _mount(WidgetTester tester, AppState state, Widget screen) async {
  tester.view.physicalSize = const Size(1280, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => screen),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(const SizedBox.shrink());
  state.dispose();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void _expectNoContactField(WidgetTester tester) {
  expect(find.text('cuenta@example.com'), findsNothing);
  final fields = tester.widgetList<TextField>(find.byType(TextField));
  expect(
    fields.any((field) => field.keyboardType == TextInputType.emailAddress),
    false,
  );
  expect(
    fields.any(
      (field) => RegExp(
        'gmail|correo|email',
        caseSensitive: false,
      ).hasMatch(field.decoration?.labelText ?? ''),
    ),
    false,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final role in UserRole.values) {
    testWidgets(
      '${role.name}: admin edits without contact data and assigns a photo',
      (tester) async {
        final server = _Server();
        final repo = server.repository(UserRole.admin);
        await repo.login('admin', '1234', UserRole.admin);
        final state = AppState(repository: repo);
        final user = AppUser.fromJson({
          'username': 'cuenta',
          'full_name': 'Persona',
          'role': role.name,
          'email': 'cuenta@example.com',
        });
        await _mount(tester, state, UserEditorScreen(user: user));
        _expectNoContactField(tester);
        final editor = tester.widget<ProfilePhotoEditor>(
          find.byType(ProfilePhotoEditor),
        );
        expect(editor.enabled, true);
        expect(editor.localOnly, false);
        await editor.onSelected(_photo);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ProfilePhotoEditor>(find.byType(ProfilePhotoEditor))
              .photo,
          _photo,
        );
        await _tap(tester, 'Guardar usuario');
        expect(find.text('Abrir'), findsOneWidget);
        final update = server.requests.singleWhere(
          (r) =>
              r.method == 'PUT' && r.url.path == '/users/${role.name}/cuenta',
        );
        final body = jsonDecode(update.body) as Map;
        expect(body.containsKey('email'), false);
        expect(body['full_name'], 'Persona');
        expect(server.photoUploads, hasLength(1));
        expect(
          server.photoUploads.single.url.path,
          '/users/${role.name}/cuenta/avatar',
        );
        final reopened = AppState(
          repository: server.repository(UserRole.admin),
        );
        expect(await reopened.profilePhoto(user), _photo);
        reopened.dispose();
        expect(tester.takeException(), isNull);
        await _close(tester, state);
      },
    );
  }

  for (final role in UserRole.values) {
    testWidgets('${role.name}: own settings upload a photo to the server', (
      tester,
    ) async {
      final server = _Server();
      final repo = server.repository(role);
      await repo.login(role.name, '1234', role);
      final state = AppState(repository: repo);
      await _mount(tester, state, const SettingsScreen());
      _expectNoContactField(tester);
      await tester
          .widget<ProfilePhotoEditor>(find.byType(ProfilePhotoEditor))
          .onSelected(_photo);
      await tester.pumpAndSettle();
      expect(
        find.text('Tu foto se ha guardado en el servidor.'),
        findsOneWidget,
      );
      expect(await state.profilePhoto(state.user!), _photo);
      expect(server.photoUploads.single.url.path, '/users/me/avatar');
      expect(tester.takeException(), isNull);
      await _close(tester, state);
    });
  }

  testWidgets('renaming an account preserves its demo photo', (tester) async {
    final repo = DemoRepository();
    await repo.login('admin', '1234', UserRole.admin);
    final state = AppState(repository: repo);
    final user = (await repo.users()).firstWhere(
      (u) => u.role == UserRole.parent,
    );
    await state.saveProfilePhoto(user, _photo);
    await _mount(tester, state, UserEditorScreen(user: user));
    await _enter(tester, 'Nombre de usuario *', 'familia_nueva');
    await _tap(tester, 'Guardar usuario');
    final renamed = (await repo.users()).firstWhere(
      (u) => u.username == 'familia_nueva',
    );
    expect(await state.profilePhoto(renamed), _photo);
    expect(await state.profilePhoto(user, loadRemote: false), isNull);
    await _close(tester, state);
  });

  testWidgets(
    'own photo is uploaded before a username change revokes the token',
    (tester) async {
      final server = _Server();
      final repo = server.repository(UserRole.admin);
      await repo.login('admin', '1234', UserRole.admin);
      final state = AppState(repository: repo);
      repo.api.onSessionExpired = state.expire;
      await _mount(tester, state, UserEditorScreen(user: state.user));
      await _enter(tester, 'Nombre de usuario *', 'otro_admin');
      await tester
          .widget<ProfilePhotoEditor>(find.byType(ProfilePhotoEditor))
          .onSelected(_photo);
      await tester.pumpAndSettle();
      await _tap(tester, 'Guardar usuario');
      final update = server.requests.singleWhere(
        (r) => r.method == 'PUT' && r.url.path == '/users/admin/admin',
      );
      expect(server.photoUploads.single.url.path, '/users/me/avatar');
      expect(
        server.requests.indexOf(server.photoUploads.single),
        lessThan(server.requests.indexOf(update)),
      );
      expect(state.user, isNull);
      expect(repo.api.token, isNull);
      await _close(tester, state);
    },
  );

  testWidgets(
    'cancelling the file picker restores the editor without changes',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/file_selector');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'openFile');
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final repo = DemoRepository();
      await repo.login('admin', '1234', UserRole.admin);
      final state = AppState(repository: repo);
      await _mount(tester, state, const SettingsScreen());
      await _tap(tester, 'Mi foto');
      expect(find.text('Guardando foto…'), findsNothing);
      expect(
        tester
            .widget<ProfilePhotoEditor>(find.byType(ProfilePhotoEditor))
            .enabled,
        true,
      );
      expect(await state.profilePhoto(state.user!), isNull);
      expect(tester.takeException(), isNull);
      await _close(tester, state);
    },
  );

  testWidgets('deleting an account also removes its demo photo', (
    tester,
  ) async {
    final repo = DemoRepository();
    await repo.login('admin', '1234', UserRole.admin);
    final state = AppState(repository: repo);
    final user = (await repo.users()).firstWhere(
      (u) => u.role == UserRole.parent,
    );
    await state.saveProfilePhoto(user, _photo);
    await _mount(tester, state, const AdminScreen());
    final remove = find.byTooltip('Eliminar a ${user.displayName}');
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(
      (await repo.users()).where((u) => u.username == user.username),
      isEmpty,
    );
    expect(await state.profilePhoto(user, loadRemote: false), isNull);
    expect(tester.takeException(), isNull);
    await _close(tester, state);
  });

  testWidgets(
    'creating a user can include a photo and cancelling discards it',
    (tester) async {
      final repo = DemoRepository();
      await repo.login('admin', '1234', UserRole.admin);
      final state = AppState(repository: repo);
      await _mount(tester, state, const UserEditorScreen());
      await tester
          .widget<ProfilePhotoEditor>(find.byType(ProfilePhotoEditor))
          .onSelected(_photo);
      await tester.pumpAndSettle();
      await _tap(tester, 'Cancelar');
      expect((await repo.users()).where((u) => u.username == 'nuevo'), isEmpty);
      await _tap(tester, 'Abrir');
      expect(
        tester
            .widget<ProfilePhotoEditor>(find.byType(ProfilePhotoEditor))
            .photo,
        isNull,
      );
      await _enter(tester, 'Nombre de usuario *', 'nuevo');
      await _enter(tester, 'Nombre *', 'Nuevo');
      await _enter(tester, 'Apellidos', 'alumno');
      await _enter(tester, 'Contraseña *', '1234');
      await _enter(tester, 'Confirmar contraseña', '1234');
      await tester
          .widget<ProfilePhotoEditor>(find.byType(ProfilePhotoEditor))
          .onSelected(_photo);
      await tester.pumpAndSettle();
      await _tap(tester, 'Guardar usuario');
      final created = (await repo.users()).firstWhere(
        (u) => u.username == 'nuevo',
      );
      expect(await state.profilePhoto(created), _photo);
      await _close(tester, state);
    },
  );

  for (final role in UserRole.values) {
    testWidgets(
      '${role.name}: real account creation sends no email and can upload a photo',
      (tester) async {
        final server = _Server();
        final repo = server.repository(UserRole.admin);
        await repo.login('admin', '1234', UserRole.admin);
        final state = AppState(repository: repo);
        await _mount(tester, state, const UserEditorScreen());
        if (role != UserRole.student) {
          final roles = find.byType(DropdownButtonFormField<UserRole>);
          await tester.ensureVisible(roles);
          await tester.tap(roles);
          await tester.pumpAndSettle();
          await tester.tap(find.text(role.label).last);
          await tester.pumpAndSettle();
        }
        _expectNoContactField(tester);
        await _enter(tester, 'Nombre de usuario *', 'nueva');
        await _enter(tester, 'Nombre *', 'Persona');
        await _enter(tester, 'Apellidos', 'nueva');
        await _enter(tester, 'Contraseña *', '1234');
        await _enter(tester, 'Confirmar contraseña', '1234');
        await tester
            .widget<ProfilePhotoEditor>(find.byType(ProfilePhotoEditor))
            .onSelected(_photo);
        await tester.pumpAndSettle();
        await _tap(tester, 'Guardar usuario');
        expect(find.text('Abrir'), findsOneWidget);
        final creation = server.requests.singleWhere(
          (r) => r.method == 'POST' && r.url.path == '/users',
        );
        final payload = jsonDecode(creation.body) as Map;
        expect(payload['role'], role.name);
        expect(payload.containsKey('email'), false);
        expect(
          server.photoUploads.single.url.path,
          '/users/${role.name}/nueva/avatar',
        );
        expect(
          server.requests.indexOf(creation),
          lessThan(server.requests.indexOf(server.photoUploads.single)),
        );
        await _close(tester, state);
      },
    );
  }

  testWidgets(
    'retrying a failed photo upload does not repeat account creation',
    (tester) async {
      final server = _Server()..failUpload = true;
      final repo = server.repository(UserRole.admin);
      await repo.login('admin', '1234', UserRole.admin);
      final state = AppState(repository: repo);
      await _mount(tester, state, const UserEditorScreen());
      await _enter(tester, 'Nombre de usuario *', 'nuevo');
      await _enter(tester, 'Nombre *', 'Nuevo');
      await _enter(tester, 'Apellidos', 'alumno');
      await _enter(tester, 'Contraseña *', '1234');
      await _enter(tester, 'Confirmar contraseña', '1234');
      await tester
          .widget<ProfilePhotoEditor>(find.byType(ProfilePhotoEditor))
          .onSelected(_photo);
      await tester.pumpAndSettle();
      await _tap(tester, 'Guardar usuario');
      expect(find.textContaining('La cuenta se ha guardado.'), findsOneWidget);
      server.failUpload = false;
      await _tap(tester, 'Guardar usuario');
      expect(find.text('Abrir'), findsOneWidget);
      expect(
        server.requests.where(
          (r) => r.method == 'POST' && r.url.path == '/users',
        ),
        hasLength(1),
      );
      expect(server.photoUploads, hasLength(2));
      await _close(tester, state);
    },
  );
}
