import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/validation.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'access_editor.dart';

/// Ajustes de la propia cuenta: foto, apoyos visuales y contraseña.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _maximoBytesDeFoto = 5 * 1024 * 1024;

  final form = GlobalKey<FormState>();
  final contrasena = TextEditingController();
  final repeticion = TextEditingController();
  late AccessSettings ajustes;
  late AccessSettings ajustesOriginales;
  bool inicializado = false;
  bool ocupado = false;
  String? aviso;
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!inicializado) {
      ajustesOriginales = AppScope.of(context).access.copy();
      ajustes = ajustesOriginales.copy();
      inicializado = true;
    }
  }

  @override
  void dispose() {
    contrasena.dispose();
    repeticion.dispose();
    super.dispose();
  }

  /// Un alumno solo edita su perfil si tiene el permiso correspondiente.
  bool get puedeEditar {
    final usuario = AppScope.of(context).user!;
    return usuario.role != UserRole.student ||
        usuario.access.flag('profile_mod');
  }

  Json _cambios(AppUser usuario) => {
    if (usuario.role == UserRole.student)
      for (final entrada in ajustes.toJson().entries)
        if (entrada.value != ajustesOriginales.values[entrada.key])
          entrada.key: entrada.value,
    if (contrasena.text.isNotEmpty) 'password': contrasena.text,
  };

  Future<void> guardar() async {
    if (!form.currentState!.validate()) return;
    final state = AppScope.of(context);
    final cambios = _cambios(state.user!);
    if (cambios.isEmpty) {
      setState(() => aviso = 'No hay cambios para guardar.');
      return;
    }
    setState(() {
      ocupado = true;
      error = null;
      aviso = null;
    });
    try {
      await state.repository.saveUser(cambios, previous: state.user);
      // Cambiar la contraseña invalida la sesión: hay que volver a entrar.
      if (contrasena.text.isNotEmpty) {
        state.expire();
        return;
      }
      await state.refreshProfile();
      if (mounted) {
        setState(() {
          ajustesOriginales = ajustes.copy();
          aviso = 'Tus ajustes se han guardado.';
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> cambiarFoto() async {
    final state = AppScope.of(context);
    try {
      final archivo = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Imágenes PNG, JPEG o WebP',
            extensions: ['png', 'jpg', 'jpeg', 'webp'],
          ),
        ],
      );
      if (archivo == null) return;
      if (await archivo.length() > _maximoBytesDeFoto) {
        throw StateError('La imagen no puede superar los 5 MB.');
      }
      if (!mounted) return;
      setState(() {
        ocupado = true;
        error = null;
        aviso = null;
      });
      await state.repository.uploadAvatar(
        await archivo.readAsBytes(),
        archivo.name,
      );
      state.photoChanged();
      if (mounted) setState(() => aviso = 'Tu foto se ha actualizado.');
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final usuario = state.user;
    if (usuario == null) return const SizedBox.shrink();
    return PageShell(
      title: 'Mis ajustes',
      subtitle: usuario.displayName,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (usuario.role == UserRole.student) ..._seccionDeAlumno(usuario),
            const SectionTitle(
              'Cambiar contraseña',
              hint: 'Déjala vacía si no quieres cambiarla.',
            ),
            _campoContrasena(),
            const SizedBox(height: 16),
            _campoRepeticion(),
            const SizedBox(height: 8),
            Text(
              'Después de cambiarla tendrás que iniciar sesión de nuevo.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (error != null) Notice(error!, error: true),
            if (aviso != null) Notice(aviso!),
            FormActions(
              busy: ocupado || !puedeEditar,
              onSave: guardar,
              label: 'Guardar mis ajustes',
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _seccionDeAlumno(AppUser usuario) => [
    Center(
      child: Column(
        children: [
          UserAvatar(user: usuario, size: 130),
          const SizedBox(height: 12),
          if (AppScope.of(context).repository.canSetOwnAvatar)
            OutlinedButton.icon(
              onPressed: ocupado || !puedeEditar ? null : cambiarFoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Cambiar mi foto'),
            )
          else
            const Notice(_laFotoLaCambiaElCentro),
        ],
      ),
    ),
    if (!AppScope.of(context).repository.supportsProfileRead)
      const Notice(_servidorSinLecturaDePerfil),
    if (!puedeEditar) const Notice(_ajustesProtegidos),
    AccessEditor(settings: ajustes, enabled: puedeEditar && !ocupado),
  ];

  Widget _campoContrasena() => TextFormField(
    controller: contrasena,
    obscureText: true,
    enabled: puedeEditar && !ocupado,
    decoration: const InputDecoration(labelText: 'Nueva contraseña (opcional)'),
    validator: (valor) => valor!.isEmpty ? null : passwordError(valor),
  );

  Widget _campoRepeticion() => TextFormField(
    controller: repeticion,
    obscureText: true,
    enabled: puedeEditar && !ocupado,
    decoration: const InputDecoration(labelText: 'Repite la nueva contraseña'),
    validator: (valor) =>
        valor == contrasena.text ? null : 'Las contraseñas no coinciden.',
  );

  static const _laFotoLaCambiaElCentro =
      'Tu foto la cambia la administración del centro.';
  static const _servidorSinLecturaDePerfil =
      'El servidor todavía no permite consultar tus ajustes actuales. '
      'Solo se enviarán las opciones que cambies aquí.';
  static const _ajustesProtegidos =
      'Tus ajustes están protegidos. Pide ayuda al administrador.';
}
