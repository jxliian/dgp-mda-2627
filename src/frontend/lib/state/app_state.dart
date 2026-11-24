import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import '../models/domain.dart';
import '../services/api_client.dart';
import '../services/demo_repository.dart';
import '../services/repository.dart';
import '../services/profile_photos.dart';

class AppState extends ChangeNotifier {
  AppState({AutovidaRepository? repository}) {
    this.repository = repository ?? _live();
    if (repository != null) user = repository.currentUser;
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (user != null && this.repository.pendingChanges > 0) {
        try {
          await synchronize();
        } on Object {
          /* Retry idempotent progress when the connection returns. */
        }
      }
    });
  }
  late AutovidaRepository repository;
  final profilePhotos = ProfilePhotos();
  String get photoNamespace => repository is LiveRepository
      ? (repository as LiveRepository).api.baseUri.toString()
      : serverUrl;
  AppUser? user;
  String serverUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  int sessionVersion = 0;
  int avatarVersion = 0;
  int classroomVersion = 0;
  Timer? _syncTimer;
  bool get demo => repository.isDemo;
  bool get student => user?.role == UserRole.student;
  bool get canEditOwnSettings =>
      user != null && (!student || access.flag('profile_mod'));
  AccessSettings get access => user?.access ?? AccessSettings();

  LiveRepository _live() {
    final client = ApiClient(serverUrl);
    client.onSessionExpired = expire;
    return LiveRepository(client);
  }

  void expire() {
    user = null;
    sessionVersion++;
    notifyListeners();
  }

  void setDemo(bool value) {
    repository.close();
    user = null;
    repository = value ? DemoRepository() : _live();
    profilePhotos.clearDemo();
    avatarVersion++;
    sessionVersion++;
    notifyListeners();
  }

  void setServer(String url) {
    serverUrl = url;
    repository.close();
    repository = _live();
    avatarVersion++;
    user = null;
    sessionVersion++;
    notifyListeners();
  }

  Future<void> login(String username, String password, UserRole role) async {
    user = await repository.login(username, password, role);
    avatarVersion++;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await repository.logout();
    } finally {
      if (repository.currentUser == null) {
        user = null;
        sessionVersion++;
        notifyListeners();
      }
    }
  }

  Future<void> refreshProfile() async {
    user = repository.supportsProfileRead
        ? await repository.profile()
        : repository.currentUser;
    notifyListeners();
  }

  void photoChanged() {
    avatarVersion++;
    notifyListeners();
  }

  Future<Uint8List?> profilePhoto(
    AppUser account, {
    bool loadRemote = true,
  }) async {
    final local = await profilePhotos.read(photoNamespace, account, demo: demo);
    if (local != null) return local;
    if (!loadRemote || account.role != UserRole.student) return null;
    return repository.avatar(account);
  }

  /// Solo el servidor de alumnos ofrece actualmente subida de fotos.
  bool profilePhotoIsLocal(AppUser account) =>
      demo ||
      account.role != UserRole.student ||
      !(user?.role == UserRole.admin && repository.canSetAvatarOf ||
          user?.username == account.username && repository.canSetOwnAvatar);

  String profilePhotoSavedMessage(AppUser account) =>
      profilePhotoIsLocal(account)
      ? 'Tu foto se ha guardado en este equipo.'
      : 'Tu foto se ha guardado en el servidor.';

  Future<void> saveProfilePhoto(AppUser account, Uint8List image) async {
    final own =
        user?.username == account.username && user?.role == account.role;
    if (user?.role != UserRole.admin && !(own && canEditOwnSettings)) {
      throw const ApiException('No tienes permiso para cambiar esta foto.');
    }
    final namespace = photoNamespace;
    if (profilePhotoIsLocal(account)) {
      await profilePhotos.save(namespace, account, image, demo: demo);
    } else {
      if (user?.role == UserRole.admin && repository.canSetAvatarOf) {
        await repository.uploadAvatarOf(account, image, 'perfil.png');
      } else {
        await repository.uploadAvatar(image, 'perfil.png');
      }
      // Una copia local anterior no debe ocultar la foto recién subida.
      await profilePhotos.remove(namespace, account);
    }
    photoChanged();
  }

  void classroomsChanged() {
    classroomVersion++;
    notifyListeners();
  }

  Future<void> synchronize() async {
    await repository.synchronize();
    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    repository.close();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
