import 'dart:typed_data';
import '../models/domain.dart';
import '../models/validation.dart';
import 'api_client.dart';
import 'repository.dart';

/// A separate, explicitly labelled sandbox. Never used as a network fallback.
class DemoRepository implements AutovidaRepository {
  DemoRepository() {
    _seed();
  }
  @override
  bool get isDemo => true;
  @override
  bool get supportsTaskContent => true;
  @override
  bool get supportsProfileRead => true;
  @override
  bool get canReadAgenda => true;
  @override
  bool get canTrackProgress => true;
  @override
  bool get canBrowseDirectory => true;
  @override
  bool get canEnrollStudents => true;
  @override
  bool get canRemoveStaff => true;
  @override
  bool get canSetAvatarOf => true;
  @override
  bool get canSetOwnAvatar => true;
  @override
  bool get offline => false;
  @override
  int get pendingChanges => 0;
  @override
  Future<void> synchronize() async {}
  AppUser? _current;
  @override
  AppUser? get currentUser => _current;
  final Map<String, AppUser> _users = {};
  final Map<String, String> _passwords = {};
  final Map<String, Set<String>> _students = {};
  final Map<String, Set<String>> _staff = {};
  final Map<String, Set<String>> _parents = {};
  final Map<String, List<AgendaTask>> _tasks = {};
  final Map<String, Uint8List> _photos = {};
  int _nextTask = 100;

  void _seed() {
    for (final user in [
      AppUser(
        username: 'admin',
        fullName: 'Administración',
        role: UserRole.admin,
        email: 'admin@example.com',
      ),
      AppUser(
        username: 'lucia',
        fullName: 'Lucía Martín',
        role: UserRole.staff,
        email: 'lucia@example.com',
      ),
      AppUser(
        username: 'familia',
        fullName: 'Elena García',
        role: UserRole.parent,
        email: 'familia@example.com',
      ),
      for (final name in [
        'Pablo',
        'Ana',
        'Lucas',
        'Sofía',
        'Diego',
        'Alba',
        'Hugo',
        'María',
      ])
        AppUser(
          username: _slug(name),
          fullName: '$name García',
          role: UserRole.student,
        ),
    ]) {
      _users[user.username] = user;
      _passwords[user.username] = '1234';
    }
    _students.addAll({
      'Aula de la autonomía': {'pablo', 'ana', 'lucas', 'sofia'},
      'Aula de los descubrimientos': {'diego', 'alba', 'hugo', 'maria'},
      'Taller de reprografía': {},
    });
    for (final name in _students.keys) {
      _staff[name] = {'lucia'};
    }
    _parents['pablo'] = {'familia'};
    _parents['ana'] = {'familia'};
    final today = DateTime.now();
    for (final username
        in _users.values
            .where((u) => u.role == UserRole.student)
            .map((u) => u.username)) {
      // La Iteración 1 trata la tarea como una unidad: su descripción se
      // guarda como un único paso no obligatorio.
      _tasks[username] = [
        for (var day = -1; day < 7; day++) ...[
          _demoTask(
            title: 'Preparar la mochila',
            description:
                'Pon la mochila sobre la mesa.\nGuarda el cuaderno, el estuche y la botella de agua.\nCierra la cremallera.',
            date: today.add(Duration(days: day)),
            duration: 10,
            creator: 'lucia',
            startHour: '09:00:00',
          ),
          _demoTask(
            title: 'Regar las plantas',
            description:
                'Llena la regadera con agua.\nEcha un poco de agua en cada maceta.',
            date: today.add(Duration(days: day)),
            duration: 15,
            creator: 'lucia',
            startHour: '10:30:00',
            index: 1,
          ),
          _demoTask(
            title: 'Leer mi cuento',
            description:
                'Elige un cuento que te guste. Busca un lugar tranquilo y lee.',
            date: today.add(Duration(days: day)),
            duration: 20,
            creator: 'familia',
            startHour: '17:00:00',
            index: 2,
          ),
        ],
      ];
    }
  }

