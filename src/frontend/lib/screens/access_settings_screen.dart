import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'access_editor.dart';

/// Permisos y apoyos de un alumno, en su propia pantalla.
///
/// Estaban incrustados en mitad del formulario de datos personales, de modo
/// que para cambiar el tamaño de letra había que bajar entre el nombre de
/// usuario y la contraseña. Son dos cosas distintas y se editan por separado:
/// esta pantalla guarda lo suyo con su propio botón y no arrastra cambios de
/// la otra.
///
/// Vale para las dos situaciones: administración editando a un alumno y el
/// propio alumno en sus ajustes. Solo cambia quién puede tocar los permisos.
class AccessSettingsScreen extends StatefulWidget {
  const AccessSettingsScreen({
    super.key,
    required this.user,
    this.permissions = false,
    this.enabled = true,
  });

  /// Alumno cuyos ajustes se editan.
  final AppUser user;

  /// Si se muestran los interruptores de permisos, que solo ve quien
  /// administra la cuenta.
  final bool permissions;

  /// Si se pueden modificar. Un alumno sin permiso los ve pero no los cambia.
  final bool enabled;

  @override
  State<AccessSettingsScreen> createState() => _AccessSettingsScreenState();
}

class _AccessSettingsScreenState extends State<AccessSettingsScreen> {
  final form = GlobalKey<FormState>();
  late AccessSettings ajustes;
  late AccessSettings originales;
  bool guardando = false;
  String? aviso;
  String? error;

  @override
  void initState() {
    super.initState();
    originales = widget.user.access.copy();
    ajustes = originales.copy();
  }

  /// Solo se envía lo que ha cambiado: así esta pantalla no pisa datos que se
  /// editan en la otra.
  Json get _cambios => {
    for (final entrada in ajustes.toJson().entries)
      if (entrada.value != originales.values[entrada.key])
        entrada.key: entrada.value,
  };

  Future<void> guardar() async {
    if (guardando || !widget.enabled) return;
    if (!form.currentState!.validate()) return;
    final cambios = _cambios;
    if (cambios.isEmpty) {
      setState(() => aviso = 'No hay cambios para guardar.');
      return;
    }
    final state = AppScope.of(context);
    setState(() {
      guardando = true;
      error = null;
      aviso = null;
    });
    try {
      await state.repository.saveUser(cambios, previous: widget.user);
      if (state.user?.username == widget.user.username) {
        await state.refreshProfile();
      }
      if (mounted) {
        setState(() {
          originales = ajustes.copy();
          aviso = 'Los ajustes se han guardado.';
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Accesibilidad',
    subtitle: widget.user.displayName,
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.enabled) const Notice(_protegidos),
          AccessEditor(
            settings: ajustes,
            permissions: widget.permissions,
            enabled: widget.enabled && !guardando,
          ),
          if (error != null) Notice(error!, error: true),
          if (aviso != null) Notice(aviso!),
          FormActions(
            busy: guardando || !widget.enabled,
            onSave: guardar,
            label: 'Guardar',
            topPadding: 18,
          ),
        ],
      ),
    ),
  );

  static const _protegidos =
      'Estos ajustes están protegidos. Pide ayuda al administrador.';
}
