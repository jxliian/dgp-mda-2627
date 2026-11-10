import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/domain.dart';
import 'api_client.dart';

abstract class AutovidaRepository {
  bool get isDemo;

  // Lo que sabe hacer el servidor con el que se ha iniciado sesión. La
  // interfaz las consulta para ofrecer solo lo que de verdad funciona, en
  // lugar de enseñar un botón que acaba en error.
  /// Guarda la descripción de una tarea.
  bool get supportsTaskContent;

  /// Devuelve el perfil completo de la sesión.
  bool get supportsProfileRead;

  /// Lista las tareas de la agenda de un alumno.
  bool get canReadAgenda;

  /// Registra que el alumno ha terminado una tarea.
  bool get canTrackProgress;

  /// Ofrece el directorio de aulas y fotos para que el alumno se busque.
  ///
  /// No se puede deducir del catálogo de rutas, porque depende de que
  /// `/classes` acepte peticiones sin sesión. Se comprueba al pedirlo.
  bool get canBrowseDirectory;

  /// Permite a la sesión actual matricular o retirar alumnos de un aula.
  bool get canEnrollStudents;

  /// Alumnos que todavía no están en ninguna clase, que son los únicos que se
  /// pueden matricular: el servidor rechaza al resto con «ya pertenece a otra
  /// clase». Devuelve solo los que esta cuenta puede ver.
  Future<List<AppUser>> studentsWithoutClass();

  /// Permite retirar a un miembro del personal de un aula.
  bool get canRemoveStaff;

  /// Permite a administración cambiar la foto de otra persona (SCRUM-329).
  bool get canSetAvatarOf;

  /// Permite que cada quien cambie su propia foto.
  bool get canSetOwnAvatar;

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

  /// Sube la foto de la propia sesión.
  Future<void> uploadAvatar(Uint8List image, String filename);

  /// Sube la foto de otra persona, desde administración.
  Future<void> uploadAvatarOf(AppUser user, Uint8List image, String filename);
  void close();
}

extension AutovidaRepositoryActions on AutovidaRepository {
  /// Aula a la que pertenece un alumno, o `null` si no consta ninguna.
  ///
  /// Se obtiene del directorio del centro, que es la única vista de aulas
  /// disponible para una sesión de alumno.
  Future<String?> classOf(String student) async {
    try {
      final aulas = await directory();
      for (final aula in aulas) {
        if (aula.students.any((alumno) => alumno.username == student)) {
          return aula.name;
        }
      }
    } on Object {
      // El directorio es opcional: sin él, simplemente no se muestra el aula.
    }
    return null;
  }

  /// Da una tarea por terminada tratándola como una unidad.
  ///
  /// Las tareas creadas antes de la Iteración 1 pueden conservar pasos
  /// obligatorios que el servidor exige confirmar; se confirman primero para
  /// que el alumno no quede bloqueado ante una pantalla sin pasos.
  Future<AgendaTask> completeTask(String student, AgendaTask task) async {
    var actual = task;
    for (final paso in task.steps.where((p) => p.required && !p.finished)) {
      actual = await progress(student, actual, stepId: paso.id, finished: true);
    }
    return progress(student, actual, complete: true);
  }
}

/// Only currently implemented routes are enabled by default. Optional extensions
/// must be advertised by OpenAPI before the client can call them.
class LiveRepository implements AutovidaRepository {
  LiveRepository(this.api);
  final ApiClient api;
  AppUser? _user;
  Json _paths = {};
  Json _esquemas = {};
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
      camposDelCuerpo('post', '/student-tasks/me').contains('steps');
  @override
  bool get supportsProfileRead => supports('get', '/users/me');
  @override
  bool get canReadAgenda => _user?.role == UserRole.student
      ? supports('get', '/student-tasks/me')
      : supports('get', '/student-tasks/students/{student_username}');
  @override
  bool get canTrackProgress =>
      supports('patch', '/student-tasks/me/{task_id}/progress');
  @override
  bool get canBrowseDirectory => supports('get', '/classes');
  @override
  bool get canEnrollStudents => supports('post', _rutaDeMatricula);
  @override
  bool get canRemoveStaff =>
      supports('delete', '/classes/{class_name}/staff/{staff_username}');
  @override
  bool get canSetAvatarOf =>
      supports('put', '/users/students/{student_username}/avatar');
  @override
  bool get canSetOwnAvatar => supports('put', '/users/students/me/avatar');

