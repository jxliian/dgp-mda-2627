import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/validation.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'access_settings_screen.dart';
import 'color_settings_screen.dart';

/// Accesibilidad del alumno y contraseña de las cuentas del centro y familia.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
  bool get puedeEditar => AppScope.of(context).canEditOwnSettings;

  Json _cambios(AppUser usuario) => {
    if (usuario.role == UserRole.student)
      for (final entrada in ajustes.toJson().entries)
        if (entrada.value != ajustesOriginales.values[entrada.key])
          entrada.key: entrada.value,
    if (usuario.role != UserRole.student && contrasena.text.isNotEmpty)
      'password': contrasena.text,
  };

  Future<void> guardar() async {
    if (ocupado || !puedeEditar) return;
    if (!form.currentState!.validate()) return;
    final state = AppScope.of(context);
    if (!state.student) await state.saveAdultAccess();
    final cambios = _cambios(state.user!);
    if (cambios.isEmpty) {
      setState(() => aviso = 'Tus ajustes se han guardado.');
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
      if (!state.student && contrasena.text.isNotEmpty) {
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
        child: LayoutBuilder(
          builder: (context, restricciones) {
            final ajustes = _ajustes(usuario);
            final foto = _fotoPropia(usuario);
            // La foto va al lado de los ajustes, no encima de ellos: en una
            // tablet sobra ancho de sobra para las dos cosas.
            if (restricciones.maxWidth < Pantalla.media) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [foto, const SizedBox(height: 24), ajustes],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: ajustes),
                const SizedBox(width: 32),
                SizedBox(width: 280, child: foto),
              ],
            );
          },
        ),
      ),
    );
  }

  /// La propia foto, para cualquier rol: el alumnado también reconoce a su
  /// profesorado por ella.
  Widget _fotoPropia(AppUser usuario) {
    final repositorio = AppScope.of(context).repository;
    return AvatarEditor(
      user: usuario,
      size: 140,
      title: 'Mi foto',
      busy: ocupado,
      allowed: repositorio.canSetOwnAvatar,
      upload: repositorio.uploadAvatar,
      note: 'Este servidor todavía no permite cambiar la foto desde aquí.',
    );
  }

  Widget _ajustes(AppUser usuario) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (usuario.role == UserRole.student) ..._seccionDeAlumno(usuario),
            if (usuario.role != UserRole.student) ...[
              ..._seccionDeAdulto(),
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
            ],
            if (error != null) Notice(error!, error: true),
            if (aviso != null) Notice(aviso!),
            if (usuario.role != UserRole.student)
              FormActions(
                busy: ocupado || !puedeEditar,
                onSave: guardar,
                label: 'Guardar mis ajustes',
              ),
          ],
        );

  /// La aplicación también la usan profesorado, familias y administración, y
  /// también necesitan letra grande o contraste. El servidor solo guarda los
  /// ajustes del alumnado, así que estos se quedan en el dispositivo.
  List<Widget> _seccionDeAdulto() {
    final state = AppScope.of(context);
    final ajustesDeAdulto = state.adultAccess;
    return [
      const SectionTitle(
        'Cómo veo la aplicación',
        hint: 'Se guarda en este dispositivo, no en tu cuenta.',
      ),
      Wrap(
        spacing: 20,
        runSpacing: 20,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextFormField(
              initialValue: '${ajustesDeAdulto.number('fontsize')}',
              enabled: !ocupado,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tamaño de letra',
                helperText: '16 es el tamaño normal',
              ),
              validator: (valor) {
                final numero = int.tryParse(valor ?? '');
                return numero == null || numero <= 0
                    ? 'Escribe un entero válido.'
                    : null;
              },
              onChanged: (valor) {
                final numero = int.tryParse(valor);
                if (numero != null && numero > 0) {
                  ajustesDeAdulto.values['stud_access_fontsize'] = numero;
                }
              },
            ),
          ),
          OutlinedButton.icon(
            onPressed: ocupado
                ? null
                : () async {
                    await openPage<bool>(
                      context,
                      ColorSettingsScreen(settings: ajustesDeAdulto),
                    );
                    if (mounted) setState(() {});
                  },
            icon: const Icon(Icons.palette_outlined),
            label: const Text('Configurar los colores'),
          ),
        ],
      ),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Alto contraste'),
        value: ajustesDeAdulto.flag('contrast'),
        onChanged: ocupado
            ? null
            : (valor) => setState(
                () => ajustesDeAdulto.values['stud_access_contrast'] = valor,
              ),
      ),
    ];
  }

  List<Widget> _seccionDeAlumno(AppUser usuario) => [
    const SectionTitle(
      'Cómo veo mi agenda',
      hint: 'El tamaño de la letra, los colores y los apoyos.',
    ),
    if (!AppScope.of(context).repository.supportsProfileRead)
      const Notice(_servidorSinLecturaDePerfil),
    if (!puedeEditar) const Notice(_ajustesProtegidos),
    OutlinedButton.icon(
      onPressed: ocupado
          ? null
          : () async {
              await openPage(
                context,
                AccessSettingsScreen(user: usuario, enabled: puedeEditar),
              );
              if (mounted) setState(() {});
            },
      icon: const Icon(Icons.accessibility_new),
      label: const Text('Abrir mis opciones de accesibilidad'),
    ),
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

  static const _servidorSinLecturaDePerfil =
      'El servidor todavía no permite consultar tus ajustes actuales. '
      'Solo se enviarán las opciones que cambies aquí.';
  static const _ajustesProtegidos =
      'Tus ajustes están protegidos. Pide ayuda al administrador.';
}
