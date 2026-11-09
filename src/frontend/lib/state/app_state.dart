import 'package:flutter/material.dart';
import 'dart:async';
import '../models/domain.dart';
import '../services/api_client.dart';
import '../services/demo_repository.dart';
import '../services/repository.dart';

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
  AppUser? user;
  String serverUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  int sessionVersion = 0;
  int avatarVersion = 0;
  Timer? _syncTimer;
  bool get demo => repository.isDemo;
  bool get student => user?.role == UserRole.student;
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
    sessionVersion++;
    notifyListeners();
  }

  void setServer(String url) {
    serverUrl = url;
    repository.close();
    repository = _live();
    user = null;
    sessionVersion++;
    notifyListeners();
  }

  Future<void> login(String username, String password, UserRole role) async {
    user = await repository.login(username, password, role);
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
