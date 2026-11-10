import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/validation.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';

/// Icono asociado a cada perfil del centro.
IconData roleIcon(UserRole role) => switch (role) {
  UserRole.student => Icons.backpack_outlined,
  UserRole.staff => Icons.supervisor_account_outlined,
  UserRole.parent => Icons.family_restroom_outlined,
  UserRole.admin => Icons.admin_panel_settings_outlined,
};

/// Nombre corto, para cuando varios perfiles comparten una fila.
String roleShortLabel(UserRole role) => switch (role) {
  UserRole.student => 'Alumno',
  UserRole.staff => 'Personal',
  UserRole.parent => 'Familia',
  UserRole.admin => 'Dirección',
};

/// Pantalla de credenciales.
///
/// Se llega desde la portada, que ya ha decidido el camino: el personal y las
/// familias escriben usuario y contraseña, administración entra con su cuenta,
/// y el alumno llega con su foto ya elegida y solo pone su clave.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.roles = perfilesDelCentro, this.student});

  /// Perfiles que puede elegir quien entra. Con uno solo no se muestra
  /// selector: la portada ya lo ha decidido.
  final List<UserRole> roles;

  /// Alumno elegido en el directorio de fotos. Fija perfil y usuario.
  final AppUser? student;

  static const perfilesDelCentro = [UserRole.staff, UserRole.parent];

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _anchoFormulario = 560.0;
  static const _anchoConTeclado = 720.0;

  final form = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  late UserRole role;
  bool entrando = false;
  bool ocultarContrasena = true;
  bool usarDibujos = true;
  String? error;

  bool get esAlumno => role == UserRole.student;
  bool get usaTecladoDeDibujos => esAlumno && usarDibujos;
  bool get hayQueElegirPerfil =>
      widget.student == null && widget.roles.length > 1;

  @override
  void initState() {
    super.initState();
    role = widget.student != null ? UserRole.student : widget.roles.first;
    username.text = widget.student?.username ?? '';
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> entrar() async {
    if (usaTecladoDeDibujos && password.text.isEmpty) {
      setState(() => error = 'Introduce tu contraseña.');
      return;
    }
    if (!form.currentState!.validate()) return;
    setState(() {
      entrando = true;
      error = null;
    });
    try {
      await AppScope.of(
        context,
      ).login(username.text.trim(), password.text, role);
      password.clear();
      if (mounted) goHome(context);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          entrando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: esAlumno ? 'Introduce tu contraseña' : 'Iniciar sesión',
    subtitle: esAlumno ? null : _subtitulo,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: usaTecladoDeDibujos ? _anchoConTeclado : _anchoFormulario,
        ),
        child: Column(
          children: [
            if (!esAlumno) ...[
              const Brand(large: true),
              const SizedBox(height: 24),
            ],
            _formulario(),
          ],
        ),
      ),
    ),
  );

  String get _subtitulo => hayQueElegirPerfil
      ? 'Elige tu tipo de cuenta y escribe tus datos.'
      : role.label;

  Widget _formulario() => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.student != null)
              _AlumnoElegido(student: widget.student!)
            else ...[
              if (hayQueElegirPerfil) ...[
                const SectionTitle('¿Quién eres?', centered: true),
                _FilaDePerfiles(
                  perfiles: widget.roles,
                  seleccionado: role,
                  habilitado: !entrando,
                  onSelect: (elegido) => setState(() {
                    role = elegido;
                    error = null;
                  }),
                ),
              ],
              const SectionTitle('Tus datos', centered: true),
              TextFormField(
                controller: username,
                validator: usernameError,
                enabled: !entrando,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(labelText: 'Usuario'),
              ),
              const SizedBox(height: 20),
            ],
            if (usaTecladoDeDibujos)
              _TecladoDeDibujos(
                password: password,
                habilitado: !entrando,
                onChange: () => setState(() {}),
              )
            else
              _campoContrasena(),
            if (esAlumno) _cambiarModoDeContrasena(),
            if (error != null) Notice(error!, error: true),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: entrando ? null : entrar,
              icon: const Icon(Icons.login),
              label: Text(entrando ? 'Entrando…' : 'Iniciar sesión'),
            ),
            if (!esAlumno) _recordatorioDeContrasena(),
            if (AppScope.of(context).demo) Notice(_cuentasDePrueba),
          ],
        ),
      ),
    ),
  );

  Widget _campoContrasena() => TextFormField(
    controller: password,
    validator: passwordError,
    enabled: !entrando,
    obscureText: ocultarContrasena,
    autofillHints: const [AutofillHints.password],
    onFieldSubmitted: (_) => entrando ? null : entrar(),
    decoration: InputDecoration(
      labelText: esAlumno ? 'Mi contraseña o PIN' : 'Contraseña',
      suffixIcon: IconButton(
        tooltip: ocultarContrasena ? 'Mostrar contraseña' : 'Ocultar contraseña',
        onPressed: () => setState(() => ocultarContrasena = !ocultarContrasena),
        icon: Icon(
          ocultarContrasena
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );

  Widget _cambiarModoDeContrasena() => TextButton(
    onPressed: entrando
        ? null
        : () => setState(() => usarDibujos = !usarDibujos),
    child: Text(
      usarDibujos ? 'Escribir la contraseña con el teclado' : 'Usar dibujos',
    ),
  );

  Widget _recordatorioDeContrasena() => TextButton(
    onPressed: () => setState(() => error = _pedirCambioAlAdministrador),
    child: const Text('¿Has olvidado tu contraseña?'),
  );

  String get _cuentasDePrueba => switch (role) {
    UserRole.admin => 'Cuenta de prueba: admin. Contraseña: 1234.',
    UserRole.student =>
      'Contraseña de prueba: Corazón, Estrella, Animal y Flor.',
    _ => 'Cuentas de prueba: lucia (personal) y familia (tutor). '
        'Contraseña: 1234.',
  };

  static const _pedirCambioAlAdministrador =
      'Si has olvidado tu contraseña, pide al administrador del centro que la cambie.';
}

/// Perfiles disponibles, todos en una fila y del mismo tamaño.
class _FilaDePerfiles extends StatelessWidget {
  const _FilaDePerfiles({
    required this.perfiles,
    required this.seleccionado,
    required this.habilitado,
    required this.onSelect,
  });

  final List<UserRole> perfiles;
  final UserRole seleccionado;
  final bool habilitado;
  final ValueChanged<UserRole> onSelect;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final perfil in perfiles) ...[
        if (perfil != perfiles.first) const SizedBox(width: 10),
        Expanded(
          child: _BotonDePerfil(
            role: perfil,
            seleccionado: seleccionado == perfil,
            onPressed: habilitado ? () => onSelect(perfil) : null,
          ),
        ),
      ],
    ],
  );
}

