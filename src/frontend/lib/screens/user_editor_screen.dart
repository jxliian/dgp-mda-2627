import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/validation.dart';
import '../services/repository.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'access_settings_screen.dart';
import 'associations_screen.dart';
import 'class_picker_screen.dart';

/// Alta y edición de cuentas (SCRUM-8 y SCRUM-9).
///
/// La plantilla es la misma para cualquier rol: arriba, lo que se puede hacer
/// con la cuenta y su foto; debajo, los datos, repartidos en horizontal para
/// que una tablet no desperdicie el ancho con campos de lado a lado. La
/// accesibilidad del alumno no está aquí: tiene pantalla propia.
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
  final apellidos = TextEditingController();
  final contrasena = TextEditingController();
  final repeticion = TextEditingController();
  late UserRole rol;
  late AccessSettings ajustes;
  bool guardando = false;
  String? error;
  String? aviso;

  Uint8List? nuevaFoto;
  bool cuentaGuardada = false;
  bool fotoGuardada = false;

  bool get esNueva => widget.user == null;
  bool get esAlumno => rol == UserRole.student;

  @override
  void initState() {
    super.initState();
    final cuenta = widget.user;
    final (nom, ape) = _partirNombre(cuenta?.fullName ?? '');
    usuario.text = cuenta?.username ?? '';
    nombre.text = nom;
    apellidos.text = ape;
    rol = cuenta?.role ?? UserRole.student;
    ajustes = cuenta?.access.copy() ?? AccessSettings();
  }

  @override
  void dispose() {
    usuario.dispose();
    nombre.dispose();
    apellidos.dispose();
    contrasena.dispose();
    repeticion.dispose();
    super.dispose();
  }

  /// El servidor guarda un único campo de nombre completo. Aquí se reparte en
  /// dos para que quepan uno al lado del otro.
  static (String, String) _partirNombre(String completo) {
    final partes = completo.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return ('', '');
    return (partes.first, partes.skip(1).join(' '));
  }

  String get _nombreCompleto =>
      '${nombre.text.trim()} ${apellidos.text.trim()}'.trim();

  Json _datosParaGuardar() => {
    'username': usuario.text.trim(),
    'full_name': _nombreCompleto,
    if (esNueva) 'role': rol.name,
    if (contrasena.text.isNotEmpty) 'password': contrasena.text,
    // Al crear, el servidor exige los ajustes completos; al modificar se
    // tocan desde la pantalla de accesibilidad, no desde aquí.
    if (esAlumno && esNueva) ...ajustes.toJson(),
  };

  Future<void> guardar() async {
    if (guardando || !form.currentState!.validate()) return;
    final problema = fullNameError(_nombreCompleto);
    if (problema != null) {
      setState(() => error = problema);
      return;
    }
    final state = AppScope.of(context);
    final cuenta = AppUser(
      username: usuario.text.trim(),
      fullName: _nombreCompleto,
      role: rol,
    );
    final own =
        widget.user?.username == state.user?.username &&
        widget.user?.role == state.user?.role;
    final closesSession =
        own &&
        (contrasena.text.isNotEmpty ||
            widget.user?.username != cuenta.username);
    setState(() {
      guardando = true;
      error = null;
    });
    try {
      // El cambio de credenciales revoca el token: la foto propia debe subirse antes.
      if (closesSession && nuevaFoto != null && !fotoGuardada) {
        await state.saveProfilePhoto(widget.user!, nuevaFoto!);
        fotoGuardada = true;
      }
      if (!cuentaGuardada) {
        await state.repository.saveUser(
          _datosParaGuardar(),
          previous: widget.user,
        );
        cuentaGuardada = true;
      }
      if (nuevaFoto != null && !fotoGuardada) {
        await state.saveProfilePhoto(cuenta, nuevaFoto!);
        fotoGuardada = true;
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
          // Lo que se puede hacer con la cuenta va primero, no al final de un
          // formulario largo.
          _cabecera(),
          const SectionTitle('Datos de la cuenta'),
          _fila([(3, _campoUsuario()), (3, _campoRol())]),
          const SizedBox(height: 18),
          _fila([(1, _campoNombre()), (1, _campoApellidos())]),
          const SectionTitle(
            'Contraseña',
            hint: 'Al modificar una cuenta, déjala vacía para no cambiarla.',
          ),
          _fila([(1, _campoContrasena()), (1, _campoRepeticion())]),
          if (error != null) Notice(error!, error: true),
          if (aviso != null) Notice(aviso!),
          FormActions(
            busy: guardando,
            onSave: guardar,
            label: 'Guardar usuario',
          ),
        ],
      ),
    ),
  );

  /// Gestión a la izquierda y foto a la derecha; en pantalla estrecha, una
  /// debajo de la otra.
  Widget _cabecera() => LayoutBuilder(
    builder: (context, restricciones) {
      final gestion = _gestion();
      final foto = _foto();
      if (restricciones.maxWidth < Pantalla.media) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [foto, const SizedBox(height: 20), gestion],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: gestion),
          const SizedBox(width: 28),
          Expanded(flex: 2, child: foto),
        ],
      );
    },
  );

  Widget _gestion() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionTitle(
        'Gestión de la cuenta',
        hint: 'Su aula, su accesibilidad y sus asociaciones.',
      ),
      if (esNueva)
        const Notice(
          'Guarda la cuenta y vuelve a abrirla para asignarle aula, '
          'accesibilidad y asociaciones.',
        )
      else ...[
        if (rol != UserRole.admin) _AulaDeLaCuenta(user: widget.user!),
        const SizedBox(height: 14),
        if (esAlumno)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: OutlinedButton.icon(
              onPressed: guardando
                  ? null
                  : () => openPage(
                      context,
                      AccessSettingsScreen(
                        user: widget.user!,
                        permissions: true,
                      ),
                    ),
              icon: const Icon(Icons.accessibility_new),
              label: const Text('Permisos y accesibilidad'),
            ),
          ),
        if (rol != UserRole.admin)
          OutlinedButton.icon(
            onPressed: guardando
                ? null
                : () =>
                      openPage(context, AssociationsScreen(user: widget.user!)),
            icon: const Icon(Icons.link),
            label: const Text('Gestionar asociaciones'),
          ),
      ],
    ],
  );

  Widget _foto() => ProfilePhotoEditor(
    user:
        widget.user ??
        AppUser(username: '', fullName: 'nuevo usuario', role: rol),
    photo: nuevaFoto,
    localOnly: AppScope.of(context).profilePhotoIsLocal(
      AppUser(
        username: usuario.text.trim(),
        fullName: _nombreCompleto,
        role: rol,
      ),
    ),
    label: esNueva ? 'Elegir foto' : 'Cambiar la foto',
    enabled: !guardando && AppScope.of(context).repository.canSetAvatarOf,
    onBusyChanged: (value) => setState(() => guardando = value),
    onSelected: (bytes) async {
      setState(() {
        nuevaFoto = bytes;
        fotoGuardada = false;
        aviso = 'Foto seleccionada. Pulsa Guardar usuario para conservarla.';
      });
    },
  );

  /// Campos en una fila con los pesos indicados; apilados si no caben.
  Widget _fila(List<(int, Widget)> campos) => LayoutBuilder(
    builder: (context, restricciones) {
      if (restricciones.maxWidth < Pantalla.compacta || campos.length == 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < campos.length; i++) ...[
              if (i > 0) const SizedBox(height: 18),
              campos[i].$2,
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < campos.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            Expanded(flex: campos[i].$1, child: campos[i].$2),
          ],
        ],
      );
    },
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
    validator: requiredText,
    maxLength: 70,
    decoration: const InputDecoration(labelText: 'Nombre *'),
  );

  Widget _campoApellidos() => TextFormField(
    controller: apellidos,
    enabled: !guardando && !cuentaGuardada,
    maxLength: 80,
    decoration: const InputDecoration(labelText: 'Apellidos'),
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

}