  AgendaTask _demoTask({
    required String title,
    required String description,
    required DateTime date,
    required int duration,
    required String creator,
    required String startHour,
    int index = 0,
  }) => AgendaTask(
    id: _nextTask++,
    title: title,
    date: date,
    duration: duration,
    creator: creator,
    startHour: startHour,
    index: index,
    steps: [
      TaskStep(
        id: 1,
        title: title,
        description: description,
        index: 0,
        duration: duration,
        required: false,
      ),
    ],
  );

  String _slug(String s) =>
      s.toLowerCase().replaceAll('í', 'i').replaceAll('á', 'a');
  void _signedIn() {
    if (_current == null) {
      throw const ApiException('Inicia sesión.', code: 1002);
    }
  }

  void _admin() {
    _signedIn();
    if (_current!.role != UserRole.admin) {
      throw const ApiException('Se requiere administrador.');
    }
  }

  void _canAccess(String student) {
    _signedIn();
    final u = _current!;
    final permitted = u.role == UserRole.student
        ? u.username == student
        : u.role == UserRole.parent
        ? (_parents[student]?.contains(u.username) ?? false)
        : u.role == UserRole.staff &&
              _students.entries.any(
                (e) =>
                    e.value.contains(student) &&
                    (_staff[e.key]?.contains(u.username) ?? false),
              );
    if (!permitted) throw const ApiException('No tienes acceso a este alumno.');
  }

  @override
  Future<AppUser> login(String username, String password, UserRole role) async {
    final user = _users[username];
    if (user == null || user.role != role || _passwords[username] != password) {
      throw const ApiException('Usuario o contraseña incorrectos', code: 1001);
    }
    return _current = user;
  }

  @override
  Future<void> logout() async {
    _current = null;
  }

  Classroom _classroom(String name) => Classroom(
    name: name,
    students: (_students[name] ?? {}).map((s) => _users[s]!).toList(),
    staff: (_staff[name] ?? {}).map((s) => _users[s]!).toList(),
  );
  @override
  Future<List<Classroom>> directory() async =>
      _students.keys.map(_classroom).toList();
  @override
  Future<AppUser> profile() async {
    _signedIn();
    return _users[_current!.username]!;
  }

  @override
  Future<List<AppUser>> users() async {
    _admin();
    return _users.values.toList();
  }

  @override
  Future<void> saveUser(Json payload, {AppUser? previous}) async {
    _signedIn();
    final own = _current!.username == previous?.username;
    if (_current!.role != UserRole.admin &&
        (!own ||
            (_current!.role == UserRole.student &&
                !_current!.access.flag('profile_mod')))) {
      throw const ApiException('No tienes permiso para modificar este perfil.');
    }
    if (previous != null &&
        payload['role'] != null &&
        payload['role'] != previous.role.name) {
      throw const ApiException('El rol no se puede cambiar.');
    }
    final data = {...?previous?.toJson(), ...payload};
    final user = AppUser.fromJson(data);
    if (user.username != previous?.username &&
        _users.containsKey(user.username)) {
      throw const ApiException('Ya existe un usuario con ese nombre.');
    }
    final oldName = previous?.username;
    if (oldName != null && oldName != user.username) {
      _users.remove(oldName);
      _passwords[user.username] = _passwords.remove(oldName)!;
      if (_tasks.containsKey(oldName)) {
        _tasks[user.username] = _tasks.remove(oldName)!;
      }
      if (_parents.containsKey(oldName)) {
        _parents[user.username] = _parents.remove(oldName)!;
      }
      for (final set in [
        ..._students.values,
        ..._staff.values,
        ..._parents.values,
      ]) {
        if (set.remove(oldName)) set.add(user.username);
      }
    }
    _users[user.username] = user;
    if (payload['password'] != null) {
      _passwords[user.username] = payload['password'] as String;
    }
    if (own) _current = user;
  }

  @override
  Future<void> deleteUser(AppUser user) async {
    _admin();
    if (user.role == UserRole.admin &&
        _users.values.where((u) => u.role == UserRole.admin).length == 1) {
      throw const ApiException('No se puede eliminar al último administrador.');
    }
    _users.remove(user.username);
    _passwords.remove(user.username);
    _tasks.remove(user.username);
    _parents.remove(user.username);
    _photos.remove(user.username);
    for (final set in [
      ..._students.values,
      ..._staff.values,
      ..._parents.values,
    ]) {
      set.remove(user.username);
    }
    if (_current?.username == user.username) _current = null;
  }