class _BotonDePerfil extends StatelessWidget {
  const _BotonDePerfil({
    required this.role,
    required this.seleccionado,
    required this.onPressed,
  });

  final UserRole role;
  final bool seleccionado;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(roleIcon(role), size: 40),
        const SizedBox(height: 8),
        Text(
          role.label,
          textAlign: TextAlign.center,
          // Con la letra muy ampliada se recorta en pantalla, pero el nombre
          // completo del perfil sigue anunciándose al lector.
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ],
    );
    const relleno = EdgeInsets.symmetric(horizontal: 6, vertical: 20);
    return Semantics(
      selected: seleccionado,
      button: true,
      label: role.label,
      excludeSemantics: true,
      child: seleccionado
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(padding: relleno),
              child: contenido,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(padding: relleno),
              child: contenido,
            ),
    );
  }
}

/// Cabecera cuando el alumno ya se ha identificado con su foto.
class _AlumnoElegido extends StatelessWidget {
  const _AlumnoElegido({required this.student});

  final AppUser student;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 16),
    child: Column(
      children: [
        UserAvatar(user: student, size: 96),
        const SizedBox(height: 10),
        Text(student.displayName, style: Theme.of(context).textTheme.titleLarge),
      ],
    ),
  );
}

/// Teclado de dibujos: cada dibujo escribe una cifra del PIN.
class _TecladoDeDibujos extends StatelessWidget {
  const _TecladoDeDibujos({
    required this.password,
    required this.habilitado,
    required this.onChange,
  });

