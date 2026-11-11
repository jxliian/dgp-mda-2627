import 'dart:convert';
import 'domain.dart';

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Completa este campo.' : null;
String? usernameError(String? value) {
  if (requiredText(value) != null) return 'Escribe el nombre de usuario.';
  if (value!.trim().length > 50 || RegExp(r'\s').hasMatch(value.trim())) {
    return 'Usa hasta 50 caracteres, sin espacios.';
  }
  return null;
}

String? fullNameError(String? value) {
  if (requiredText(value) != null) return 'Escribe el nombre completo.';
  if (value!.trim().length > 150 ||
      RegExp(r'\d').hasMatch(value) ||
      !RegExp(r'[a-zA-ZÀ-ž]').hasMatch(value)) {
    return 'Escribe un nombre con letras, sin números (máximo 150 caracteres).';
  }
  return null;
}

String? passwordError(String? value) {
  if (value == null || value.isEmpty) return 'Escribe la contraseña.';
  return utf8.encode(value).length > 72
      ? 'La contraseña supera los 72 bytes permitidos.'
      : null;
}

String? emailError(String? value) =>
    value != null &&
        value.length <= 254 &&
        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
    ? null
    : 'Escribe un correo electrónico válido.';
String? positiveInteger(String? value) =>
    int.tryParse(value ?? '') == null || int.parse(value!) <= 0
    ? 'Escribe un número entero mayor que cero.'
    : null;

/// Mirrors task_schedule.py; the server remains the authority for permissions.
String? scheduleError(UserRole role, String? hour, int duration) {
  if (duration <= 0) return 'La duración debe ser mayor que cero.';
  if (hour == null) {
    return role == UserRole.staff
        ? 'El personal debe indicar una hora de inicio.'
        : null;
  }
  final match = RegExp(
    r'^(\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?$',
  ).firstMatch(hour);
  if (match == null) return 'Escribe una hora válida.';
  final h = int.parse(match[1]!);
  final m = int.parse(match[2]!);
  final s = int.parse(match[3] ?? '0');
  if (h > 23 || m > 59 || s > 59) return 'Escribe una hora válida.';
  final start = h * 3600 + m * 60 + s;
  final end = start + duration * 60;
  if (role == UserRole.staff) {
    return start < 9 * 3600 || end > 15 * 3600
        ? 'La tarea completa debe quedar entre las 09:00 y las 15:00.'
        : null;
  }
  final overlaps = start < 9 * 3600
      ? end > 9 * 3600
      : start < 15 * 3600 || end > (24 + 9) * 3600;
  return overlaps
      ? 'La tarea completa debe quedar fuera del horario escolar (09:00–15:00).'
      : null;
}
