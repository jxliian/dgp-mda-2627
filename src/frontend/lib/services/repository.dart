import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/domain.dart';
import 'api_client.dart';

abstract class AutovidaRepository {
  bool get isDemo;
  bool get supportsTaskContent;
  bool get supportsProfileRead;
  bool get offline;
  int get pendingChanges;
  Future<void> synchronize();
  AppUser? get currentUser;
  Future<AppUser> login(String username, String password, UserRole role);
  Future<void> logout();
  Future<List<Classroom>> directory();
  Future<AppUser> profile();
  Future<List<AppUser>> users();
  Future<void> saveUser(Json payload, {AppUser? previous});
  Future<void> deleteUser(AppUser user);
  Future<List<Classroom>> classes();
  Future<Classroom> classDetail(String name);
  Future<void> saveClass(String name, {String? previous});
  Future<void> deleteClass(String name);
  Future<void> addStaff(String classroom, String username);
  Future<void> removeStaff(String classroom, String username);
  Future<void> enroll(String classroom, String username, {bool remove = false});
  Future<List<AppUser>> linkedStudents(AppUser user);
  Future<List<AppUser>> parents(String student);
  Future<void> linkParent(String student, String parent, {bool remove = false});
  Future<List<AgendaTask>> agenda(String student, DateTime date);
  Future<List<AgendaTask>> classTasks(String name);
  Future<AgendaTask> saveTask(
    String student,
    TaskDraft draft, {
    AgendaTask? previous,
    String? classroom,
  });
  Future<void> deleteTask(String student, AgendaTask task, {String? classroom});
  Future<void> setAlternative(int taskId, int? alternativeId);
  Future<AgendaTask> progress(
    String student,
    AgendaTask task, {
    int? stepId,
    bool? finished,
    bool complete = false,
  });
  Future<Uint8List?> avatar(AppUser user);
  Future<void> uploadAvatar(Uint8List image, String filename);
  void close();
}

/// Only currently implemented routes are enabled by default. Optional extensions
/// must be advertised by OpenAPI before the client can call them.
class LiveRepository implements AutovidaRepository {
  LiveRepository(this.api);
  final ApiClient api;
  AppUser? _user;
  Json _paths = {};
  final Map<String, List<AgendaTask>> _agendaCache = {};
  final List<Json> _pending = [];
  SharedPreferences? _storage;
  String? _storageKey;
  bool _offline = false;
  Future<void>? _syncing;
  @override
  bool get offline => _offline;
  @override
  int get pendingChanges => _pending.length;
  @override
  bool get isDemo => false;
  bool supports(String method, String path) =>
      (_paths[path] as Map?)?.containsKey(method.toLowerCase()) == true;
  @override
  bool get supportsTaskContent =>
      supports('get', '/student-tasks/students/{student_username}');
  @override
  bool get supportsProfileRead => supports('get', '/users/me');
  @override
  AppUser? get currentUser => _user;

  Future<void> discover() async {
    final schema = await api.request('GET', '/openapi.json', protected: false);
    _paths = Map<String, dynamic>.from(schema['paths'] as Map? ?? {});
  }

  void requireFeature(String method, String path, String label) {
    if (!supports(method, path)) throw FeatureUnavailable(label);
  }

  @override
  Future<AppUser> login(String username, String password, UserRole role) async {
    final response = await api.request(
      'POST',
      '/auth/login',
      protected: false,
      body: {
        'username': username.trim(),
        'password': password,
        'role': role.name,
      },
    );
    api.token = response['access_token'] as String;
    _user = AppUser.fromJson(
      Map<String, dynamic>.from(response['user'] as Map),
    );
    try {
      await discover();
    } on ApiException {
      /* Existing operations do not depend on discovery. */
    }
    if (supportsProfileRead) {
      _user = await profile();
    }
    _agendaCache.clear();
    _pending.clear();
    _offline = false;
    if (_user!.role == UserRole.student) {
      _storage = await SharedPreferences.getInstance();
      _storageKey = 'autovida/${api.baseUri}/${_user!.username}/agenda';
      final saved = _storage!.getString(_storageKey!);
      if (saved != null) {
        try {
          final json = jsonDecode(saved) as Map;
          for (final entry in (json['agendas'] as Map).entries) {
            _agendaCache[entry.key as String] = (entry.value as List)
                .map(
                  (t) =>
                      AgendaTask.fromJson(Map<String, dynamic>.from(t as Map)),
                )
                .toList();
          }
          _pending.addAll(
            (json['pending'] as List).map(
              (p) => Map<String, dynamic>.from(p as Map),
            ),
          );
        } on Object {
          await _storage!.remove(_storageKey!);
        }
      }
    }
    return _user!;
  }

