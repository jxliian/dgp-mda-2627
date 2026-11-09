import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/domain.dart';
import '../state/app_state.dart';

const ink = Color(0xff203b38);
const teal = Color(0xff00695c);
const canvas = Color(0xfff7faf8);

Color parseColor(String value) {
  var hex = value.replaceFirst('#', '');
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  return Color(int.parse('ff$hex', radix: 16));
}

ThemeData appTheme(AccessSettings settings, {bool student = false}) {
  final highContrast = student && settings.flag('contrast');
  final background = highContrast
      ? Colors.white
      : student
      ? parseColor(settings.color('main_col'))
      : canvas;
  var accent = highContrast
      ? Colors.black
      : student
      ? parseColor(settings.color('sec_col'))
      : teal;
  // Custom colours cannot make primary buttons unreadable.
  if (accent.computeLuminance() > .45) accent = teal;
  final dark = background.computeLuminance() < .179;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: accent,
        onPrimary: accent.computeLuminance() > .179
            ? Colors.black
            : Colors.white,
        surface: background,
        onSurface: dark
            ? Colors.white
            : student
            ? Colors.black
            : ink,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    textTheme: ThemeData(brightness: scheme.brightness).textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff22352f) : const Color(0xffedf3ef),
      contentPadding: const EdgeInsets.all(18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: highContrast ? Colors.black : const Color(0xff92aaa2),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(56, 56),
        padding: const EdgeInsets.all(16),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
    ),
    visualDensity: VisualDensity.standard,
  );
}

Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
void goHome(BuildContext context) =>
    Navigator.of(context).popUntil((route) => route.isFirst);

class Brand extends StatelessWidget {
  const Brand({super.key, this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: EdgeInsets.all(large ? 18 : 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.spa_outlined,
          size: large ? 44 : 27,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      const SizedBox(width: 12),
      Text(
        'AUTOVIDA',
        style: TextStyle(
          fontSize: large ? 28 : 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    ],
  );
}

class PageShell extends StatelessWidget {
  const PageShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.footer,
    this.showBack = true,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final Widget? footer;
  final bool showBack;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (state.demo)
              Container(
                width: double.infinity,
                color: const Color(0xffffedc4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                child: const Text(
                  'DEMOSTRACIÓN · Datos ficticios · Los cambios se guardan solo durante esta prueba',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xff654300), fontSize: 13),
                ),
              ),
            if (state.repository.offline || state.repository.pendingChanges > 0)
              const SyncBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  if (showBack && Navigator.canPop(context)) ...[
                    IconButton.filledTonal(
                      tooltip: 'Volver',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (subtitle != null)
                          Text(subtitle!, style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth < 600 ? 18 : 48,
                    vertical: 20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
            if (footer != null)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

class SyncBanner extends StatefulWidget {
  const SyncBanner({super.key});
  @override
  State<SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends State<SyncBanner> {
  bool busy = false;
  String? error;
  Future<void> sync() async {
    final state = AppScope.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await state.synchronize();
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Container(
      width: double.infinity,
      color: const Color(0xffffedc4),
      padding: const EdgeInsets.all(12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            error ??
                'Sin conexión · ${state.repository.pendingChanges} cambios pendientes de enviar',
            style: const TextStyle(color: Color(0xff654300), fontSize: 14),
          ),
          TextButton(
            onPressed: busy ? null : sync,
            child: Text(busy ? 'Enviando…' : 'Sincronizar'),
          ),
        ],
      ),
    );
  }
}

class Notice extends StatelessWidget {
  const Notice(this.message, {super.key, this.error = false, this.action});
  final String message;
  final bool error;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: error ? const Color(0xffffece9) : const Color(0xffe3f2ea),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: error ? const Color(0xffa63423) : const Color(0xff457558),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                error ? Icons.error_outline : Icons.info_outline,
                color: error ? const Color(0xff8c281a) : ink,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: error ? const Color(0xff8c281a) : ink,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: action),
        ],
      ),
    ),
  );
}

class LoadPanel<T> extends StatefulWidget {
  const LoadPanel({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(T data) builder;
  @override
  State<LoadPanel<T>> createState() => _LoadPanelState<T>();
}

class _LoadPanelState<T> extends State<LoadPanel<T>> {
  late Future<T> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Notice(
          snapshot.error.toString(),
          error: true,
          action: OutlinedButton.icon(
            onPressed: () => setState(() => future = widget.load()),
            icon: const Icon(Icons.refresh),
            label: const Text('Volver a intentar'),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(48),
          child: Center(
            child: CircularProgressIndicator(semanticsLabel: 'Cargando'),
          ),
        );
      }
      return widget.builder(snapshot.data as T);
    },
  );
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.leading,
    this.color,
    this.vertical = false,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? leading;
  final Color? color;
  final bool vertical;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final stacked = vertical || narrow;
    final picture =
        leading ??
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: vertical ? 68 : 40, color: scheme.onSurface),
        );
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: stacked ? TextAlign.center : TextAlign.start,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            textAlign: stacked ? TextAlign.center : TextAlign.start,
          ),
        ],
      ],
    );
    final body = Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: stacked
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ExcludeSemantics(child: picture),
                    const SizedBox(height: 20),
                    text,
                  ],
                )
              : Row(
                  children: [
                    ExcludeSemantics(child: picture),
                    const SizedBox(width: 22),
                    Expanded(child: text),
                    if (trailing == null && onTap != null)
                      const Icon(Icons.chevron_right),
                  ],
                ),
        ),
      ),
    );
    return Card(
      elevation: 0,
      color: color ?? scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                body,
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailing,
                    ),
                  ),
              ],
            )
          : Row(
              children: [
                Expanded(child: body),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: trailing!,
                  ),
              ],
            ),
    );
  }
}

