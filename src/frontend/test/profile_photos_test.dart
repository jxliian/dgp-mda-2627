import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:autovida/models/domain.dart';
import 'package:autovida/services/api_client.dart';
import 'package:autovida/services/demo_repository.dart';
import 'package:autovida/services/profile_photos.dart';
import 'package:autovida/services/repository.dart';
import 'package:autovida/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final photo = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

AppUser account(UserRole role, [String username = 'persona']) =>
    AppUser(username: username, fullName: 'Persona', role: role);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final role in UserRole.values) {
    test(
      '${role.name}: local photo survives a new store and is isolated',
      () async {
        final user = account(role);
        await ProfilePhotos().save('https://centro/', user, photo);
        final reopened = ProfilePhotos();
        expect(await reopened.read('https://centro/', user), photo);
        expect(await reopened.read('https://otro-centro/', user), isNull);
        expect(
          await reopened.read('https://centro/', account(role, 'otra')),
          isNull,
        );
        for (final otherRole in UserRole.values.where((r) => r != role)) {
          expect(
            await reopened.read('https://centro/', account(otherRole)),
            isNull,
          );
        }
        expect(
          await reopened.read('https://centro/', user, demo: true),
          isNull,
        );
        await reopened.save(
          'https://centro/',
          user,
          Uint8List.fromList([1]),
          demo: true,
        );
        reopened.clearDemo();
        expect(
          await reopened.read('https://centro/', user, demo: true),
          isNull,
        );
        expect(await reopened.read('https://centro/', user), photo);
        await reopened.remove('https://centro/', user);
        expect(await ProfilePhotos().read('https://centro/', user), isNull);
      },
    );

    test(
      '${role.name}: admin can set a photo and user can see it after login',
      () async {
        final repo = DemoRepository();
        final state = AppState(repository: repo);
        addTearDown(state.dispose);
        await state.login('admin', '1234', UserRole.admin);
        final user = (await repo.users()).firstWhere((u) => u.role == role);
        await state.saveProfilePhoto(user, photo);
        await state.logout();
        await state.login(user.username, '1234', role);
        expect(await state.profilePhoto(state.user!), photo);
        if (role == UserRole.student) {
          await expectLater(
            state.saveProfilePhoto(user, photo),
            throwsA(isA<ApiException>()),
          );
          user.access.values['stud_access_profile_mod'] = true;
        }
        await state.saveProfilePhoto(state.user!, photo);
        expect(await state.profilePhoto(state.user!), photo);
        if (role != UserRole.admin) {
          await expectLater(
            state.saveProfilePhoto(account(UserRole.admin), photo),
            throwsA(isA<ApiException>()),
          );
        }
        state.setDemo(true);
        expect(await state.profilePhoto(user, loadRemote: false), isNull);
      },
    );
  }

  test('admin student photos still use the existing server upload', () async {
    var uploaded = false;
    final student = account(UserRole.student);
    final api = ApiClient(
      'https://centro/',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/auth/login':
            return http.Response(
              jsonEncode({
                'errorCode': 0,
                'access_token': 'token',
                'user': account(UserRole.admin, 'admin').toJson(),
              }),
              200,
            );
          case '/openapi.json':
            return http.Response(
              jsonEncode({
                'paths': {
                  '/users/students/{student_username}/avatar': {'put': {}},
                },
              }),
              200,
            );
          case '/users/students/persona/avatar':
            expect(request.method, 'PUT');
            expect(request.headers['authorization'], 'Bearer token');
            expect(
              request.headers['content-type'],
              startsWith('multipart/form-data'),
            );
            uploaded = true;
            return http.Response('{"errorCode":0}', 200);
          case '/users/students/persona/avatar-image':
            expect(uploaded, true);
            return http.Response.bytes(photo, 200);
          default:
            fail('Unexpected request: ${request.method} ${request.url.path}');
        }
      }),
    );
    final state = AppState(repository: LiveRepository(api));
    addTearDown(state.dispose);
    await state.login('admin', '1234', UserRole.admin);
    await state.profilePhotos.save(
      state.photoNamespace,
      student,
      Uint8List.fromList([1]),
    );
    expect(state.profilePhotoIsLocal(student), false);
    await state.saveProfilePhoto(student, photo);
    expect(uploaded, true);
    expect(
      await state.profilePhotos.read(state.photoNamespace, student),
      isNull,
    );
    expect(await state.profilePhoto(student), photo);
  });

  test(
    'invalid, empty and oversized images are rejected before storage',
    () async {
      for (final invalid in [
        Uint8List(0),
        Uint8List.fromList([1, 2, 3]),
        Uint8List(5 * 1024 * 1024 + 1),
      ]) {
        await expectLater(prepareProfilePhoto(invalid), throwsFormatException);
      }
      final normalized = await prepareProfilePhoto(photo);
      final codec = await ui.instantiateImageCodec(normalized);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1);
      expect(frame.image.height, 1);
      frame.image.dispose();
      codec.dispose();
    },
  );

  test('large photos are reduced with their aspect ratio preserved', () async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xff112233), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1200, 600);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final normalized = await prepareProfilePhoto(data!.buffer.asUint8List());
    final codec = await ui.instantiateImageCodec(normalized);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 512);
    expect(frame.image.height, 256);
    frame.image.dispose();
    codec.dispose();
    image.dispose();
    picture.dispose();
  });
}
