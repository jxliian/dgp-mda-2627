import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autovida/app.dart';
import 'package:autovida/models/domain.dart';
import 'package:autovida/services/demo_repository.dart';
import 'package:autovida/state/app_state.dart';
import 'package:autovida/ui/theme.dart';

/// Auditoría automática de accesibilidad (WCAG 2.2 AA).
///
/// Comprueba sobre la aplicación en marcha lo que se puede medir: contraste de
/// color, tamaño de los objetivos táctiles, nombre accesible de todo lo que se
/// puede pulsar y comportamiento con la letra ampliada.
void main() {
  group('Contraste de color', () {
    // Umbral AAA para texto normal; el proyecto se compromete a >7:1.
    const minimoTextoPrincipal = 7.0;
    // Umbral AA para texto de insignias y elementos de interfaz.
    const minimoTextoSecundario = 4.5;

    test('los textos sobre el fondo superan 7:1', () {
      expect(_contraste(Paleta.tinta, Paleta.lino), greaterThan(minimoTextoPrincipal));
      expect(_contraste(Paleta.tintaSuave, Paleta.lino), greaterThan(minimoTextoPrincipal));
      expect(_contraste(Paleta.bosque, Paleta.lino), greaterThan(minimoTextoPrincipal));
      expect(_contraste(Paleta.tinta, Paleta.papel), greaterThan(minimoTextoPrincipal));
      expect(_contraste(Paleta.tintaSuave, Paleta.papel), greaterThan(minimoTextoPrincipal));
    });

    test('el texto sobre los botones principales supera 7:1', () {
      expect(_contraste(Colors.white, Paleta.bosque), greaterThan(minimoTextoPrincipal));
    });

    test('los avisos y las insignias superan 4.5:1', () {
      expect(
        _contraste(Paleta.alertaTinta, Paleta.alertaSuave),
        greaterThan(minimoTextoSecundario),
      );
      expect(
        _contraste(Paleta.bosqueTinta, Paleta.bosqueSuave),
        greaterThan(minimoTextoSecundario),
      );
      expect(
        _contraste(Paleta.terracotaTinta, Paleta.terracotaSuave),
        greaterThan(minimoTextoSecundario),
      );
      expect(
        _contraste(Paleta.ambarTinta, Paleta.ambarSuave),
        greaterThan(minimoTextoSecundario),
      );
    });

    test('los bordes de los acentos se distinguen del fondo', () {
      // Componentes de interfaz: mínimo 3:1 (WCAG 1.4.11).
      expect(_contraste(Paleta.terracota, Paleta.lino), greaterThan(3));
      expect(_contraste(Paleta.ambarTinta, Paleta.ambarSuave), greaterThan(3));
      // Borde de los controles: debe distinguirse de sus dos fondos posibles.
      expect(_contraste(Paleta.trazoControl, Paleta.blanco), greaterThan(3));
      expect(_contraste(Paleta.trazoControl, Paleta.papel), greaterThan(3));
    });
  });

  group('Pantallas', () {
    for (final caso in _casos) {
      testWidgets('${caso.nombre}: todo lo pulsable tiene nombre y tamaño', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final estado = await _abrir(tester, caso);

        final problemas = <String>[];
        _recorrer(tester.binding.rootElement!.renderObject!.debugSemantics!, (
          nodo,
        ) {
          final datos = nodo.getSemanticsData();
          if (!_esPulsable(datos)) return;
          if (_nombre(datos).trim().isEmpty) {
            problemas.add('Sin nombre accesible en ${nodo.rect}');
          }
          final tamano = nodo.rect.size;
          if (math.min(tamano.width, tamano.height) < _objetivoMinimo) {
            problemas.add(
              'Objetivo táctil pequeño (${tamano.width.toStringAsFixed(0)}'
              'x${tamano.height.toStringAsFixed(0)}) en «${_nombre(datos)}»',
            );
          }
        });

        expect(problemas, isEmpty, reason: problemas.join('\n'));
        handle.dispose();
        await _cerrar(tester, estado);
      });

      testWidgets('${caso.nombre}: se dibuja con la letra al 200 %', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final estado = await _abrir(tester, caso, tamano: const Size(1280, 2400));
        expect(tester.takeException(), isNull);
        await _cerrar(tester, estado);
      });
    }
  });
}

/// Tamaño mínimo de un objetivo táctil (WCAG 2.2 AA pide 24 px; Material, 48).
const _objetivoMinimo = 48.0;

typedef _Caso = ({String nombre, UserRole? rol, String? pulsar});

const _casos = <_Caso>[
  (nombre: 'Inicio de sesión', rol: null, pulsar: null),
  (nombre: 'Agenda del alumno', rol: UserRole.student, pulsar: null),
  (
    nombre: 'Detalle de tarea',
    rol: UserRole.student,
    pulsar: 'Preparar la mochila',
  ),
  (nombre: 'Aulas del personal', rol: UserRole.staff, pulsar: null),
  (nombre: 'Familia', rol: UserRole.parent, pulsar: null),
  (nombre: 'Administración', rol: UserRole.admin, pulsar: null),
];

Future<AppState> _abrir(
  WidgetTester tester,
  _Caso caso, {
  Size tamano = const Size(1280, 1400),
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repositorio = DemoRepository();
  if (caso.rol != null) {
    await repositorio.login(_cuenta(caso.rol!), '1234', caso.rol!);
  }
  final estado = AppState(repository: repositorio);
  await tester.pumpWidget(AutovidaApp(state: estado));
  await tester.pumpAndSettle();
  if (caso.pulsar != null) {
    await tester.tap(find.text(caso.pulsar!).first);
    await tester.pumpAndSettle();
  }
  return estado;
}

Future<void> _cerrar(WidgetTester tester, AppState estado) async {
  await tester.pumpWidget(const SizedBox.shrink());
  estado.dispose();
}

String _cuenta(UserRole rol) => switch (rol) {
  UserRole.student => 'pablo',
  UserRole.parent => 'familia',
  UserRole.staff => 'lucia',
  UserRole.admin => 'admin',
};

void _recorrer(SemanticsNode nodo, void Function(SemanticsNode) visita) {
  visita(nodo);
  nodo.visitChildren((hijo) {
    _recorrer(hijo, visita);
    return true;
  });
}

bool _esPulsable(SemanticsData datos) =>
    datos.hasAction(SemanticsAction.tap) &&
    !datos.flagsCollection.isTextField &&
    !datos.flagsCollection.isHidden;

String _nombre(SemanticsData datos) =>
    [datos.label, datos.tooltip, datos.value].where((t) => t.isNotEmpty).join(' ');

/// Relación de contraste según WCAG 2.x.
double _contraste(Color a, Color b) {
  final luminanciaA = a.computeLuminance();
  final luminanciaB = b.computeLuminance();
  final clara = math.max(luminanciaA, luminanciaB);
  final oscura = math.min(luminanciaA, luminanciaB);
  return (clara + 0.05) / (oscura + 0.05);
}
