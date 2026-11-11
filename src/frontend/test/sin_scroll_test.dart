import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autovida/app.dart';
import 'package:autovida/models/domain.dart';
import 'package:autovida/services/demo_repository.dart';
import 'package:autovida/state/app_state.dart';

/// Las pantallas de alumno y de personal deben caber en una tablet sin tener
/// que desplazarlas. El desplazamiento sigue disponible como red de seguridad
/// (letra ampliada, móviles), pero en el tamaño objetivo no debe hacer falta.
///
/// Datos de demostración sin la banda de «modo demostración», para medir el
/// mismo espacio que habrá en la demostración contra el servidor real.
class _ComoEnProduccion extends DemoRepository {
  @override
  bool get isDemo => false;
}

Future<void> medir(WidgetTester t, String nombre,
    {UserRole? rol, Future<void> Function(WidgetTester)? luego}) async {
  t.view.physicalSize = const Size(1280, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final repo = _ComoEnProduccion();
  if (rol != null) {
    await repo.login(switch (rol) {
      UserRole.student => 'pablo', UserRole.parent => 'familia',
      UserRole.staff => 'lucia', UserRole.admin => 'admin',
    }, '1234', rol);
  }
  final estado = AppState(repository: repo);
  await t.pumpWidget(AutovidaApp(state: estado));
  await t.pumpAndSettle();
  if (luego != null) await luego(t);
  final scrollables = find.byType(Scrollable).evaluate();
  var sobra = 0.0;
  for (final e in scrollables) {
    final pos = (e.widget as Scrollable).controller?.position;
    if (pos != null && pos.hasContentDimensions) {
      if (pos.maxScrollExtent > sobra) sobra = pos.maxScrollExtent;
    }
  }
  // Alternativa fiable: el Scrollable principal de PageShell
  final estados = t.stateList<ScrollableState>(find.byType(Scrollable));
  for (final st in estados) {
    if (st.position.hasContentDimensions &&
        st.position.maxScrollExtent > sobra) {
      sobra = st.position.maxScrollExtent;
    }
  }
  expect(sobra, 0,
      reason: '$nombre necesita desplazarse ${sobra.toStringAsFixed(0)} px '
          'en una tablet de 1280x900');
  await t.pumpWidget(const SizedBox.shrink());
  estado.dispose();
}

void main() {
  testWidgets('portada', (t) => medir(t, 'Portada'));
  testWidgets('aulas', (t) => medir(t, 'Elegir aula', luego: (x) async {
    await x.tap(find.text('Soy alumno')); await x.pumpAndSettle();
  }));
  testWidgets('fotos', (t) => medir(t, 'Elegir alumno', luego: (x) async {
    await x.tap(find.text('Soy alumno')); await x.pumpAndSettle();
    await x.tap(find.text('Aula de la autonomía')); await x.pumpAndSettle();
  }));
  testWidgets('pin', (t) => medir(t, 'PIN', luego: (x) async {
    await x.tap(find.text('Soy alumno')); await x.pumpAndSettle();
    await x.tap(find.text('Aula de la autonomía')); await x.pumpAndSettle();
    await x.tap(find.text('Pablo García')); await x.pumpAndSettle();
  }));
  testWidgets('agenda', (t) => medir(t, 'Agenda alumno', rol: UserRole.student));
  testWidgets('detalle', (t) => medir(t, 'Detalle tarea', rol: UserRole.student,
      luego: (x) async {
    await x.tap(find.text('Preparar la mochila').first); await x.pumpAndSettle();
  }));
  testWidgets('aulas personal', (t) => medir(t, 'Aulas personal', rol: UserRole.staff));
  testWidgets('alumnos aula', (t) => medir(t, 'Alumnos del aula', rol: UserRole.staff,
      luego: (x) async {
    await x.tap(find.text('Aula de la autonomía')); await x.pumpAndSettle();
  }));
  testWidgets('familia', (t) => medir(t, 'Familia', rol: UserRole.parent));
}