  @override
  Future<void> logout() async {
    if (_pending.isNotEmpty) {
      try {
        await synchronize();
      } on Object {
        throw const ApiException(
          'Hay progreso pendiente de enviar. Recupera la conexión y pulsa Sincronizar antes de salir.',
        );
      }
    }
    try {
      await api.request('POST', '/auth/logout');
    } finally {
      api.token = null;
      _user = null;
      _agendaCache.clear();
      if (_storageKey != null) await _storage?.remove(_storageKey!);
      _pending.clear();
      _storageKey = null;
    }
  }

  @override
  Future<List<Classroom>> directory() async {
    await discover();
    requireFeature(
      'get',
      '/auth/student-directory',
      'La selección visual de aulas y alumnos',
    );
    final data = await api.request(
      'GET',
      '/auth/student-directory',
      protected: false,
    );
    return _classList(data);
  }

  @override
  Future<AppUser> profile() async {
    requireFeature('get', '/users/me', 'La consulta del perfil');
    final data = await api.request('GET', '/users/me');
    return _user = AppUser.fromJson(
      Map<String, dynamic>.from(data['user'] as Map),
    );
  }

  @override
  Future<List<AppUser>> users() async =>
      _userList(await api.request('GET', '/users'), 'users');
  @override
  Future<void> saveUser(Json payload, {AppUser? previous}) async {
    await api.request(
      previous == null ? 'POST' : 'PUT',
      previous == null
          ? '/users'
          : '/users/${previous.role.name}/${segment(previous.username)}',
      body: payload,
    );
    if (previous?.username == _user?.username) {
      if (payload['password'] != null ||
          (payload['username'] != null &&
              payload['username'] != previous!.username)) {
        api.token = null;
        _user = null;
        api.onSessionExpired?.call();
      } else if (supportsProfileRead) {
        _user = await profile();
      }
    }
  }

  @override
  Future<void> deleteUser(AppUser user) async {
    await api.request(
      'DELETE',
      '/users/${user.role.name}/${segment(user.username)}',
    );
    if (_user?.username == user.username) {
      api.token = null;
      _user = null;
      api.onSessionExpired?.call();
    }
  }

  @override
  Future<List<Classroom>> classes() async =>
      _classList(await api.request('GET', '/classes'));
  @override
  Future<Classroom> classDetail(String name) async =>
      Classroom.fromJson(await api.request('GET', '/classes/${segment(name)}'));
  @override
  Future<void> saveClass(String name, {String? previous}) async {
    await api.request(
      previous == null ? 'POST' : 'PUT',
      previous == null ? '/classes' : '/classes/${segment(previous)}',
      body: {'class_name': name},
    );
  }

  @override
  Future<void> deleteClass(String name) async {
    await api.request('DELETE', '/classes/${segment(name)}');
  }

  @override
  Future<void> addStaff(String classroom, String username) async {
    await api.request(
      'POST',
      '/classes/${segment(classroom)}/staff/${segment(username)}',
    );
  }

  @override
  Future<void> removeStaff(String classroom, String username) async {
    requireFeature(
      'delete',
      '/classes/{class_name}/staff/{staff_username}',
      'La retirada de personal de un aula',
    );
    await api.request(
      'DELETE',
      '/classes/${segment(classroom)}/staff/${segment(username)}',
    );
  }

  @override
  Future<void> enroll(
    String classroom,
    String username, {
    bool remove = false,
  }) async {
    final prefix = _user?.role == UserRole.admin
        ? '/admin/classes'
        : '/classes';
    await api.request(
      remove ? 'DELETE' : 'POST',
      '$prefix/${segment(classroom)}/students/${segment(username)}',
    );
  }