  final TextEditingController password;
  final bool habilitado;
  final VoidCallback onChange;

  static const _dibujos = [
    (Icons.wb_sunny_outlined, 'Sol'),
    (Icons.favorite_border, 'Corazón'),
    (Icons.star_border, 'Estrella'),
    (Icons.pets_outlined, 'Animal'),
    (Icons.local_florist_outlined, 'Flor'),
    (Icons.directions_car_outlined, 'Coche'),
    (Icons.sports_soccer, 'Pelota'),
    (Icons.home_outlined, 'Casa'),
    (Icons.park_outlined, 'Árbol'),
    (Icons.music_note_outlined, 'Música'),
  ];
  static const _anchoMinimoTecla = 104.0;
  static const _separacion = 10.0;
  static const _maximoCaracteres = 72;
  static const _casillasMinimas = 4;

  void _escribir(int cifra) {
    if (password.text.length < _maximoCaracteres) {
      password.text += '$cifra';
      onChange();
    }
  }

  void _borrar() {
    if (password.text.isNotEmpty) {
      password.text = password.text.substring(0, password.text.length - 1);
      onChange();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        'Pulsa tus dibujos en orden.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 10),
      _marcador(),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, restricciones) {
          final columnas = _columnasQueCaben(restricciones.maxWidth);
          final ancho =
              (restricciones.maxWidth - _separacion * (columnas - 1)) / columnas;
          return Wrap(
            spacing: _separacion,
            runSpacing: _separacion,
            alignment: WrapAlignment.center,
            children: [
              for (var cifra = 0; cifra < _dibujos.length; cifra++)
                SizedBox(width: ancho, child: _tecla(cifra)),
            ],
          );
        },
      ),
      const SizedBox(height: 4),
      TextButton.icon(
        onPressed: habilitado ? _borrar : null,
        icon: const Icon(Icons.backspace_outlined),
        label: const Text('Borrar el último dibujo'),
      ),
    ],
  );

  int _columnasQueCaben(double ancho) {
    final caben =
        ((ancho + _separacion) / (_anchoMinimoTecla + _separacion)).floor();
    return caben.clamp(2, 5);
  }

  /// Casillas que muestran cuántos dibujos se han pulsado, como en el boceto.
  Widget _marcador() => Semantics(
    liveRegion: true,
    label: '${password.text.length} dibujos introducidos',
    excludeSemantics: true,
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < _casillasVisibles; i++)
          Container(
            width: 58,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i < password.text.length
                  ? Paleta.bosqueSuave
                  : Paleta.blanco,
              borderRadius: BorderRadius.circular(Medidas.radioControl),
              border: Border.all(
                color: Paleta.trazoControl,
                width: Medidas.trazoGrueso,
              ),
            ),
            child: i < password.text.length
                ? const Icon(Icons.circle, size: 20, color: Paleta.bosque)
                : null,
          ),
      ],
    ),
  );

  int get _casillasVisibles => password.text.length < _casillasMinimas
      ? _casillasMinimas
      : password.text.length;

  Widget _tecla(int cifra) {
    final (icono, nombre) = _dibujos[cifra];
    return Semantics(
      label: '$nombre, número $cifra',
      button: true,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: habilitado ? () => _escribir(cifra) : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 38),
            const SizedBox(height: 4),
            Text(
              '$nombre · $cifra',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
