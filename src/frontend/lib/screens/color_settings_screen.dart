import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../ui/ui.dart';

/// Colores de la agenda de un alumno, en su propia pantalla.
///
/// Antes eran dos campos sueltos perdidos entre los demás ajustes. Aquí cada
/// color se elige de una paleta propuesta ---o escribiéndolo a mano, si hace
/// falta--- y se ve el resultado antes de guardar.
class ColorSettingsScreen extends StatefulWidget {
  const ColorSettingsScreen({
    super.key,
    required this.settings,
    this.enabled = true,
  });

  final AccessSettings settings;
  final bool enabled;

  @override
  State<ColorSettingsScreen> createState() => _ColorSettingsScreenState();
}

class _ColorSettingsScreenState extends State<ColorSettingsScreen> {
  static const _principales = [
    ('#fbf9f5', 'Lino'),
    ('#ffffff', 'Blanco'),
    ('#eef5f0', 'Verde claro'),
    ('#fdf1dc', 'Crema'),
    ('#e8eef7', 'Azul claro'),
    ('#1f2a24', 'Oscuro'),
  ];
  static const _secundarios = [
    ('#1b4332', 'Verde'),
    ('#1d3557', 'Azul'),
    ('#8a3a22', 'Terracota'),
    ('#5b2a86', 'Morado'),
    ('#7a4b06', 'Ámbar'),
    ('#111111', 'Negro'),
  ];

  static final _formato = RegExp(r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');

  void _guardar(String clave, String valor) =>
      setState(() => widget.settings.values['stud_access_$clave'] = valor);

  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Colores de la agenda',
    subtitle: 'Visualización del alumno',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _vistaPrevia(),
        LayoutBuilder(
          builder: (context, restricciones) {
            final principal = _bloque(
              clave: 'main_col',
              titulo: 'Color principal',
              ayuda: 'Es el fondo de la agenda.',
              paleta: _principales,
            );
            final secundario = _bloque(
              clave: 'sec_col',
              titulo: 'Color secundario',
              ayuda: 'Es el de los botones.',
              paleta: _secundarios,
            );
            if (restricciones.maxWidth < Pantalla.media) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [principal, secundario],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: principal),
                const SizedBox(width: 32),
                Expanded(child: secundario),
              ],
            );
          },
        ),
        ScreenActions(
          primary: FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('Usar estos colores'),
          ),
        ),
      ],
    ),
  );

  Widget _vistaPrevia() {
    final fondo = colorDesdeHex(widget.settings.color('main_col'));
    final acento = colorDesdeHex(widget.settings.color('sec_col'));
    final claro = fondo.computeLuminance() > .45;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(Medidas.radioTarjeta),
        border: Border.all(color: Paleta.trazoControl, width: Medidas.trazo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Así se verá su agenda',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: claro ? Paleta.tinta : Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: acento,
              borderRadius: BorderRadius.circular(Medidas.radioControl),
            ),
            child: const Text(
              'He terminado la tarea',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloque({
    required String clave,
    required String titulo,
    required String ayuda,
    required List<(String, String)> paleta,
  }) {
    final actual = widget.settings.color(clave).toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(titulo, hint: ayuda),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final (valor, nombre) in paleta)
              _muestra(clave, valor, nombre, elegido: valor == actual),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 300,
          child: TextFormField(
            key: ValueKey('$clave/$actual'),
            initialValue: widget.settings.color(clave),
            enabled: widget.enabled,
            decoration: InputDecoration(
              labelText: 'O escribe el color (#RRGGBB)',
              errorText: _formato.hasMatch(widget.settings.color(clave))
                  ? null
                  : 'Usa un color como #1b4332.',
            ),
            onChanged: (valor) {
              if (_formato.hasMatch(valor)) _guardar(clave, valor);
            },
          ),
        ),
      ],
    );
  }

  Widget _muestra(
    String clave,
    String valor,
    String nombre, {
    required bool elegido,
  }) => Semantics(
    button: true,
    selected: elegido,
    label: nombre,
    child: InkWell(
      onTap: widget.enabled ? () => _guardar(clave, valor) : null,
      borderRadius: BorderRadius.circular(Medidas.radioControl),
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Medidas.radioControl),
          border: Border.all(
            color: elegido ? Paleta.bosque : Paleta.trazoControl,
            width: elegido ? Medidas.anilloFoco : Medidas.trazo,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colorDesdeHex(valor),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Paleta.trazoControl),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            if (elegido) const Icon(Icons.check, size: 20),
          ],
        ),
      ),
    ),
  );
}