  /// Misma ruta para todos: el servidor decide quién puede matricular.
  static const _rutaDeMatricula =
      '/classes/{class_name}/students/{student_username}';
  @override
  AppUser? get currentUser => _user;

  Future<void> discover() async {
    final schema = await api.request('GET', '/openapi.json', protected: false);
    _paths = Map<String, dynamic>.from(schema['paths'] as Map? ?? {});
    final componentes = schema['components'] as Map?;
    _esquemas = Map<String, dynamic>.from(componentes?['schemas'] as Map? ?? {});
  }

  /// Campos que admite el cuerpo de una operación, resolviendo la referencia
  /// al esquema que declara OpenAPI.
  ///
  /// Preguntar por un campo concreto es más fiable que deducir capacidades de
  /// la existencia de otra ruta: dos servidores pueden ofrecer la misma ruta y
  /// aceptar datos distintos.
  Set<String> camposDelCuerpo(String method, String path) {
    final operacion = (_paths[path] as Map?)?[method.toLowerCase()] as Map?;
    final contenido = (operacion?['requestBody'] as Map?)?['content'] as Map?;
    var definicion = (contenido?['application/json'] as Map?)?['schema'] as Map?;
    final referencia = definicion?[r'$ref'] as String?;
    if (referencia != null) {
      definicion = _esquemas[referencia.split('/').last] as Map?;
    }
    final propiedades = (definicion?['properties'] as Map?)?.keys ?? const [];
    return propiedades.map((clave) => clave.toString()).toSet();
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

  /// Aulas con sus alumnos para que el alumno se busque antes de entrar.
  ///
  /// Sin sesión, `/classes` devuelve solo los nombres y hay que pedir cada
  /// aula por separado para obtener su alumnado. Si el servidor exige sesión,
  /// la llamada falla y la pantalla ofrece entrar escribiendo el usuario.
  @override
  Future<List<Classroom>> directory() async {
    final data = await api.request('GET', '/classes', protected: false);
    final nombres = (data['classes'] as List? ?? [])
        .map((aula) => (aula as Map)['class_name'] as String)
        .toList();
    final aulas = await Future.wait(nombres.map(_aulaPublica));
    return aulas.nonNulls.toList();
  }

  /// Un aula con su alumnado, o `null` si deja de estar disponible mientras
  /// se consulta: una sola aula no debe tumbar toda la pantalla.
  Future<Classroom?> _aulaPublica(String nombre) async {
    try {
      final data = await api.request(
        'GET',
        '/classes/${segment(nombre)}',
        protected: false,
      );
      return Classroom.fromJson(data);
    } on ApiException {
      return null;
    }
  }

  @override
  Future<AppUser> profile() async {
    requireFeature('get', '/users/me', 'La consulta del perfil');
    final data = await api.request('GET', '/users/me');
    // El servidor devuelve los campos en la raíz; se admite también la forma
    // anidada por si algún despliegue antiguo responde con «user».
    final cuerpo = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : Map<String, dynamic>.from(data);
    return _user = AppUser.fromJson(
      cuerpo,
      // Si la ficha no trae el rol, se conserva el de la sesión.
      role: cuerpo['role'] == null ? _user?.role : null,
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
  @override
  Future<List<AppUser>> studentsWithoutClass() async {
    final matriculados = <String>{
      for (final aula in await directory())
        for (final alumno in aula.students) alumno.username,
    };
    final conocidos = _user?.role == UserRole.admin
        ? (await users()).where((u) => u.role == UserRole.student)
        : await linkedStudents(_user!);
    return conocidos
        .where((alumno) => !matriculados.contains(alumno.username))
        .toList();
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
    // La descripción viaja en el esquema de pasos: si el servidor todavía no
    // lo admite, la tarea se guarda con sus datos básicos.
    if (!supportsTaskContent) body.remove('steps');
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
      // Comprobación de vida contra la raíz de la API, que existe en
      // cualquier servidor: /users/me es una ampliación opcional.
      await api.request('GET', '/', protected: false);
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
        : user.avatarUrl ??
              '/users/students/${segment(user.username)}/avatar-image',
  );
  @override
  Future<void> uploadAvatar(Uint8List image, String filename) =>
      api.uploadAvatar(image, filename);
  @override
  Future<void> uploadAvatarOf(
    AppUser user,
    Uint8List image,
    String filename,
  ) {
    requireFeature(
      'put',
      '/users/students/{student_username}/avatar',
      'El cambio de la foto de otra persona desde administración',
    );
    return api.uploadAvatar(
      image,
      filename,
      path: '/users/students/${segment(user.username)}/avatar',
    );
  }
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
