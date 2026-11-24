import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/validation.dart';
import '../state/app_state.dart';
import '../services/repository.dart';
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
  final contrasena = TextEditingController();
  final repeticion = TextEditingController();
  late UserRole rol;
  late AccessSettings ajustes;
  bool guardando = false;
  String? error;
  String? aviso;

  Uint8List? nuevaFoto;
  bool cuentaGuardada = false;

  bool get altaDisponible =>
      !esNueva || AppScope.of(context).repository.canCreateUser(rol);

  bool get esNueva => widget.user == null;
  bool get esAlumno => rol == UserRole.student;

  @override
  void initState() {
    super.initState();
    final cuenta = widget.user;
    usuario.text = cuenta?.username ?? '';
    nombre.text = cuenta?.fullName ?? '';
    rol = cuenta?.role ?? UserRole.student;
    ajustes = cuenta?.access.copy() ?? AccessSettings();
  }

  @override
  void dispose() {
    usuario.dispose();
    nombre.dispose();
    contrasena.dispose();
    repeticion.dispose();
    super.dispose();
  }

  Json _datosParaGuardar() => {
    'username': usuario.text.trim(),
    'full_name': nombre.text.trim(),
    if (esNueva) 'role': rol.name,
    if (contrasena.text.isNotEmpty) 'password': contrasena.text,
    if (esAlumno) ...ajustes.toJson(),
  };

  Future<void> guardar() async {
    if (guardando || !altaDisponible || !form.currentState!.validate()) return;
    final state = AppScope.of(context);
    final namespace = state.photoNamespace;
    final demo = state.demo;
    final cuenta = AppUser(
      username: usuario.text.trim(),
      fullName: nombre.text.trim(),
      role: rol,
    );
    final fotoLocal = state.profilePhotoIsLocal(cuenta);
    setState(() {
      guardando = true;
      error = null;
    });
    try {
      if (!cuentaGuardada) {
        await state.repository.saveUser(
          _datosParaGuardar(),
          previous: widget.user,
        );
        cuentaGuardada = true;
      }
      final anterior = widget.user;
      final renombrada =
          anterior != null && anterior.username != cuenta.username;
      final foto =
          nuevaFoto ??
          (renombrada
              ? await state.profilePhotos.read(namespace, anterior, demo: demo)
              : null);
      if (nuevaFoto != null) {
        // El cambio del propio usuario puede cerrar la sesión. El alta o la
        // edición ya se ha autorizado antes de guardar esta copia local.
        if (fotoLocal) {
          await state.profilePhotos.save(
            namespace,
            cuenta,
            nuevaFoto!,
            demo: demo,
          );
        } else {
          await state.saveProfilePhoto(cuenta, nuevaFoto!);
        }
      } else if (foto != null) {
        await state.profilePhotos.save(namespace, cuenta, foto, demo: demo);
      }
      if (renombrada) {
        await state.profilePhotos.remove(namespace, anterior, demo: demo);
      }
      state.photoChanged();
      final esLaPropia = widget.user?.username == state.user?.username;
      if (state.user != null && esLaPropia) await state.refreshProfile();
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => error = cuentaGuardada
              ? 'La cuenta se ha guardado. No se ha podido completar la foto '
                    'o actualizar la pantalla. Pulsa Guardar usuario para reintentarlo.'
              : e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: esNueva ? 'Crear usuario' : 'Modificar usuario',
    subtitle: 'Administración',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfilePhotoEditor(
            user:
                widget.user ??
                AppUser(username: '', fullName: 'nuevo usuario', role: rol),
            photo: nuevaFoto,
            localOnly: AppScope.of(context).profilePhotoIsLocal(
              AppUser(
                username: usuario.text.trim(),
                fullName: nombre.text.trim(),
                role: rol,
              ),
            ),
            label: esNueva ? 'Elegir foto' : 'Cambiar la foto',
            enabled: !guardando,
            onBusyChanged: (value) => setState(() => guardando = value),
            onSelected: (bytes) async {
              setState(() {
                nuevaFoto = bytes;
                aviso =
                    'Foto seleccionada. Pulsa Guardar usuario para conservarla.';
              });
            },
          ),
          const SectionTitle('Datos de la cuenta'),
          _campoUsuario(),
          const SizedBox(height: 18),
          _campoNombre(),
          const SizedBox(height: 18),
          _campoRol(),
          if (!altaDisponible) const Notice(userCreationUnavailable),
          const SectionTitle(
            'Contraseña',
            hint: 'Al modificar una cuenta, déjala vacía para no cambiarla.',
          ),
          _campoContrasena(),
          const SizedBox(height: 18),
          _campoRepeticion(),
          if (esAlumno)
            AccessEditor(
              settings: ajustes,
              permissions: true,
              enabled: !guardando,
            ),
          _asociaciones(),
          if (error != null) Notice(error!, error: true),
          if (aviso != null) Notice(aviso!),
          FormActions(
            busy: guardando,
            canSave: altaDisponible,
            onSave: guardar,
            label: 'Guardar usuario',
          ),
        ],
      ),
    ),
  );

  Widget _campoUsuario() => TextFormField(
    controller: usuario,
    enabled: !guardando && !cuentaGuardada,
    validator: usernameError,
    autocorrect: false,
    maxLength: 50,
    decoration: const InputDecoration(labelText: 'Nombre de usuario *'),
  );

  Widget _campoNombre() => TextFormField(
    controller: nombre,
    enabled: !guardando && !cuentaGuardada,
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
        onChanged: esNueva && !guardando && !cuentaGuardada
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

  Widget _campoContrasena() => TextFormField(
    controller: contrasena,
    enabled: !guardando && !cuentaGuardada,
    obscureText: true,
    keyboardType: esAlumno ? TextInputType.number : TextInputType.text,
    validator: (valor) {
      if (!esNueva && (valor == null || valor.isEmpty)) return null;
      final error = passwordError(valor);
      if (error != null) return error;
      return esAlumno && !RegExp(r'^[0-9]+$').hasMatch(valor!)
          ? 'Usa solo números del 0 al 9 para el acceso con dibujos.'
          : null;
    },
    decoration: InputDecoration(
      labelText: esNueva ? 'Contraseña *' : 'Nueva contraseña (opcional)',
      helperText: esAlumno
          ? 'Solo números del 0 al 9: cada cifra corresponde a un dibujo.'
          : null,
    ),
  );

  Widget _campoRepeticion() => TextFormField(
    controller: repeticion,
    enabled: !guardando && !cuentaGuardada,
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
