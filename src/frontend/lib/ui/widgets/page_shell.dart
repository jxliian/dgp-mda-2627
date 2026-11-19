import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import 'bar_action.dart';
import 'icon_action.dart';
import 'session_actions.dart';

/// Armazón común de todas las pantallas: avisos de estado arriba, una única
/// barra con el título y todas las acciones, y el contenido centrado debajo.
///
/// Hay una sola barra, siempre arriba y siempre con el mismo orden: volver a
/// la izquierda, el título en el centro y, a la derecha, primero las acciones
/// de la pantalla y después las de la sesión. Antes había dos barras, una
/// arriba y otra abajo, y las acciones cambiaban de sitio según la pantalla.
///
/// El título se marca como cabecera de la página para los lectores de pantalla
/// y el botón de volver aparece solo cuando hay sitio al que volver.
class PageShell extends StatelessWidget {
  const PageShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.session = true,
  });

  final String title;
  final Widget child;
  final String? subtitle;

  /// Acciones propias de la pantalla. Van en la barra, antes de las de sesión.
  final List<Widget> actions;

  /// Si la barra incluye inicio, ajustes y salir. Se apaga en las pantallas
  /// que todavía no tienen sesión iniciada.
  final bool session;

  /// Ancho a partir del cual la barra se queda fija arriba. Por debajo viaja
  /// con el contenido: en un móvil con la letra muy ampliada, una barra fija
  /// con título y acciones se comería la pantalla entera.
  static const _anchoParaBarraFija = 760.0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final barra = _Barra(
      title: title,
      subtitle: subtitle,
      actions: actions,
      session: session && state.user != null,
    );
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, restricciones) {
            final fija = restricciones.maxWidth >= _anchoParaBarraFija;
            return Column(
              children: [
                if (state.demo) const AvisoBanda(_textoDemostracion),
                if (state.repository.offline ||
                    state.repository.pendingChanges > 0)
                  const SyncBanner(),
                if (fija) barra,
                Expanded(
                  child: _Contenido(
                    header: fija ? null : barra,
                    child: child,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static const _textoDemostracion =
      'Modo demostración · Datos de prueba · Los cambios duran solo esta sesión';
}

/// Identifica la barra única de la pantalla; las pruebas la miden con ella.
const barraDePagina = ValueKey('barra-de-pagina');

class _Barra extends StatelessWidget {
  const _Barra({
    required this.title,
    required this.session,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool session;

  /// Ancho a partir del cual caben los botones con su texto.
  static const _anchoParaTexto = 760.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: barraDePagina,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: Medidas.trazo),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: LayoutBuilder(
        builder: (context, restricciones) {
          final estrecha = restricciones.maxWidth < _anchoParaTexto;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (Navigator.canPop(context)) ...[
                _volver(context, estrecha),
                const SizedBox(width: 14),
              ],
              Expanded(flex: 4, child: _titulo(context)),
              // Las acciones se reparten en varias líneas antes que
              // estrecharse: con la letra muy ampliada no caben todas en una
              // sola fila.
              Flexible(
                flex: 6,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...actions,
                      if (session) SessionActions(compact: estrecha),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _volver(BuildContext context, bool estrecha) => estrecha
      ? IconAction(
          icon: Icons.arrow_back,
          label: 'Volver',
          onPressed: () => Navigator.maybePop(context),
        )
      : BarAction(
          icon: Icons.arrow_back,
          label: 'Volver',
          onPressed: () => Navigator.maybePop(context),
        );

  Widget _titulo(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
      if (subtitle != null)
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
    ],
  );
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.child, this.header});

  final Widget child;

  /// Barra que viaja con el contenido cuando no cabe fija.
  final Widget? header;

  static const _margenVertical = 18.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, restricciones) {
      final relleno = EdgeInsets.symmetric(
        horizontal: restricciones.maxWidth < 600 ? 18 : 48,
        vertical: _margenVertical,
      );
      // Reservando la altura del hueco, el contenido queda centrado cuando
      // cabe y se desplaza solo cuando no cabe. Con la letra muy ampliada en
      // un móvil, la cabecera puede dejar un hueco mínimo: de ahí que se acote
      // a cero en vez de restar sin más.
      final alturaDisponible = restricciones.maxHeight.isFinite
          ? (restricciones.maxHeight - _margenVertical * 2).clamp(
              0.0,
              double.infinity,
            )
          : 0.0;
      final cuerpo = Padding(
        padding: relleno,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: header == null ? alturaDisponible : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Medidas.anchoMaximo),
              child: child,
            ),
          ),
        ),
      );
      return SingleChildScrollView(
        child: header == null
            ? cuerpo
            : Column(children: [header!, cuerpo]),
      );
    },
  );
}

/// Banda de aviso cálida en la parte superior de la pantalla.
class AvisoBanda extends StatelessWidget {
  const AvisoBanda(this.message, {super.key, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: Paleta.ambarSuave,
      border: Border(
        bottom: BorderSide(color: Paleta.ambarTinta, width: Medidas.trazoGrueso),
      ),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 14,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Paleta.ambarTinta,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        ?action,
      ],
    ),
  );
}

/// Aviso de trabajo sin conexión, con el botón para reenviar los cambios.
class SyncBanner extends StatefulWidget {
  const SyncBanner({super.key});

  @override
  State<SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends State<SyncBanner> {
  bool enviando = false;
  String? error;

  Future<void> sincronizar() async {
    final state = AppScope.of(context);
    setState(() {
      enviando = true;
      error = null;
    });
    try {
      await state.synchronize();
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = AppScope.of(context).repository.pendingChanges;
    return AvisoBanda(
      error ?? 'Sin conexión · $pendientes cambios pendientes de enviar',
      action: TextButton(
        onPressed: enviando ? null : sincronizar,
        child: Text(enviando ? 'Enviando…' : 'Sincronizar'),
      ),
    );
  }
}
