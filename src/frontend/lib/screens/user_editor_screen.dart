import 'package:flutter/material.dart';
import 'dart:typed_data';
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
/// que una tablet no desperdicie el ancho con campos de lado a lado.
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
  final correo = TextEditingController();
  final contrasena = TextEditingController();
  final repeticion = TextEditingController();
  late UserRole rol;
  late AccessSettings ajustes;
  bool guardando = false;
  String? error;
  String? aviso;

  /// El servidor solo tiene ruta de foto para alumnos: para el resto de roles
  /// la plantilla enseña el mismo bloque, pero explica que aún no se puede.
  bool get puedeCambiarLaFoto =>
      !esNueva && esAlumno && AppScope.of(context).repository.canSetAvatarOf;

  bool get esNueva => widget.user == null;
  bool get esAlumno => rol == UserRole.student;

  /// Al crear una cuenta que no es de alumno el servidor exige un correo
  /// válido; al modificarla, no.
  bool get correoObligatorio => esNueva && !esAlumno;

  @override
  void initState() {
    super.initState();
    final cuenta = widget.user;
    final (nom, ape) = _partirNombre(cuenta?.fullName ?? '');
    usuario.text = cuenta?.username ?? '';
    nombre.text = nom;
    apellidos.text = ape;
    correo.text = cuenta?.email ?? '';
    rol = cuenta?.role ?? UserRole.student;
    ajustes = cuenta?.access.copy() ?? AccessSettings();
  }

  @override
  void dispose() {
    usuario.dispose();
    nombre.dispose();
    apellidos.dispose();
    correo.dispose();
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
    if (esAlumno && esNueva)
      ...ajustes.toJson()
    else if (!esAlumno && correo.text.trim().isNotEmpty)
      'email': correo.text.trim(),
  };

  Future<void> guardar() async {
    if (!form.currentState!.validate()) return;
    final problema = fullNameError(_nombreCompleto);
    if (problema != null) {
      setState(() => error = problema);
      return;
    }
    final state = AppScope.of(context);
    setState(() {
      guardando = true;
      error = null;
    });
    try {
      await state.repository.saveUser(
        _datosParaGuardar(),
        previous: widget.user,
      );
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
  Future<void> subirFoto(Uint8List bytes, String nombre) => AppScope.of(
    context,
  ).repository.uploadAvatarOf(widget.user!, bytes, nombre);

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
          _fila([
            (3, _campoUsuario()),
            (3, _campoRol()),
          ]),
          const SizedBox(height: 18),
          _fila([
            (1, _campoNombre()),
            (1, _campoApellidos()),
          ]),
          if (!esAlumno) ...[
            const SizedBox(height: 18),
            _fila([
              (1, _campoCorreo()),
            ]),
          ],
          const SectionTitle(
            'Contraseña',
            hint: 'Al modificar una cuenta, déjala vacía para no cambiarla.',
          ),
          _fila([
            (1, _campoContrasena()),
            (1, _campoRepeticion()),
          ]),
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
      final enHorizontal = restricciones.maxWidth >= Pantalla.media;
      final gestion = _gestion();
      final foto = _foto();
      if (!enHorizontal) {
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
          'Guarda la cuenta y vuelve a abrirla para asignarle aula y asociaciones.',
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
                : () => openPage(context, AssociationsScreen(user: widget.user!)),
            icon: const Icon(Icons.link),
            label: const Text('Gestionar asociaciones'),
          ),
      ],
    ],
  );

  Widget _foto() {
    if (esNueva) {
      return const Column(
        children: [
          SectionTitle('Foto', centered: true),
          Notice('La foto se puede poner al guardar la cuenta.'),
        ],
      );
    }
    return AvatarEditor(
      user: widget.user!,
      size: 160,
      busy: guardando,
      allowed: puedeCambiarLaFoto,
      upload: subirFoto,
      note: esAlumno ? _servidorSinCambioDeFoto : _servidorSinFotoDeAdultos,
    );
  }

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

  static const _servidorSinCambioDeFoto =
      'Este servidor todavía no permite cambiar la foto desde administración. '
      'La cambia cada alumno desde sus ajustes.';
  static const _servidorSinFotoDeAdultos =
      'El servidor solo guarda foto de las cuentas de alumno. Para que el '
      'alumnado reconozca a su profesorado hace falta ampliarlo.';

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
    validator: requiredText,
    maxLength: 70,
    decoration: const InputDecoration(labelText: 'Nombre *'),
  );

  Widget _campoApellidos() => TextFormField(
    controller: apellidos,
    enabled: !guardando,
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
    validator: (valor) {
      if (!correoObligatorio && (valor == null || valor.trim().isEmpty)) {
        return null;
      }
      return emailError(valor);
    },
    keyboardType: TextInputType.emailAddress,
    decoration: InputDecoration(
      labelText: correoObligatorio
          ? 'Correo electrónico *'
          : 'Correo electrónico (opcional)',
      helperText: correoObligatorio
          ? 'El servidor lo exige para crear cuentas que no son de alumno.'
          : null,
    ),
  );

  Widget _campoContrasena() => TextFormField(
    controller: contrasena,
    enabled: !guardando,
    obscureText: true,
    keyboardType: esAlumno ? TextInputType.number : TextInputType.text,
    maxLength: esAlumno ? dibujosDeLaContrasena : null,
    validator: (valor) {
      if (!esNueva && (valor == null || valor.isEmpty)) return null;
      return esAlumno ? studentPasswordError(valor) : passwordError(valor);
    },
    decoration: InputDecoration(
      labelText: esNueva ? 'Contraseña *' : 'Nueva contraseña (opcional)',
      helperText: esAlumno
          ? 'Exactamente $dibujosDeLaContrasena números del 0 al 9: cada '
                'cifra es un dibujo de su teclado.'
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

  Future<String?> _aulaActual() =>
      AppScope.of(context).repository.classOf(widget.user.username);

  Future<void> cambiarAula(String? anterior) async {
    final elegida = await openPage<String>(
      context,
      ClassPickerScreen(
        title: esAlumno ? 'Matricular en un aula' : 'Asignar a un aula',
        current: anterior,
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
        if (anterior != null) {
          await repositorio.enroll(
            anterior,
            widget.user.username,
            remove: true,
          );
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
    return LoadPanel<String?>(
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
                  aula == null ? 'Todavía sin aula' : 'Aula: $aula',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: ocupado ? null : () => cambiarAula(aula),
            icon: const Icon(Icons.swap_horiz),
            label: Text(aula == null ? 'Asignar aula' : 'Cambiar de aula'),
          ),
          if (error != null) Notice(error!, error: true),
        ],
      ),
    );
  }
}
