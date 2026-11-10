import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:autovida/models/domain.dart';

/// Respuesta literal de GET /users/me del servidor real, para comprobar que
/// los ajustes del alumno llegan hasta la interfaz.
const _fichaDePablo = r'''{"errorCode": 0, "details": "successful", "username": "pablo", "full_name": "Pablo García", "stud_access_main_col": "#fbf9f5", "stud_access_sec_col": "#1b4332", "stud_access_ntasks_visible": 3, "stud_access_pictograms": true, "stud_access_contrast": false, "stud_access_fontsize": 20, "stud_access_filters": true, "stud_access_ndays_visible": 7, "stud_access_prof_mod": false, "stud_access_timebar": true, "stud_access_talkback": true, "stud_access_profile_mod": true, "stud_access_task_mod": true, "role": "student"}''';

void main() {
  test('los ajustes del alumno llegan desde el servidor', () {
    final json = Map<String, dynamic>.from(jsonDecode(_fichaDePablo) as Map);
    final alumno = AppUser.fromJson(json, role: UserRole.student);
    expect(alumno.username, 'pablo');
    // Cada ajuste vale lo que diga el servidor, no el valor por defecto.
    for (final clave in ['task_mod', 'profile_mod', 'pictograms', 'contrast']) {
      expect(
        alumno.access.flag(clave),
        json['stud_access_$clave'],
        reason: '$clave debe venir del servidor',
      );
    }
  });

}
