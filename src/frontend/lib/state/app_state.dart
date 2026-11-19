import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
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
  int classroomVersion = 0;
  Timer? _syncTimer;
  bool get demo => repository.isDemo;
  bool get student => user?.role == UserRole.student;
  bool get canEditOwnSettings =>
      user != null && (!student || access.flag('profile_mod'));
  AccessSettings get access => user?.access ?? AccessSettings();

  /// Ajustes de visualización del profesorado, las familias y administración.
  ///
  /// El servidor solo guarda los del alumnado, así que estos viven en el
  /// propio dispositivo. Arrancan en el tamaño de letra de base para que nada
  /// cambie de aspecto hasta que alguien lo pida.
  AccessSettings adultAccess = AccessSettings({'stud_access_fontsize': 16});

  /// Los que se aplican a la sesión actual, sea de quien sea.
  AccessSettings get display => student ? access : adultAccess;

  static const _claveAjustesDeAdulto = 'autovida.adult_access';

  /// Carga los ajustes del dispositivo. Si no hay almacenamiento disponible
  /// ---por ejemplo en las pruebas--- se sigue con los de base.
  Future<void> loadAdultAccess() async {
    try {
      final almacen = await SharedPreferences.getInstance();
      final guardado = almacen.getString(_claveAjustesDeAdulto);
      if (guardado == null) return;
      adultAccess = AccessSettings(
        Map<String, dynamic>.from(jsonDecode(guardado) as Map),
      );
      notifyListeners();
    } on Object {
      /* Sin almacenamiento se usan los ajustes de base. */
    }
  }

  Future<void> saveAdultAccess() async {
    notifyListeners();
    try {
      final almacen = await SharedPreferences.getInstance();
      await almacen.setString(
        _claveAjustesDeAdulto,
        jsonEncode(adultAccess.toJson()),
      );
    } on Object {
      /* Los ajustes siguen aplicados en esta sesión aunque no se guarden. */
    }
  }

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
