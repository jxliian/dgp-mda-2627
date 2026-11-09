import 'package:flutter/material.dart';
import '../../state/app_state.dart';
import '../theme.dart';

/// Armazón común de todas las pantallas: avisos de estado arriba, cabecera con
/// título, contenido desplazable centrado y, si procede, barra de navegación.
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
    this.footer,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (state.demo) const AvisoBanda(_textoDemostracion),
            if (state.repository.offline || state.repository.pendingChanges > 0)
              const SyncBanner(),
            _Cabecera(title: title, subtitle: subtitle, actions: actions),
            Expanded(child: _Contenido(child: child)),
            if (footer != null) _PieDePagina(child: footer!),
          ],
        ),
      ),
    );
  }

  static const _textoDemostracion =
      'Modo demostración · Datos de prueba · Los cambios duran solo esta sesión';
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.title, this.subtitle, this.actions = const []});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: Medidas.trazo),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      // Disposición de los bocetos: volver a la izquierda, título centrado y
      // las acciones de la sesión a la derecha.
      child: Row(
        children: [
          if (Navigator.canPop(context))
            OutlinedButton.icon(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Volver'),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, restricciones) => SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: restricciones.maxWidth < 600 ? 18 : 48,
        vertical: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Medidas.anchoMaximo),
          child: child,
        ),
      ),
    ),
  );
}

class _PieDePagina extends StatelessWidget {
  const _PieDePagina({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: Medidas.trazo),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: child,
    );
  }
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
