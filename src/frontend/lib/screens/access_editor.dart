import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../ui/ui.dart';
import 'color_settings_screen.dart';

/// Permisos y apoyos de un alumno: qué puede hacer y cómo ve su agenda.
///
/// Los colores no están aquí: tienen pantalla propia, porque elegir color es
/// una tarea en sí misma y entre campos de texto se perdía.
///
/// Los interruptores de permisos solo se muestran a quien administra la
/// cuenta, no al propio alumno.
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
  static const _numeros = {
    'fontsize': ('Tamaño de letra', 'Entero mayor que cero', 1),
    'ntasks_visible': ('Tareas por página', '0: mostrar todas', 0),
    'ndays_visible': ('Días visibles', '0: solo hoy; hasta 7 por semana', 0),
  };
  static const _apoyos = {
    'pictograms': 'Mostrar apoyos visuales',
    'contrast': 'Alto contraste',
    'talkback': 'Mostrar botones para escuchar',
  };
  static const _permisos = {
    'prof_mod': 'Permiso de personalización avanzada',
    'profile_mod': 'Puede modificar su perfil',
    'task_mod': 'Puede crear y eliminar sus tareas',
  };

  void _guardar(String clave, Object valor) =>
      widget.settings.values['stud_access_$clave'] = valor;

  Future<void> _abrirColores() async {
    await openPage<bool>(
      context,
      ColorSettingsScreen(settings: widget.settings, enabled: widget.enabled),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionTitle(
        'Permisos',
        hint: 'Qué puede hacer el alumno y con qué apoyos ve su agenda.',
      ),
      _botonDeColores(),
      const SizedBox(height: 18),
      Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          for (final entrada in _numeros.entries)
            SizedBox(
              width: 260,
              child: _campoNumerico(entrada.key, entrada.value),
            ),
        ],
      ),
      const SizedBox(height: 12),
      for (final entrada in _apoyos.entries)
        _interruptor(entrada.key, entrada.value),
      if (widget.permissions)
        for (final entrada in _permisos.entries)
          _interruptor(entrada.key, entrada.value),
    ],
  );

  Widget _botonDeColores() => Row(
    children: [
      OutlinedButton.icon(
        onPressed: widget.enabled ? _abrirColores : null,
        icon: const Icon(Icons.palette_outlined),
        label: const Text('Configurar los colores'),
      ),
      const SizedBox(width: 16),
      _muestraDeColor(widget.settings.color('main_col')),
      const SizedBox(width: 8),
      _muestraDeColor(widget.settings.color('sec_col')),
    ],
  );

  Widget _muestraDeColor(String valor) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: colorDesdeHex(valor),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Paleta.trazoControl, width: Medidas.trazo),
    ),
  );

  Widget _campoNumerico(String clave, (String, String, int) definicion) {
    final (etiqueta, ayuda, minimo) = definicion;
    return TextFormField(
      initialValue: '${widget.settings.number(clave)}',
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: etiqueta, helperText: ayuda),
      validator: (valor) {
        final numero = int.tryParse(valor ?? '');
        return numero == null || numero < minimo
            ? 'Escribe un entero válido.'
            : null;
      },
      onChanged: (valor) {
        final numero = int.tryParse(valor);
        if (numero != null) _guardar(clave, numero);
      },
    );
  }

  Widget _interruptor(String clave, String etiqueta) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(etiqueta),
    value: widget.settings.flag(clave),
    onChanged: widget.enabled
        ? (valor) => setState(() => _guardar(clave, valor))
        : null,
  );
}
