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
      state.confirm('Ajustes guardados');
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
        setState(() => ajustesOriginales = ajustes.copy());
        state.confirm('Ajustes guardados');
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
      child: usuario.role == UserRole.student
          ? _vistaDeAlumno(usuario)
          : Form(
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

  /// Vista propia del alumnado: fichas grandes y simétricas que llenan la
  /// pantalla en tablet apaisada y pasan a una columna horizontal cuando se
  /// estrecha o se agranda la letra, para que nunca se deformen ni desborden.
  Widget _vistaDeAlumno(AppUser usuario) {
    final state = AppScope.of(context);
    final opciones =
        <Widget Function({required bool vertical, required double minHeight})>[
          ({required vertical, required minHeight}) => Semantics(
            button: true,
            enabled: !ocupado,
            child: ActionTile(
              title: 'Accesibilidad',
              subtitle: 'Letra, colores y apoyos',
              icon: Icons.accessibility_new,
              vertical: vertical,
              height: minHeight,
              edge: Paleta.bosque,
              onTap: ocupado
                  ? null
                  : () async {
                      await openPage(
                        context,
                        AccessSettingsScreen(
                          user: usuario,
                          enabled: puedeEditar,
                        ),
                      );
                      if (mounted) setState(() {});
                    },
            ),
          ),
          ({required vertical, required minHeight}) => ProfilePhotoEditor(
            user: usuario,
            label: 'Mi foto',
            localOnly: state.profilePhotoIsLocal(usuario),
            enabled:
                puedeEditar && !ocupado && state.canSetProfilePhoto(usuario),
            onBusyChanged: (value) => setState(() => ocupado = value),
            onError: (msg) => setState(() => error = msg),
            onSelected: (bytes) async {
              await state.saveProfilePhoto(usuario, bytes);
              if (mounted) {
                setState(() {
                  error = null;
                  aviso = state.profilePhotoSavedMessage(usuario);
                });
              }
            },
            asTile: true,
            vertical: vertical,
            height: minHeight,
            edge: Paleta.terracota,
          ),
        ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: LayoutBuilder(
          builder: (context, restricciones) {
            final letraGrande = Pantalla.letraGrande(context);
            final dosColumnas =
                restricciones.maxWidth >= Pantalla.media && !letraGrande;
            final minHeight = dosColumnas
                ? (opciones.length <= 2 ? 320.0 : 220.0)
                : (letraGrande
                      ? 140.0
                      : (opciones.length <= 2 ? 200.0 : 140.0));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!state.repository.supportsProfileRead)
                  const Notice(_servidorSinLecturaDePerfil),
                if (!puedeEditar) const Notice(_ajustesProtegidos),
                if (dosColumnas)
                  for (var i = 0; i < opciones.length; i += 2) ...[
                    if (i > 0) const SizedBox(height: 12),
                    if (i + 1 < opciones.length)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: opciones[i](
                                vertical: true,
                                minHeight: minHeight,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: opciones[i + 1](
                                vertical: true,
                                minHeight: minHeight,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      opciones[i](vertical: false, minHeight: 160),
                  ]
                else
                  for (final opcion in opciones)
                    opcion(vertical: false, minHeight: minHeight),
                if (error != null) Notice(error!, error: true),
                if (aviso != null) Notice(aviso!),
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
    final state = AppScope.of(context);
    return ProfilePhotoEditor(
      user: usuario,
      label: 'Mi foto',
      localOnly: state.profilePhotoIsLocal(usuario),
      enabled: puedeEditar && !ocupado && state.canSetProfilePhoto(usuario),
      onBusyChanged: (value) => setState(() => ocupado = value),
      onSelected: (bytes) async {
        await state.saveProfilePhoto(usuario, bytes);
        if (mounted) {
          setState(() => aviso = state.profilePhotoSavedMessage(usuario));
        }
      },
    );
  }

  Widget _ajustes(AppUser usuario) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._seccionDeAdulto(),
        const SectionTitle(
          'Contraseña',
          hint: 'Déjala vacía si no la cambias.',
        ),
        _campoContrasena(),
        const SizedBox(height: 16),
        _campoRepeticion(),
        const SizedBox(height: 8),
        Text(
          'Al cambiarla tendrás que entrar de nuevo.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (error != null) Notice(error!, error: true),
        // El mensaje de la foto no es un «guardado» cualquiera: dice si ha
        // ido al servidor o solo a este dispositivo, así que se queda.
        if (aviso != null) Notice(aviso!),
        FormActions(
          busy: ocupado,
          canSave: puedeEditar,
          onSave: guardar,
          label: 'Guardar mis ajustes',
        ),
      ],
    );
  }

  /// La aplicación también la usan profesorado, familias y administración, y
  /// también necesitan letra grande o contraste. El servidor solo guarda los
  /// ajustes del alumnado, así que estos se quedan en el dispositivo.
  List<Widget> _seccionDeAdulto() {
    final state = AppScope.of(context);
    final ajustesDeAdulto = state.adultAccess;
    return [
      const SectionTitle(
        'Cómo la veo',
        hint: 'Solo en este dispositivo.',
      ),
      // El mismo criterio que en la accesibilidad del alumno: se elige entre
      // opciones, no se escribe un número.
      OptionPicker<int>(
        label: 'Tamaño de letra',
        enabled: !ocupado,
        value: ajustesDeAdulto.number('fontsize'),
        onChanged: (valor) => setState(
          () => ajustesDeAdulto.values['stud_access_fontsize'] = valor,
        ),
        options: [
          for (final (tamano, nombre) in const [
            (16, 'Normal'),
            (20, 'Grande'),
            (26, 'Muy grande'),
            (32, 'Enorme'),
          ])
            Opcion(
              tamano,
              nombre,
              leading: SizedBox(
                width: 34,
                child: Center(
                  child: Text(
                    'A',
                    style: TextStyle(
                      fontSize: tamano.toDouble().clamp(14, 30),
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 20,
        runSpacing: 20,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
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
      'El servidor no devuelve tus ajustes actuales: solo se envía lo que '
      'cambies aquí.';
  static const _ajustesProtegidos =
      'Tus ajustes están protegidos. Pide ayuda.';
}
