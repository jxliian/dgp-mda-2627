import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/validation.dart';
import '../state/app_state.dart';
import '../ui/components.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  late AccessSettings settings;
  late AccessSettings original;
  bool initialized = false, busy = false;
  String? error, message;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      original = AppScope.of(context).access.copy();
      settings = original.copy();
      initialized = true;
    }
  }

  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final state = AppScope.of(context);
    final user = state.user!;
    final changes = <String, dynamic>{
      if (user.role == UserRole.student)
        for (final entry in settings.toJson().entries)
          if (entry.value != original.values[entry.key]) entry.key: entry.value,
      if (password.text.isNotEmpty) 'password': password.text,
    };
    if (changes.isEmpty) {
      setState(() => message = 'No hay cambios para guardar.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      await state.repository.saveUser(changes, previous: user);
      if (password.text.isNotEmpty) {
        if (state.user != null) state.expire();
        return;
      }
      await state.refreshProfile();
      if (mounted) {
        setState(() {
          original = settings.copy();
          message = 'Tus ajustes se han guardado.';
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changePhoto() async {
    final state = AppScope.of(context);
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Imágenes PNG, JPEG o WebP',
            extensions: ['png', 'jpg', 'jpeg', 'webp'],
          ),
        ],
      );
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw StateError('La imagen no puede superar los 5 MB.');
      }
      if (!mounted) return;
      setState(() {
        busy = true;
        error = null;
        message = null;
      });
      await state.repository.uploadAvatar(await file.readAsBytes(), file.name);
      state.photoChanged();
      if (mounted) setState(() => message = 'Tu foto se ha actualizado.');
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.user;
    if (user == null) return const SizedBox.shrink();
    final canEdit =
        user.role != UserRole.student || user.access.flag('profile_mod');
    return PageShell(
      title: 'Mis ajustes',
      subtitle: user.displayName,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.role == UserRole.student) ...[
              Center(
                child: Column(
                  children: [
                    UserAvatar(user: user, size: 130),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy || !canEdit ? null : changePhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Cambiar mi foto'),
                    ),
                  ],
                ),
              ),
              if (!state.repository.supportsProfileRead)
                const Notice(
                  'El servidor todavía no permite consultar tus ajustes actuales. Solo se enviarán las opciones que cambies aquí.',
                ),
              if (!canEdit)
                const Notice(
                  'Tus ajustes están protegidos. Pide ayuda al administrador.',
                ),
              AccessEditor(settings: settings, enabled: canEdit && !busy),
            ],
            const SizedBox(height: 28),
            const Text(
              'Cambiar contraseña',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: password,
              obscureText: true,
              enabled: canEdit && !busy,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña (opcional)',
              ),
              validator: (v) => v!.isEmpty ? null : passwordError(v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: confirmation,
              obscureText: true,
              enabled: canEdit && !busy,
              decoration: const InputDecoration(
                labelText: 'Repite la nueva contraseña',
              ),
              validator: (v) =>
                  v == password.text ? null : 'Las contraseñas no coinciden.',
            ),
            const Text(
              'Después de cambiarla tendrás que iniciar sesión de nuevo.',
            ),
            if (error != null) Notice(error!, error: true),
            if (message != null) Notice(message!),
            FormActions(
              busy: busy || !canEdit,
              onSave: save,
              label: 'Guardar mis ajustes',
            ),
          ],
        ),
      ),
    );
  }
}

class AccessEditor extends StatefulWidget {
  const AccessEditor({
    super.key,
    required this.settings,
    this.permissions = false,
    this.enabled = true,
  });
  final AccessSettings settings;
  final bool permissions;
  final bool enabled;
  @override
  State<AccessEditor> createState() => _AccessEditorState();
}

class _AccessEditorState extends State<AccessEditor> {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      const Text(
        'Visualización y apoyos',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          for (final entry in {
            'main_col': 'Color de fondo',
            'sec_col': 'Color de los botones',
          }.entries)
            SizedBox(
              width: 260,
              child: TextFormField(
                initialValue: widget.settings.color(entry.key),
                enabled: widget.enabled,
                decoration: InputDecoration(
                  labelText: '${entry.value} (#RRGGBB)',
                ),
                validator: (v) =>
                    RegExp(
                      r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$',
                    ).hasMatch(v ?? '')
                    ? null
                    : 'Usa un color como #00695c.',
                onChanged: (v) =>
                    widget.settings.values['stud_access_${entry.key}'] = v,
              ),
            ),
          for (final entry in {
            'fontsize': 'Tamaño de letra',
            'ntasks_visible': 'Tareas por página',
            'ndays_visible': 'Días visibles',
          }.entries)
            SizedBox(
              width: 260,
              child: TextFormField(
                initialValue: '${widget.settings.number(entry.key)}',
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: entry.value,
                  helperText: entry.key == 'fontsize'
                      ? 'Entero mayor que cero'
                      : entry.key == 'ndays_visible'
                      ? '0: solo hoy; hasta 7 días por semana'
                      : '0: mostrar todas',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < (entry.key == 'fontsize' ? 1 : 0)
                      ? 'Escribe un entero válido.'
                      : null;
                },
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null) {
                    widget.settings.values['stud_access_${entry.key}'] = n;
                  }
                },
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      for (final entry in {
        'pictograms': 'Mostrar apoyos visuales',
        'contrast': 'Alto contraste',
        'filters': 'Mostrar filtros de tareas',
        'timebar': 'Mostrar temporizador',
        'talkback': 'Mostrar botones para escuchar',
        if (widget.permissions) ...{
          'prof_mod': 'Permiso de personalización avanzada',
          'profile_mod': 'Puede modificar su perfil',
          'task_mod': 'Puede crear y eliminar sus tareas',
        },
      }.entries)
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(entry.value),
          value: widget.settings.flag(entry.key),
          onChanged: widget.enabled
              ? (v) => setState(
                  () => widget.settings.values['stud_access_${entry.key}'] = v,
                )
              : null,
        ),
    ],
  );
}
