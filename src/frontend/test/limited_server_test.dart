import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autovida/app.dart';
import 'package:autovida/models/domain.dart';
import 'package:autovida/services/api_client.dart';
import 'package:autovida/services/demo_repository.dart';
import 'package:autovida/state/app_state.dart';

/// Servidor con el alcance de la rama `main`: no lista agendas, no guarda el
/// progreso ni la descripción, no tiene directorio de fotos y la matrícula
/// solo la hace el personal del aula.
class _ServidorBasico extends DemoRepository {
  @override
  bool get canReadAgenda => false;
  @override
  bool get canTrackProgress => false;
  @override
  bool get canBrowseDirectory => false;
  @override
  bool get canEnrollStudents => false;
  @override
  bool get canRemoveStaff => false;
  @override
  bool get supportsTaskContent => false;
  @override
  bool get supportsProfileRead => false;

  @override
  Future<List<Classroom>> directory() async =>
      throw const FeatureUnavailable('El directorio de alumnos');
}

Future<AppState> _abrir(WidgetTester tester, {UserRole? rol}) async {
  tester.view.physicalSize = const Size(1280, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repositorio = _ServidorBasico();
  if (rol != null) {
    await repositorio.login(switch (rol) {
      UserRole.student => 'pablo',
      UserRole.parent => 'familia',
      UserRole.staff => 'lucia',
      UserRole.admin => 'admin',
    }, '1234', rol);
  }
  final estado = AppState(repository: repositorio);
  await tester.pumpWidget(AutovidaApp(state: estado));
  await tester.pumpAndSettle();
  return estado;
}

Future<void> _cerrar(WidgetTester tester, AppState estado) async {
  await tester.pumpWidget(const SizedBox.shrink());
  estado.dispose();
}

void main() {
  testWidgets('sin directorio, el alumno entra escribiendo su usuario', (
    tester,
  ) async {
    final estado = await _abrir(tester);
    await tester.tap(find.text('Soy alumno'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no muestra las fotos'), findsOneWidget);
    await tester.tap(find.text('Entrar con mi usuario'));
    await tester.pumpAndSettle();
    expect(find.text('Introduce tu contraseña'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Usuario'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _cerrar(tester, estado);
  });

  testWidgets('sin consulta de agenda, se explica y se puede seguir creando', (
    tester,
  ) async {
    final estado = await _abrir(tester, rol: UserRole.student);
    expect(find.textContaining('no permite consultar la lista'), findsOneWidget);
    expect(find.text('Preparar la mochila'), findsNothing);
    expect(find.text('Añadir mi tarea'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _cerrar(tester, estado);
  });

  testWidgets('sin contenido de tarea, el editor no pide descripción', (
    tester,
  ) async {
    final estado = await _abrir(tester, rol: UserRole.student);
    await tester.ensureVisible(find.text('Añadir mi tarea'));
    await tester.tap(find.text('Añadir mi tarea'));
    await tester.pumpAndSettle();
    expect(find.text('Crear tarea'), findsOneWidget);
    expect(find.text('Nombre de la tarea *'), findsOneWidget);
    expect(find.text('Descripción de la tarea'), findsNothing);
    expect(tester.takeException(), isNull);
    await _cerrar(tester, estado);
  });

  testWidgets('sin matrícula, el personal no ve la gestión de alumnos', (
    tester,
  ) async {
    final estado = await _abrir(tester, rol: UserRole.staff);
    await tester.tap(find.text('Aula de la autonomía'));
    await tester.pumpAndSettle();
    expect(find.text('Tareas de toda el aula'), findsOneWidget);
    expect(find.text('Gestionar matrículas'), findsNothing);
    expect(tester.takeException(), isNull);
    await _cerrar(tester, estado);
  });

  testWidgets('administración mantiene usuarios, aulas y profesorado', (
    tester,
  ) async {
    final estado = await _abrir(tester, rol: UserRole.admin);
    expect(find.text('Gestión de usuarios y aulas'), findsOneWidget);
    await tester.tap(find.text('Aulas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aula de la autonomía'));
    await tester.pumpAndSettle();
    expect(find.text('Personal del aula'), findsOneWidget);
    // En la demostración Lucía ya está en el aula, así que el selector avisa
    // de que no quedan más candidatos; lo importante es que la sección está.
    expect(find.text('Alumnos del aula'), findsOneWidget);
    // La matrícula queda en manos del personal del aula.
    expect(find.text('Matricular alumno'), findsNothing);
    expect(
      find.textContaining('las gestiona el personal asignado'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _cerrar(tester, estado);
  });
}
