import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../ui/ui.dart';

/// Ajustes de accesibilidad de un alumno: colores, tamaños y apoyos.
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
  static const _colores = {
    'main_col': 'Color de fondo',
    'sec_col': 'Color de los botones',
  };
  static const _numeros = {
    'fontsize': ('Tamaño de letra', 'Entero mayor que cero', 1),
    'ntasks_visible': ('Tareas por página', '0: mostrar todas', 0),
    'ndays_visible': ('Días visibles', '0: solo hoy; hasta 7 por semana', 0),
  };
  static const _apoyos = {
    'pictograms': 'Mostrar apoyos visuales',
    'contrast': 'Alto contraste',
    'filters': 'Mostrar filtros de tareas',
    'talkback': 'Mostrar botones para escuchar',
  };
  static const _permisos = {
    'prof_mod': 'Permiso de personalización avanzada',
    'profile_mod': 'Puede modificar su perfil',
    'task_mod': 'Puede crear y eliminar sus tareas',
  };

  void _guardar(String clave, Object valor) =>
      widget.settings.values['stud_access_$clave'] = valor;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionTitle(
        'Visualización y apoyos',
        hint: 'Ajusta cómo se ve la agenda del alumno.',
      ),
      Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          for (final entrada in _colores.entries)
            SizedBox(width: 260, child: _campoDeColor(entrada.key, entrada.value)),
          for (final entrada in _numeros.entries)
            SizedBox(width: 260, child: _campoNumerico(entrada.key, entrada.value)),
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

  Widget _campoDeColor(String clave, String etiqueta) => TextFormField(
    initialValue: widget.settings.color(clave),
    enabled: widget.enabled,
    decoration: InputDecoration(labelText: '$etiqueta (#RRGGBB)'),
    validator: (valor) =>
        RegExp(r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(valor ?? '')
        ? null
        : 'Usa un color como #1b4332.',
    onChanged: (valor) => _guardar(clave, valor),
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
