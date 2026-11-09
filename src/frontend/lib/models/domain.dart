import 'dart:typed_data';
import 'dart:convert';

typedef Json = Map<String, dynamic>;

enum UserRole {
  student('Alumno', 'Alumnos'),
  parent('Tutor familiar', 'Tutores'),
  staff('Personal del centro', 'Personal'),
  admin('Administrador', 'Administradores');

  const UserRole(this.label, this.plural);
  final String label;
  final String plural;
  static UserRole parse(String value) => values.byName(value);
}

class AccessSettings {
  AccessSettings([Json? source]) : values = {...defaults, ...?source};
  final Json values;
  static const Json defaults = {
    'stud_access_main_col': '#ffffff',
    'stud_access_sec_col': '#00695c',
    'stud_access_ntasks_visible': 3,
    'stud_access_pictograms': true,
    'stud_access_contrast': false,
    'stud_access_fontsize': 20,
    'stud_access_filters': true,
    'stud_access_ndays_visible': 7,
    'stud_access_prof_mod': false,
    'stud_access_timebar': true,
    'stud_access_talkback': false,
    'stud_access_profile_mod': true,
    'stud_access_task_mod': true,
  };
  bool flag(String key) => values['stud_access_$key'] == true;
  int number(String key) => (values['stud_access_$key'] as num).toInt();
  String color(String key) => values['stud_access_$key'] as String;
  Json toJson() => {for (final key in defaults.keys) key: values[key]};
  AccessSettings copy() => AccessSettings(toJson());
}