  @override
  Future<List<Classroom>> classes() async {
    _signedIn();
    return _students.keys
        .where(
          (n) =>
              _current!.role == UserRole.admin ||
              (_staff[n]?.contains(_current!.username) ?? false),
        )
        .map(_classroom)
        .toList();
  }

  @override
  Future<Classroom> classDetail(String name) async {
    if (!(await classes()).any((c) => c.name == name)) {
      throw const ApiException('No tienes acceso a esta aula.');
    }
    return _classroom(name);
  }

  @override
  Future<void> saveClass(String name, {String? previous}) async {
    _admin();
    if (name != previous && _students.containsKey(name)) {
      throw const ApiException('Ya existe un aula con ese nombre.');
    }
    _students[name] = previous == null ? {} : _students.remove(previous)!;
    _staff[name] = previous == null ? {} : _staff.remove(previous)!;
  }

  @override
  Future<void> deleteClass(String name) async {
    _admin();
    _students.remove(name);
    _staff.remove(name);
    for (final tasks in _tasks.values) {
      tasks.removeWhere((t) => t.className == name);
    }
  }

  @override
  Future<void> addStaff(String classroom, String username) async {
    _admin();
    if (_users[username]?.role != UserRole.staff) {
      throw const ApiException('Personal no encontrado.');
    }
    _staff[classroom]!.add(username);
  }

  @override
  Future<void> removeStaff(String classroom, String username) async {
    _admin();
    _staff[classroom]!.remove(username);
  }

  @override
  Future<void> enroll(
    String classroom,
    String username, {
    bool remove = false,
  }) async {
    _signedIn();
    if (_current!.role != UserRole.admin &&
        (_current!.role != UserRole.staff ||
            !_staff[classroom]!.contains(_current!.username))) {
      throw const ApiException(
        'La matrícula corresponde al personal asignado al aula.',
      );
    }
    if (_users[username]?.role != UserRole.student) {
      throw const ApiException('Alumno no encontrado.');
    }
    if (remove) {
      _students[classroom]!.remove(username);
      _tasks[username]?.removeWhere((t) => t.className == classroom);
    } else {
      if (_students.entries.any(
        (e) => e.key != classroom && e.value.contains(username),
      )) {
        throw const ApiException('El alumno ya pertenece a otra aula.');
      }
      _students[classroom]!.add(username);
    }
  }

  @override
  Future<List<AppUser>> linkedStudents(AppUser user) async {
    _signedIn();
    if (_current!.role != UserRole.admin &&
        user.username != _current!.username) {
      throw const ApiException('No tienes permiso.');
    }
    final names = user.role == UserRole.parent
        ? _parents.entries
              .where((e) => e.value.contains(user.username))
              .map((e) => e.key)
              .toSet()
        : _students.entries
              .where((e) => _staff[e.key]!.contains(user.username))
              .expand((e) => e.value)
              .toSet();
    return names.map((n) => _users[n]!).toList();
  }

  @override
  Future<List<AppUser>> studentsWithoutClass() async {
    final matriculados = _students.values.expand((e) => e).toSet();
    return _users.values
        .where(
          (u) =>
              u.role == UserRole.student &&
              !matriculados.contains(u.username),
        )
        .toList();
  }

  @override
  Future<List<AppUser>> parents(String student) async {
    _admin();
    return (_parents[student] ?? {}).map((n) => _users[n]!).toList();
  }

  @override
  Future<void> linkParent(
    String student,
    String parent, {
    bool remove = false,
  }) async {
    _admin();
    final set = _parents.putIfAbsent(student, () => {});
    if (remove) {
      set.remove(parent);
    } else {
      set.add(parent);
    }
  }

  @override
  Future<List<AgendaTask>> agenda(String student, DateTime date) async {
    _canAccess(student);
    return (_tasks[student] ?? []).where((t) => sameDay(t.date, date)).toList()
      ..sort(
        (a, b) => (a.startHour ?? '99:99').compareTo(b.startHour ?? '99:99'),
      );
  }

