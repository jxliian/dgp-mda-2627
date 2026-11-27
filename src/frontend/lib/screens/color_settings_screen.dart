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
  /// Fondos: claros y de poco brillo, más uno oscuro para quien lo prefiere.
  /// Todos dan 12,7:1 o más con el texto de tinta; el oscuro cambia el tema a
  /// texto blanco. Ninguna combinación elegible aquí baja del 7:1 que se
  /// comprometió el proyecto, que es lo que permite quitar el campo libre.
  static const _principales = [
    Opcion('#fbf9f5', 'Lino'),
    Opcion('#ffffff', 'Blanco'),
    Opcion('#eef5f0', 'Verde claro'),
    Opcion('#e8eef7', 'Azul claro'),
    Opcion('#fdf1dc', 'Crema'),
    Opcion('#fbece5', 'Rosa claro'),
    Opcion('#f1ecf7', 'Lila claro'),
    Opcion('#eceff1', 'Gris claro'),
    Opcion('#1f2a24', 'Oscuro'),
  ];

  /// Acentos: el texto blanco encima de cualquiera de ellos pasa de 7:1
  /// ---el más justo es el ámbar, 7,40:1---, de modo que no hace falta
  /// comprobar nada al elegir.
  static const _secundarios = [
    Opcion('#1b4332', 'Verde'),
    Opcion('#1d3557', 'Azul'),
    Opcion('#8a3a22', 'Terracota'),
    Opcion('#5b2a86', 'Morado'),
    Opcion('#7a4b06', 'Ámbar'),
    Opcion('#005d75', 'Turquesa'),
    Opcion('#9b1b4b', 'Frambuesa'),
    Opcion('#3f4c44', 'Pizarra'),
    Opcion('#111111', 'Negro'),
  ];

  void _guardar(String clave, String valor) =>
      setState(() => widget.settings.values['stud_access_$clave'] = valor);

  /// Si el color guardado no está en la paleta ---por ejemplo, uno escrito a
  /// mano antes de que esta pantalla dejara de pedirlo--- se respeta y se
  /// añade al final como «El de siempre», para no cambiárselo a nadie sin
  /// avisar.
  List<Opcion<String>> _conElActual(
    List<Opcion<String>> paleta,
    String actual,
  ) => paleta.any((o) => o.value.toLowerCase() == actual.toLowerCase())
      ? paleta
      : [...paleta, Opcion(actual, 'El de siempre')];

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
    required List<Opcion<String>> paleta,
  }) {
    final actual = widget.settings.color(clave);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: OptionPicker<String>(
        label: titulo,
        hint: ayuda,
        enabled: widget.enabled,
        value: actual,
        onChanged: (valor) => _guardar(clave, valor),
        options: [
          for (final opcion in _conElActual(paleta, actual))
            Opcion(
              opcion.value,
              opcion.label,
              leading: MuestraDeColor(opcion.value),
            ),
        ],
      ),
    );
  }

}
