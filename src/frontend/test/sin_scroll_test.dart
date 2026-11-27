import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autovida/app.dart';
import 'package:autovida/models/domain.dart';
import 'package:autovida/services/demo_repository.dart';
import 'package:autovida/state/app_state.dart';

/// Las pantallas de alumno y de personal deben caber en una tablet sin tener
/// que desplazarlas, **en las dos orientaciones**: el centro trabaja con
/// tabletas de 10 pulgadas, 1280x800 apaisadas y 800x1280 verticales. El
/// desplazamiento sigue disponible como red de seguridad (letra ampliada,
/// móviles), pero en el tamaño objetivo no debe hacer falta.
///
/// Datos de demostración sin la banda de «modo demostración», para medir el
/// mismo espacio que habrá en la demostración contra el servidor real.
class _ComoEnProduccion extends DemoRepository {
  @override
  bool get isDemo => false;
}

/// Las dos orientaciones de la tablet del centro.
const tabletas = {
  'apaisada': Size(1280, 800),
  'vertical': Size(800, 1280),
};

Future<void> medir(WidgetTester t, String nombre,
    {UserRole? rol, Future<void> Function(WidgetTester)? luego,
    void Function(DemoRepository)? conCuenta, int? letra,
    Size tamano = const Size(1280, 800)}) async {
  t.view.physicalSize = tamano;
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
  if (letra != null) {
    repo.currentUser!.access.values['stud_access_fontsize'] = letra;
  }
  conCuenta?.call(repo);
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
  expect(t.takeException(), isNull,
      reason: '$nombre desborda en ${tamano.width.toInt()}x'
          '${tamano.height.toInt()}');
  expect(sobra, 0,
      reason: '$nombre necesita desplazarse ${sobra.toStringAsFixed(0)} px '
          'en una tablet de ${tamano.width.toInt()}x${tamano.height.toInt()}');
  await t.pumpWidget(const SizedBox.shrink());
  estado.dispose();
}

void main() {
  // El alumno puede subir la letra hasta «Enorme». Tampoco entonces debería
  // tener que desplazar: si no cupiera, la aplicación deja de servirle justo
  // a quien más la necesita.
  group('letra enorme', () {
    const tamano = Size(1280, 800);
    testWidgets('agenda', (t) => medir(t, 'Agenda con letra enorme',
        rol: UserRole.student, tamano: tamano, letra: 32));
    testWidgets('detalle', (t) => medir(t, 'Tarea con letra enorme',
        rol: UserRole.student, tamano: tamano, letra: 32, luego: (x) async {
      await x.tap(find.text('Preparar la mochila').first);
      await x.pumpAndSettle();
    }));
    testWidgets('elegir dia', (t) => medir(t, 'Elegir día con letra enorme',
        rol: UserRole.student, tamano: tamano, letra: 32, luego: (x) async {
      await x.tap(find.text('Elegir día')); await x.pumpAndSettle();
    }));
    testWidgets('accesibilidad', (t) => medir(t, 'Accesibilidad con letra enorme',
        rol: UserRole.student, tamano: tamano, letra: 32,
        conCuenta: (r) =>
            r.currentUser!.access.values['stud_access_profile_mod'] = true,
        luego: (x) async {
      await x.tap(find.byTooltip('Ajustes')); await x.pumpAndSettle();
      await x.tap(find.text('Accesibilidad'));
      await x.pumpAndSettle();
    }));
  });

  tabletas.forEach((orientacion, tamano) {
    group('tablet $orientacion', () {
      testWidgets('portada', (t) => medir(t, 'Portada', tamano: tamano));
      testWidgets('aulas', (t) => medir(t, 'Elegir aula', tamano: tamano,
          luego: (x) async {
        await x.tap(find.text('Soy alumno')); await x.pumpAndSettle();
      }));
      testWidgets('fotos', (t) => medir(t, 'Elegir alumno', tamano: tamano,
          luego: (x) async {
        await x.tap(find.text('Soy alumno')); await x.pumpAndSettle();
        await x.tap(find.text('Aula de la autonomía')); await x.pumpAndSettle();
      }));
      testWidgets('pin', (t) => medir(t, 'PIN', tamano: tamano,
          luego: (x) async {
        await x.tap(find.text('Soy alumno')); await x.pumpAndSettle();
        await x.tap(find.text('Aula de la autonomía')); await x.pumpAndSettle();
        await x.tap(find.text('Pablo García')); await x.pumpAndSettle();
      }));
      testWidgets('agenda', (t) => medir(t, 'Agenda alumno',
          rol: UserRole.student, tamano: tamano));
      testWidgets('detalle', (t) => medir(t, 'Detalle tarea',
          rol: UserRole.student, tamano: tamano, luego: (x) async {
        await x.tap(find.text('Preparar la mochila').first);
        await x.pumpAndSettle();
      }));
      // De base el alumno no entra en sus ajustes: se le habilita.
      testWidgets('accesibilidad', (t) => medir(t, 'Accesibilidad del alumno',
          rol: UserRole.student, tamano: tamano,
          conCuenta: (r) =>
              r.currentUser!.access.values['stud_access_profile_mod'] = true,
          luego: (x) async {
        // Los ajustes se abren desde la foto de la barra.
        await x.tap(find.byTooltip('Ajustes')); await x.pumpAndSettle();
        await x.tap(find.text('Accesibilidad'));
        await x.pumpAndSettle();
      }));
      testWidgets('elegir dia', (t) => medir(t, 'Elegir día',
          rol: UserRole.student, tamano: tamano, luego: (x) async {
        await x.tap(find.text('Elegir día')); await x.pumpAndSettle();
      }));
      testWidgets('mis ajustes', (t) => medir(t, 'Mis ajustes',
          rol: UserRole.student, tamano: tamano,
          conCuenta: (r) =>
              r.currentUser!.access.values['stud_access_profile_mod'] = true,
          luego: (x) async {
        await x.tap(find.byTooltip('Ajustes')); await x.pumpAndSettle();
      }));
      testWidgets('colores', (t) => medir(t, 'Colores de la agenda',
          rol: UserRole.student, tamano: tamano,
          conCuenta: (r) =>
              r.currentUser!.access.values['stud_access_profile_mod'] = true,
          luego: (x) async {
        await x.tap(find.byTooltip('Ajustes')); await x.pumpAndSettle();
        await x.tap(find.text('Accesibilidad'));
        await x.pumpAndSettle();
        await x.tap(find.text('Colores')); await x.pumpAndSettle();
      }));
      testWidgets('anadir tarea', (t) => medir(t, 'Añadir mi tarea',
          rol: UserRole.student, tamano: tamano,
          conCuenta: (r) =>
              r.currentUser!.access.values['stud_access_task_mod'] = true,
          luego: (x) async {
        await x.tap(find.text('Añadir mi tarea')); await x.pumpAndSettle();
      }));
      testWidgets('aulas personal', (t) => medir(t, 'Aulas personal',
          rol: UserRole.staff, tamano: tamano));
      testWidgets('alumnos aula', (t) => medir(t, 'Alumnos del aula',
          rol: UserRole.staff, tamano: tamano, luego: (x) async {
        await x.tap(find.text('Aula de la autonomía')); await x.pumpAndSettle();
      }));
      testWidgets('familia', (t) => medir(t, 'Familia',
          rol: UserRole.parent, tamano: tamano));
    });
  });
}