class PagedItems<T> extends StatefulWidget {
  const PagedItems({
    super.key,
    required this.items,
    required this.builder,
    this.pageSize = 3,
    this.grid = false,
    this.empty = 'No hay elementos para mostrar.',
  });
  final List<T> items;
  final Widget Function(T item) builder;
  final int pageSize;
  final bool grid;
  final String empty;
  @override
  State<PagedItems<T>> createState() => _PagedItemsState<T>();
}

class _PagedItemsState<T> extends State<PagedItems<T>> {
  int page = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return Notice(widget.empty);
    final size = widget.pageSize < 1 ? 1 : widget.pageSize;
    final pages = (widget.items.length / size).ceil();
    if (page >= pages) page = pages - 1;
    final items = widget.items.skip(page * size).take(size).toList();
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            if (!widget.grid) {
              return Column(children: items.map(widget.builder).toList());
            }
            final columns = (c.maxWidth / 250).floor().clamp(1, 4);
            final width = (c.maxWidth - (columns - 1) * 18) / columns;
            return Wrap(
              spacing: 18,
              runSpacing: 8,
              children: items
                  .map(
                    (item) =>
                        SizedBox(width: width, child: widget.builder(item)),
                  )
                  .toList(),
            );
          },
        ),
        if (pages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Página anterior',
                  onPressed: page > 0 ? () => setState(() => page--) : null,
                  icon: const Icon(Icons.chevron_left, size: 34),
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      'Página ${page + 1} de $pages',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Página siguiente',
                  onPressed: page < pages - 1
                      ? () => setState(() => page++)
                      : null,
                  icon: const Icon(Icons.chevron_right, size: 34),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class UserAvatar extends StatefulWidget {
  const UserAvatar({super.key, required this.user, this.size = 72});
  final AppUser user;
  final double size;
  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Future<Uint8List?>? future;
  int version = -1;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    if (version != state.avatarVersion) {
      version = state.avatarVersion;
      _load(state);
    }
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.username != widget.user.username) {
      _load(AppScope.of(context));
    }
  }

  void _load(AppState state) {
    final own = state.user?.username == widget.user.username;
    final allowed =
        state.demo ||
        own ||
        (widget.user.avatarUrl?.startsWith('/auth/student-directory/') ??
            false) ||
        (state.user?.role == UserRole.staff ||
            state.user?.role == UserRole.parent ||
            state.user?.role == UserRole.admin);
    future = allowed
        ? state.repository.avatar(widget.user)
        : Future.value(null);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Foto de ${widget.user.displayName}',
    image: true,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: FutureBuilder<Uint8List?>(
          future: future,
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes != null) {
              if (String.fromCharCodes(bytes.take(100)).contains('<svg')) {
                return SvgPicture.memory(bytes, fit: BoxFit.cover);
              }
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              );
            }
            return _placeholder();
          },
        ),
      ),
    ),
  );
  Widget _placeholder() => Container(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Icon(
      Icons.person_outline,
      size: widget.size * .65,
      color: Theme.of(context).colorScheme.onPrimaryContainer,
    ),
  );
}

class FormActions extends StatelessWidget {
  const FormActions({
    super.key,
    required this.busy,
    required this.onSave,
    this.label = 'Guardar',
  });
  final bool busy;
  final VoidCallback onSave;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 24,
      runSpacing: 12,
      children: [
        OutlinedButton.icon(
          onPressed: busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          label: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: busy ? null : onSave,
          icon: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(busy ? 'Guardando…' : label),
        ),
      ],
    ),
  );
}

Future<bool> confirmDelete(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ) ??
    false;

class SpeechButton extends StatefulWidget {
  const SpeechButton({super.key, required this.text});
  final String text;
  @override
  State<SpeechButton> createState() => _SpeechButtonState();
}

class _SpeechButtonState extends State<SpeechButton> {
  final FlutterTts tts = FlutterTts();
  String? error;
  Future<void> speak() async {
    try {
      await tts.setLanguage('es-ES');
      await tts.setSpeechRate(.42);
      final result = await tts.speak(widget.text);
      if (result == 0) throw StateError('No voice');
      if (mounted) setState(() => error = null);
    } on Object {
      if (mounted) {
        setState(
          () => error =
              'La lectura en voz no está disponible en este dispositivo.',
        );
      }
    }
  }

  @override
  void dispose() {
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton.filledTonal(
        tooltip: 'Escuchar',
        onPressed: speak,
        icon: const Icon(Icons.volume_up_outlined),
      ),
      if (error != null)
        SizedBox(
          width: 170,
          child: Text(error!, style: const TextStyle(fontSize: 12)),
        ),
    ],
  );
}

IconData taskIcon(String title) {
  final value = title.toLowerCase();
  if (value.contains('mochila')) return Icons.backpack_outlined;
  if (value.contains('planta') || value.contains('regar')) {
    return Icons.local_florist_outlined;
  }
  if (value.contains('leer') || value.contains('cuento')) {
    return Icons.menu_book_outlined;
  }
  if (value.contains('comer') || value.contains('comedor')) {
    return Icons.restaurant_outlined;
  }
  if (value.contains('copia')) return Icons.print_outlined;
  return Icons.checklist_outlined;
}

class ContentPicture extends StatelessWidget {
  const ContentPicture({
    super.key,
    this.bytes,
    required this.icon,
    this.size = 90,
  });
  final Uint8List? bytes;
  final IconData icon;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      width: size,
      height: size,
      child: bytes != null
          ? Image.memory(bytes!, fit: BoxFit.cover)
          : ColoredBox(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                icon,
                size: size * .55,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
    ),
  );
}
