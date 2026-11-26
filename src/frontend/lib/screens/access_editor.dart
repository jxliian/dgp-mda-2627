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
  /// Opciones preparadas para cada ajuste. No se escribe ningún número: el
  /// valor que se guarda sigue siendo el mismo que antes, pero se elige.
  static const _tamanosDeLetra = [
    Opcion(16, 'Normal'),
    Opcion(20, 'Grande'),
    Opcion(26, 'Muy grande'),
    Opcion(32, 'Enorme'),
  ];
  static const _tareasPorPagina = [
    Opcion(1, 'Una a una'),
    Opcion(2, 'Dos a la vez'),
    Opcion(3, 'Tres a la vez'),
    Opcion(0, 'Todas'),
  ];
  static const _diasVisibles = [
    Opcion(0, 'Solo hoy'),
    Opcion(3, 'Tres días'),
    Opcion(5, 'Lun. a vie.'),
    Opcion(7, 'La semana'),
  ];
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
      // Los tres ajustes, uno al lado de otro cuando hay ancho: en columna
      // ocupaban tres pantallas de alto.
      LayoutBuilder(
        builder: (context, restricciones) {
          final grupos = [
            _opciones(
              clave: 'fontsize',
              etiqueta: 'Tamaño de letra',
              opciones: _tamanosDeLetra,
              conLetra: true,
            ),
            _opciones(
              clave: 'ntasks_visible',
              etiqueta: 'Cuántas tareas ve a la vez',
              opciones: _tareasPorPagina,
              ancho: 166,
            ),
            _opciones(
              clave: 'ndays_visible',
              etiqueta: 'Qué días puede elegir',
              opciones: _diasVisibles,
              ancho: 166,
            ),
          ];
          if (restricciones.maxWidth < Pantalla.media) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final grupo in grupos) ...[
                  grupo,
                  const SizedBox(height: 20),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < grupos.length; i++) ...[
                if (i > 0) const SizedBox(width: 24),
                Expanded(child: grupos[i]),
              ],
            ],
          );
        },
      ),
      const SizedBox(height: 22),
      _botonDeColores(),
      const SizedBox(height: 12),
      // En una tablet los interruptores van a dos columnas: en una sola fila
      // por interruptor sobraba la mitad del ancho y la pantalla no cabía.
      LayoutBuilder(
        builder: (context, restricciones) {
          final enDos = restricciones.maxWidth >= Pantalla.media;
          final ancho = enDos
              ? (restricciones.maxWidth - 24) / 2
              : restricciones.maxWidth;
          return Wrap(
            spacing: 24,
            runSpacing: 0,
            children: [
              for (final entrada in {
                ..._apoyos,
                if (widget.permissions) ..._permisos,
              }.entries)
                SizedBox(
                  width: ancho,
                  child: _interruptor(entrada.key, entrada.value),
                ),
            ],
          );
        },
      ),
    ],
  );

  /// Un ajuste numérico, elegido entre opciones con nombre.
  Widget _opciones({
    required String clave,
    required String etiqueta,
    required List<Opcion<int>> opciones,
    double ancho = 148,
    bool conLetra = false,
  }) {
    final actual = widget.settings.number(clave);
    return OptionPicker<int>(
      label: etiqueta,
      optionWidth: ancho,
      enabled: widget.enabled,
      value: opciones.any((o) => o.value == actual) ? actual : opciones[0].value,
      onChanged: (valor) => setState(() => _guardar(clave, valor)),
      options: conLetra
          // Cada tamaño se enseña con una «A» de ese tamaño: así se elige
          // viendo el resultado y no imaginándolo.
          ? [
              for (final opcion in opciones)
                Opcion(
                  opcion.value,
                  opcion.label,
                  leading: SizedBox(
                    width: 34,
                    child: Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          fontSize: opcion.value.toDouble().clamp(14, 30),
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ]
          : opciones,
    );
  }

  Widget _botonDeColores() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      OutlinedButton.icon(
        onPressed: widget.enabled ? _abrirColores : null,
        icon: const Icon(Icons.palette_outlined),
        label: const Text('Elegir los colores'),
      ),
      const SizedBox(width: 12),
      MuestraDeColor(widget.settings.color('main_col')),
      const SizedBox(width: 8),
      MuestraDeColor(widget.settings.color('sec_col')),
    ],
  );

  Widget _interruptor(String clave, String etiqueta) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(etiqueta),
    value: widget.settings.flag(clave),
    onChanged: widget.enabled
        ? (valor) => setState(() => _guardar(clave, valor))
        : null,
  );
}
