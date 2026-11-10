import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/validation.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'access_editor.dart';
import 'associations_screen.dart';

/// Alta y edición de cuentas (SCRUM-8 y SCRUM-9).
class UserEditorScreen extends StatefulWidget {
  const UserEditorScreen({super.key, this.user});

  /// Cuenta existente que se edita; `null` al crear una nueva.
  final AppUser? user;

  @override
  State<UserEditorScreen> createState() => _UserEditorScreenState();
}

class _UserEditorScreenState extends State<UserEditorScreen> {
  final form = GlobalKey<FormState>();
  final usuario = TextEditingController();
  final nombre = TextEditingController();
  final correo = TextEditingController();
  final contrasena = TextEditingController();
  final repeticion = TextEditingController();
  late UserRole rol;
  late AccessSettings ajustes;
  bool guardando = false;
  String? error;
  String? aviso;

  /// Cambiar la foto de otra persona depende de que el servidor lo ofrezca.
  bool get puedeCambiarLaFoto =>
      !esNueva &&
      esAlumno &&
      AppScope.of(context).repository.canSetAvatarOf;

  bool get esNueva => widget.user == null;
  bool get esAlumno => rol == UserRole.student;

  @override
  void initState() {
    super.initState();
    final cuenta = widget.user;
    usuario.text = cuenta?.username ?? '';
    nombre.text = cuenta?.fullName ?? '';
    correo.text = cuenta?.email ?? '';
    rol = cuenta?.role ?? UserRole.student;
    ajustes = cuenta?.access.copy() ?? AccessSettings();
  }

  @override
  void dispose() {
    usuario.dispose();
    nombre.dispose();
    correo.dispose();
    contrasena.dispose();
    repeticion.dispose();
    super.dispose();
  }

  Json _datosParaGuardar() => {
    'username': usuario.text.trim(),
    'full_name': nombre.text.trim(),
    if (esNueva) 'role': rol.name,
    if (contrasena.text.isNotEmpty) 'password': contrasena.text,
    if (esAlumno) ...ajustes.toJson() else 'email': correo.text.trim(),
  };

  Future<void> guardar() async {
    if (!form.currentState!.validate()) return;
    final state = AppScope.of(context);
    setState(() {
      guardando = true;
      error = null;
    });
    try {
      await state.repository.saveUser(_datosParaGuardar(), previous: widget.user);
      final esLaPropia = widget.user?.username == state.user?.username;
      if (state.user != null && esLaPropia) await state.refreshProfile();
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  /// SCRUM-329: administración cambia la foto de perfil de un alumno.
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
        guardando = true;
        error = null;
        aviso = null;
      });
      await state.repository.uploadAvatarOf(
        widget.user!,
        await archivo.readAsBytes(),
        archivo.name,
      );
      state.photoChanged();
      if (mounted) setState(() => aviso = 'La foto se ha actualizado.');
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  static const _maximoBytesDeFoto = 5 * 1024 * 1024;

  @override
  Widget build(BuildContext context) => PageShell(
    title: esNueva ? 'Crear usuario' : 'Modificar usuario',
    subtitle: 'Administración',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.user?.role == UserRole.student) _fotoDelAlumno(),
          const SectionTitle('Datos de la cuenta'),
          _campoUsuario(),
          const SizedBox(height: 18),
          _campoNombre(),
          const SizedBox(height: 18),
          _campoRol(),
          if (!esAlumno) ...[const SizedBox(height: 18), _campoCorreo()],
          const SectionTitle(
            'Contraseña',
            hint: 'Al modificar una cuenta, déjala vacía para no cambiarla.',
          ),
          _campoContrasena(),
          const SizedBox(height: 18),
          _campoRepeticion(),
          if (esAlumno)
            AccessEditor(settings: ajustes, permissions: true, enabled: !guardando),
          _asociaciones(),
          if (error != null) Notice(error!, error: true),
          if (aviso != null) Notice(aviso!),
          FormActions(busy: guardando, onSave: guardar, label: 'Guardar usuario'),
        ],
      ),
    ),
  );

  Widget _fotoDelAlumno() => Center(
    child: Column(
      children: [
        UserAvatar(user: widget.user!, size: 140),
        const SizedBox(height: 12),
        if (puedeCambiarLaFoto)
          OutlinedButton.icon(
            onPressed: guardando ? null : cambiarFoto,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Cambiar la foto'),
          )
        else
          const Notice(_servidorSinCambioDeFoto),
      ],
    ),
  );

  static const _servidorSinCambioDeFoto =
      'Este servidor todavía no permite cambiar la foto de otra persona. '
      'La cambia cada alumno desde sus ajustes.';

  Widget _campoUsuario() => TextFormField(
    controller: usuario,
    enabled: !guardando,
    validator: usernameError,
    autocorrect: false,
    maxLength: 50,
    decoration: const InputDecoration(labelText: 'Nombre de usuario *'),
  );

  Widget _campoNombre() => TextFormField(
    controller: nombre,
    enabled: !guardando,
    validator: fullNameError,
    maxLength: 150,
    decoration: const InputDecoration(labelText: 'Nombre y apellidos *'),
  );

  Widget _campoRol() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<UserRole>(
        initialValue: rol,
        decoration: const InputDecoration(labelText: 'Rol *'),
        items: UserRole.values
            .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
            .toList(),
        onChanged: esNueva && !guardando
            ? (elegido) => setState(() => rol = elegido!)
            : null,
      ),
      if (!esNueva)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'El rol se fija al crear la cuenta y no se puede cambiar.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
    ],
  );

  Widget _campoCorreo() => TextFormField(
    controller: correo,
    enabled: !guardando,
    validator: emailError,
    keyboardType: TextInputType.emailAddress,
    decoration: const InputDecoration(labelText: 'Correo electrónico *'),
  );

  Widget _campoContrasena() => TextFormField(
    controller: contrasena,
    enabled: !guardando,
    obscureText: true,
    validator: (valor) =>
        !esNueva && valor!.isEmpty ? null : passwordError(valor),
    decoration: InputDecoration(
      labelText: esNueva ? 'Contraseña *' : 'Nueva contraseña (opcional)',
      helperText: esAlumno
          ? 'Una contraseña numérica permite usar el teclado de dibujos.'
          : null,
    ),
  );

  Widget _campoRepeticion() => TextFormField(
    controller: repeticion,
    enabled: !guardando,
    obscureText: true,
    validator: (valor) =>
        valor == contrasena.text ? null : 'Las contraseñas no coinciden.',
    decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
  );

  Widget _asociaciones() {
    if (esNueva) {
      return const Notice(
        'Guarda la cuenta y vuelve a abrirla para gestionar sus asociaciones.',
      );
    }
    if (rol == UserRole.admin) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: OutlinedButton.icon(
        onPressed: guardando
            ? null
            : () => openPage(context, AssociationsScreen(user: widget.user!)),
        icon: const Icon(Icons.link),
        label: const Text('Gestionar asociaciones'),
      ),
    );
  }
}