/// Aula de la cuenta, con el botón para cambiarla desde la propia ficha.
class _AulaDeLaCuenta extends StatefulWidget {
  const _AulaDeLaCuenta({required this.user});

  final AppUser user;

  @override
  State<_AulaDeLaCuenta> createState() => _AulaDeLaCuentaState();
}

class _AulaDeLaCuentaState extends State<_AulaDeLaCuenta> {
  int revision = 0;
  bool ocupado = false;
  String? error;

  bool get esAlumno => widget.user.role == UserRole.student;

  Future<String> _aulaActual() async =>
      await AppScope.of(context).repository.classOf(widget.user.username) ?? '';

  Future<void> cambiarAula(String anterior) async {
    final elegida = await openPage<String>(
      context,
      ClassPickerScreen(
        title: esAlumno ? 'Matricular en un aula' : 'Asignar a un aula',
        current: anterior.isEmpty ? null : anterior,
      ),
    );
    if (elegida == null || !mounted) return;
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      final repositorio = AppScope.of(context).repository;
      if (esAlumno) {
        if (anterior.isNotEmpty) {
          await repositorio.enroll(anterior, widget.user.username, remove: true);
        }
        await repositorio.enroll(elegida, widget.user.username);
      } else {
        await repositorio.addStaff(elegida, widget.user.username);
      }
      if (mounted) {
        AppScope.of(context).classroomsChanged();
        setState(() => revision++);
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.role == UserRole.parent) return const SizedBox.shrink();
    return LoadPanel<String>(
      key: ValueKey('aula/$revision'),
      load: _aulaActual,
      builder: (aula) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  aula.isEmpty ? 'Todavía sin aula' : 'Aula: $aula',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: ocupado ? null : () => cambiarAula(aula),
            icon: const Icon(Icons.swap_horiz),
            label: Text(aula.isEmpty ? 'Asignar aula' : 'Cambiar de aula'),
          ),
          if (error != null) Notice(error!, error: true),
        ],
      ),
    );
  }
}