  @override
  Future<List<AppUser>> linkedStudents(AppUser user) async {
    final type = user.role == UserRole.parent ? 'parents' : 'staff';
    return _userList(
      await api.request(
        'GET',
        '/student-links/$type/${segment(user.username)}/students',
      ),
      'students',
      role: UserRole.student,
    );
  }

  @override
  Future<List<AppUser>> parents(String student) async => _userList(
    await api.request('GET', '/student-links/students/${segment(student)}'),
    'parents',
    role: UserRole.parent,
  );
  @override
  Future<void> linkParent(
    String student,
    String parent, {
    bool remove = false,
  }) async {
    await api.request(
      remove ? 'DELETE' : 'POST',
      '/student-links/students/${segment(student)}/parents/${segment(parent)}',
    );
  }

  @override
  Future<List<AgendaTask>> agenda(String student, DateTime date) async {
    final own = _user?.role == UserRole.student;
    final template = own
        ? '/student-tasks/me'
        : '/student-tasks/students/{student_username}';
    requireFeature('get', template, 'La consulta de la agenda individual');
    final key = '$student/${isoDate(date)}';
    try {
      await synchronize();
      final data = await api.request(
        'GET',
        own
            ? '/student-tasks/me'
            : '/student-tasks/students/${segment(student)}',
        query: {'task_date': isoDate(date)},
      );
      final tasks = _tasks(data);
      _agendaCache[key] = tasks;
      _offline = false;
      await _persist();
      return tasks;
    } on ApiException catch (error) {
      // Cached data is never substituted for permission failures or expired sessions.
      if (error.code == null &&
          error.status == null &&
          _agendaCache.containsKey(key)) {
        _offline = true;
        return _agendaCache[key]!;
      }
      rethrow;
    }
  }

  @override
  Future<List<AgendaTask>> classTasks(String name) async =>
      _tasks(await api.request('GET', '/classes/${segment(name)}/tasks'));
  @override
  Future<AgendaTask> saveTask(
    String student,
    TaskDraft draft, {
    AgendaTask? previous,
    String? classroom,
  }) async {
    if (_offline) {
      throw const ApiException(
        'Necesitas conexión para crear o modificar tareas.',
      );
    }
    if (!supportsTaskContent &&
        (draft.steps.isNotEmpty || draft.image != null)) {
      throw const FeatureUnavailable(
        'El guardado de imágenes y pasos de una tarea',
      );
    }
    final own = _user?.role == UserRole.student;
    if (previous != null &&
        classroom == null &&
        !supports(
          'put',
          own
              ? '/student-tasks/me/{task_id}'
              : '/student-tasks/students/{student_username}/{task_id}',
        )) {
      throw const FeatureUnavailable('La edición de tareas individuales');
    }
    final path = classroom != null
        ? '/classes/${segment(classroom)}/tasks${previous == null ? '' : '/${previous.id}'}'
        : '${own ? '/student-tasks/me' : '/student-tasks/students/${segment(student)}'}${previous == null ? '' : '/${previous.id}'}';
    final body = draft.toApiJson();
    if (!supportsTaskContent) {
      body.remove('steps');
      body.remove('task_image');
    }
    final data = await api.request(
      previous == null ? 'POST' : 'PUT',
      path,
      body: body,
      query: previous != null && classroom == null
          ? {'task_date': previous.dateKey}
          : null,
    );
    return AgendaTask.fromJson(data);
  }

  @override
  Future<void> deleteTask(
    String student,
    AgendaTask task, {
    String? classroom,
  }) async {
    final own = _user?.role == UserRole.student;
    await api.request(
      'DELETE',
      classroom != null
          ? '/classes/${segment(classroom)}/tasks/${task.id}'
          : own
          ? '/student-tasks/me/${task.id}'
          : '/student-tasks/students/${segment(student)}/${task.id}',
      query: classroom == null ? {'task_date': task.dateKey} : null,
    );
  }

