import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:autovida/models/domain.dart';
import 'package:autovida/models/task_timer.dart';
import 'package:autovida/models/validation.dart';

void main() {
  test(
    'school interval validates the entire duration and midnight crossing',
    () {
      expect(scheduleError(UserRole.staff, '09:00:00', 360), isNull);
      expect(scheduleError(UserRole.staff, '14:59:00', 2), isNotNull);
      expect(scheduleError(UserRole.staff, null, 20), isNotNull);
      expect(scheduleError(UserRole.parent, '08:50:00', 10), isNull);
      expect(scheduleError(UserRole.parent, '08:50:00', 11), isNotNull);
      expect(scheduleError(UserRole.student, '15:00:00', 20), isNull);
      expect(scheduleError(UserRole.student, null, 20), isNull);
      expect(scheduleError(UserRole.student, '23:00:00', 601), isNotNull);
    },
  );
  test('password limit counts UTF-8 bytes without trimming the password', () {
    expect(passwordError('á' * 36), isNull);
    expect(passwordError('á' * 37), isNotNull);
    expect(passwordError(' '), isNull);
  });
  test('timer pauses and resumes without counting time while paused', () {
    var now = DateTime(2026, 11, 9, 10);
    final timer = TaskTimer(60, now: () => now);
    timer.start();
    now = now.add(const Duration(seconds: 13));
    timer.pause();
    expect(timer.remainingSeconds, 47);
    now = now.add(const Duration(minutes: 5));
    expect(timer.remainingSeconds, 47);
    timer.start();
    now = now.add(const Duration(seconds: 7));
    timer.pause();
    expect(timer.remainingSeconds, 40);
    timer.start();
    now = now.add(const Duration(minutes: 2));
    timer.pause();
    expect(timer.remainingSeconds, 0);
    expect(timer.label, '00:00');
    timer.reset();
    expect(timer.remainingSeconds, 60);
    timer.dispose();
  });
  test('task submission uses strict field names and keeps the task as a unit', () {
    final draft = TaskDraft(
      title: 'Leer',
      date: DateTime(2026, 11, 9),
      duration: 20,
      description: 'Busca la primera página.',
    );
    final json = jsonDecode(jsonEncode(draft.toApiJson())) as Map;
    expect(json['task_date'], '2026-11-09');
    expect(json['task_duration'], isA<int>());
    expect(json.containsKey('task_image'), false);
    // La descripción viaja como un único paso no obligatorio.
    final steps = json['steps'] as List;
    expect(steps.length, 1);
    expect(steps.first['step_description'], 'Busca la primera página.');
    expect(steps.first['step_title'], 'Leer');
    expect(steps.first['step_required'], false);
    expect(steps.first.containsKey('step_finished'), false);
  });
  test('a task without description sends no steps at all', () {
    final draft = TaskDraft(
      title: 'Leer',
      date: DateTime(2026, 11, 9),
      duration: 20,
    );
    expect(draft.steps, isEmpty);
    expect(draft.toApiJson()['steps'], isEmpty);
  });
  test('the description of a stored task reads its step text', () {
    final task = AgendaTask(
      id: 1,
      title: 'Leer',
      date: DateTime(2026, 11, 9),
      duration: 20,
      creator: 'lucia',
      steps: [
        TaskStep(
          id: 5,
          title: 'Leer',
          description: 'Busca la primera página.',
          index: 0,
          required: false,
        ),
      ],
    );
    expect(task.description, 'Busca la primera página.');
  });
}