class AppUser {
  AppUser({
    required this.username,
    required this.fullName,
    required this.role,
    this.email,
    this.avatarUrl,
    AccessSettings? access,
  }) : access = access ?? AccessSettings();
  final String username;
  final String fullName;
  final UserRole role;
  final String? email;
  final String? avatarUrl;
  final AccessSettings access;
  String get displayName => fullName.isEmpty ? username : fullName;
  factory AppUser.fromJson(Json json, {UserRole? role}) => AppUser(
    username: json['username'] as String,
    fullName: json['full_name'] as String? ?? '',
    role: role ?? UserRole.parse(json['role'] as String? ?? 'student'),
    email: json['email'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    access: AccessSettings({
      for (final key in AccessSettings.defaults.keys)
        if (json[key] != null) key: json[key],
    }),
  );
  Json toJson() => {
    'username': username,
    'full_name': fullName,
    'role': role.name,
    if (email != null) 'email': email,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
    if (role == UserRole.student) ...access.toJson(),
  };
}

class Classroom {
  const Classroom({
    required this.name,
    this.students = const [],
    this.staff = const [],
    this.image,
  });
  final String name;
  final List<AppUser> students;
  final List<AppUser> staff;
  final Uint8List? image;
  factory Classroom.fromJson(Json json) => Classroom(
    name: json['class_name'] as String,
    image: json['class_image'] == null
        ? null
        : base64Decode(json['class_image'] as String),
    students: (json['students'] as List? ?? [])
        .map(
          (e) => AppUser.fromJson(
            Map<String, dynamic>.from(e as Map),
            role: UserRole.student,
          ),
        )
        .toList(),
    staff: (json['staff'] as List? ?? [])
        .map(
          (e) => AppUser.fromJson(
            Map<String, dynamic>.from(e as Map),
            role: UserRole.staff,
          ),
        )
        .toList(),
  );
}

class TaskStep {
  TaskStep({
    required this.id,
    required this.title,
    required this.description,
    required this.index,
    this.duration = 1,
    this.finished = false,
    this.required = true,
    this.image,
    this.imageUrl,
  });
  final int id;
  final String title;
  final String description;
  final int index;
  final int duration;
  final bool finished;
  final bool required;
  final Uint8List? image;
  final String? imageUrl;
  factory TaskStep.fromJson(Json json) => TaskStep(
    id: json['step_id'] as int,
    title:
        json['step_title'] as String? ??
        'Paso ${(json['step_index'] as int? ?? 0) + 1}',
    description: json['step_description'] as String? ?? '',
    index: json['step_index'] as int? ?? 0,
    duration: json['step_duration'] as int? ?? 1,
    finished: json['step_finished'] == true,
    required: json['step_required'] != false,
    imageUrl: json['image_url'] as String?,
    image: json['step_image'] == null
        ? null
        : base64Decode(json['step_image'] as String),
  );
  TaskStep complete(bool value) => TaskStep(
    id: id,
    title: title,
    description: description,
    index: index,
    duration: duration,
    finished: value,
    required: required,
    image: image,
    imageUrl: imageUrl,
  );
  TaskStep atIndex(int value) => TaskStep(
    id: id,
    title: title,
    description: description,
    index: value,
    duration: duration,
    finished: finished,
    required: required,
    image: image,
    imageUrl: imageUrl,
  );
  Json toJson() => {
    'step_id': id,
    'step_title': title,
    'step_description': description,
    'step_index': index,
    'step_duration': duration,
    'step_finished': finished,
    'step_required': required,
    if (imageUrl != null) 'image_url': imageUrl,
    if (image != null) 'step_image': base64Encode(image!),
  };
}

class AgendaTask {
  AgendaTask({
    required this.id,
    required this.title,
    required this.date,
    required this.duration,
    required this.creator,
    this.startHour,
    this.index = 0,
    this.finished = false,
    this.alternativeId,
    this.className,
    this.steps = const [],
    this.image,
    this.imageUrl,
  });
  final int id;
  final String title;
  final DateTime date;
  final int duration;
  final String creator;
  final String? startHour;
  final int index;
  final bool finished;
  final int? alternativeId;
  final String? className;
  final List<TaskStep> steps;
  final Uint8List? image;
  final String? imageUrl;
  String get dateKey => isoDate(date);
  factory AgendaTask.fromJson(Json json) => AgendaTask(
    id: json['task_id'] as int,
    title: json['task_title'] as String? ?? 'Tarea',
    date: DateTime.parse(json['task_date'] as String),
    duration: json['task_duration'] as int,
    creator: json['task_creator'] as String? ?? '',
    startHour: json['task_start_hour'] as String?,
    index: json['task_index'] as int? ?? 0,
    finished: json['task_finished'] == true,
    alternativeId: json['alt_task_id_fk'] as int?,
    className:
        json['class_name_fk'] as String? ?? json['class_name'] as String?,
    steps: (json['steps'] as List? ?? [])
        .map((e) => TaskStep.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    imageUrl: json['image_url'] as String?,
    image: json['task_image'] == null
        ? null
        : base64Decode(json['task_image'] as String),
  );
  AgendaTask withProgress(List<TaskStep> newSteps, {bool? done}) => AgendaTask(
    id: id,
    title: title,
    date: date,
    duration: duration,
    creator: creator,
    startHour: startHour,
    index: index,
    finished: done ?? finished,
    alternativeId: alternativeId,
    className: className,
    steps: newSteps,
    image: image,
    imageUrl: imageUrl,
  );
  Json toJson() => {
    'task_id': id,
    'task_title': title,
    'task_date': dateKey,
    'task_duration': duration,
    'task_creator': creator,
    'task_start_hour': startHour,
    'task_index': index,
    'task_finished': finished,
    'alt_task_id_fk': alternativeId,
    'class_name_fk': className,
    'steps': steps.map((e) => e.toJson()).toList(),
    if (imageUrl != null) 'image_url': imageUrl,
    if (image != null) 'task_image': base64Encode(image!),
  };
}

class TaskDraft {
  TaskDraft({
    required this.title,
    required this.date,
    required this.duration,
    this.startHour,
    this.alternativeId,
    this.steps = const [],
    this.image,
  });
  final String title;
  final DateTime date;
  final int duration;
  final String? startHour;
  final int? alternativeId;
  final List<TaskStep> steps;
  final Uint8List? image;
  Json toApiJson() => {
    'task_title': title,
    'task_date': isoDate(date),
    'task_duration': duration,
    'task_start_hour': startHour,
    'alt_task_id_fk': alternativeId,
    'task_image': image == null ? null : base64Encode(image!),
    'steps': steps
        .map(
          (step) => {
            'step_title': step.title,
            'step_description': step.description,
            'step_duration': step.duration,
            'step_required': step.required,
            'step_image': step.image == null ? null : base64Encode(step.image!),
          },
        )
        .toList(),
  };
}

String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
bool sameDay(DateTime a, DateTime b) => isoDate(a) == isoDate(b);