  @override
  Future<void> setAlternative(int taskId, int? alternativeId) async {
    await api.request(
      'PUT',
      '/student-tasks/$taskId/alternative',
      body: {'alt_task_id_fk': alternativeId},
    );
  }

  @override
  Future<AgendaTask> progress(
    String student,
    AgendaTask task, {
    int? stepId,
    bool? finished,
    bool complete = false,
  }) async {
    requireFeature(
      'patch',
      '/student-tasks/me/{task_id}/progress',
      'El registro de pasos y tareas completados',
    );
    final body = <String, dynamic>{
      'step_id': ?stepId,
      if (stepId != null) 'step_finished': finished ?? true,
      'complete': complete,
    };
    try {
      await synchronize();
      final data = await api.request(
        'PATCH',
        '/student-tasks/me/${task.id}/progress',
        query: {'task_date': task.dateKey},
        body: body,
      );
      final updated = AgendaTask.fromJson(data);
      _replaceCached(student, updated);
      _offline = false;
      await _persist();
      return updated;
    } on ApiException catch (error) {
      if (error.code != null ||
          error.status != null ||
          _user?.role != UserRole.student) {
        rethrow;
      }
      final steps = task.steps
          .map((s) => s.id == stepId ? s.complete(finished ?? true) : s)
          .toList();
      if (complete && steps.any((s) => s.required && !s.finished)) {
        throw const ApiException(
          'Completa los pasos obligatorios antes de terminar la tarea.',
        );
      }
      final updated = task.withProgress(steps, done: complete);
      _pending.add({
        'task_id': task.id,
        'task_date': task.dateKey,
        'body': body,
      });
      _replaceCached(student, updated);
      _offline = true;
      await _persist();
      return updated;
    }
  }

  void _replaceCached(String student, AgendaTask task) {
    final key = '$student/${task.dateKey}';
    final list = _agendaCache.putIfAbsent(key, () => []);
    final index = list.indexWhere((t) => t.id == task.id);
    if (index < 0) {
      list.add(task);
    } else {
      list[index] = task;
    }
  }

  Future<void> _persist() async {
    if (_storageKey == null) return;
    await _storage!.setString(
      _storageKey!,
      jsonEncode({
        'agendas': {
          for (final entry in _agendaCache.entries)
            entry.key: entry.value.map((t) => t.toJson()).toList(),
        },
        'pending': _pending,
      }),
    );
  }

  @override
  Future<void> synchronize() async {
    if (_syncing != null) return _syncing!;
    _syncing = _synchronize();
    try {
      await _syncing;
    } finally {
      _syncing = null;
    }
  }

  Future<void> _synchronize() async {
    if (_pending.isEmpty && _offline) {
      await api.request('GET', '/users/me');
    }
    while (_pending.isNotEmpty) {
      final item = _pending.first;
      await api.request(
        'PATCH',
        '/student-tasks/me/${item['task_id']}/progress',
        query: {'task_date': item['task_date'] as String},
        body: Map<String, dynamic>.from(item['body'] as Map),
      );
      _pending.removeAt(0);
      await _persist();
    }
    _offline = false;
  }

  @override
  Future<Uint8List?> avatar(AppUser user) => api.image(
    _user?.username == user.username
        ? '/users/students/me/avatar'
        : _user?.role == UserRole.parent
        ? '/student-links/parents/me/students/${segment(user.username)}/avatar'
        : user.avatarUrl ??
              '/users/students/${segment(user.username)}/avatar-image',
  );
  @override
  Future<void> uploadAvatar(Uint8List image, String filename) =>
      api.uploadAvatar(image, filename);
  @override
  void close() {
    _agendaCache.clear();
    api.close();
  }

  List<AppUser> _userList(Json data, String key, {UserRole? role}) =>
      (data[key] as List? ?? [])
          .map(
            (e) => AppUser.fromJson(
              Map<String, dynamic>.from(e as Map),
              role: role,
            ),
          )
          .toList();
  List<Classroom> _classList(Json data) => (data['classes'] as List? ?? [])
      .map((e) => Classroom.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  List<AgendaTask> _tasks(Json data) => (data['tasks'] as List? ?? [])
      .map((e) => AgendaTask.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}