  @override
  Future<List<AgendaTask>> classTasks(String name) async {
    await classDetail(name);
    return {
      for (final u in _students[name]!)
        for (final t in _tasks[u] ?? <AgendaTask>[])
          if (t.className == name) '${t.id}/${t.dateKey}': t,
    }.values.toList();
  }

  @override
  Future<AgendaTask> saveTask(
    String student,
    TaskDraft draft, {
    AgendaTask? previous,
    String? classroom,
  }) async {
    _signedIn();
    final error = scheduleError(
      _current!.role,
      draft.startHour,
      draft.duration,
    );
    if (error != null) throw ApiException(error);
    if (_current!.role == UserRole.student &&
        !_current!.access.flag('task_mod')) {
      throw const ApiException('No tienes permiso para modificar tus tareas.');
    }
    if (previous != null &&
        _current!.role == UserRole.student &&
        previous.creator != _current!.username) {
      throw const ApiException('Solo puedes modificar tus propias tareas.');
    }
    final targets = classroom == null
        ? [student]
        : _students[classroom]!.toList();
    if (targets.isEmpty) {
      throw const ApiException(
        'El aula debe tener alumnos para asignar tareas.',
      );
    }
    for (final target in targets) {
      _canAccess(target);
    }
    final task = AgendaTask(
      id: previous?.id ?? _nextTask++,
      title: draft.title,
      date: draft.date,
      duration: draft.duration,
      creator: previous?.creator ?? _current!.username,
      startHour: draft.startHour,
      alternativeId: draft.alternativeId,
      className: classroom,
      steps: draft.steps,
    );
    for (final username in targets) {
      final tasks = _tasks.putIfAbsent(username, () => []);
      if (previous != null) {
        tasks.removeWhere(
          (t) => t.id == previous.id && sameDay(t.date, previous.date),
        );
      }
      tasks.add(
        task.withProgress(task.steps.map((s) => s.complete(false)).toList()),
      );
    }
    return task;
  }

  @override
  Future<void> deleteTask(
    String student,
    AgendaTask task, {
    String? classroom,
  }) async {
    _canAccess(student);
    final user = _current!;
    if (user.role == UserRole.student &&
        (task.creator != user.username || !user.access.flag('task_mod'))) {
      throw const ApiException(
        'Solo puedes eliminar tus propias tareas si tienes permiso.',
      );
    }
    if (classroom != null) {
      for (final list in _tasks.values) {
        list.removeWhere((t) => t.id == task.id && t.className == classroom);
      }
    } else {
      _tasks[student]?.removeWhere(
        (t) => t.id == task.id && sameDay(t.date, task.date),
      );
    }
  }

  @override
  Future<void> setAlternative(int taskId, int? alternativeId) async {
    throw const FeatureUnavailable(
      'El catálogo de tareas alternativas de demostración',
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
    _canAccess(student);
    if (_current!.role != UserRole.student) {
      throw const ApiException('El alumno registra su progreso.');
    }
    final list = _tasks[student]!;
    final index = list.indexWhere(
      (t) => t.id == task.id && sameDay(t.date, task.date),
    );
    final stored = list[index];
    final steps = stored.steps
        .map((s) => s.id == stepId ? s.complete(finished ?? true) : s)
        .toList();
    if (complete && steps.any((s) => s.required && !s.finished)) {
      throw const ApiException(
        'Completa los pasos obligatorios antes de terminar.',
      );
    }
    return list[index] = stored.withProgress(
      steps,
      done: complete ? true : false,
    );
  }

  @override
  Future<Uint8List?> avatar(AppUser user) async => _photos[user.username];
  @override
  Future<void> uploadAvatarOf(
    AppUser user,
    Uint8List image,
    String filename,
  ) async {
    _admin();
    _photos[user.username] = image;
  }

  @override
  Future<void> uploadAvatar(Uint8List image, String filename) async {
    _signedIn();
    if (!_current!.access.flag('profile_mod')) {
      throw const ApiException('No puedes cambiar tu foto.');
    }
    if (image.length > 5 * 1024 * 1024) {
      throw const ApiException('La imagen no puede superar los 5 MB.');
    }
    _photos[_current!.username] = image;
  }

  @override
  void close() {}
}
