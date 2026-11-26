import 'package:flutter/material.dart';
import '../theme.dart';

/// Una opción elegible dentro de un [OptionPicker].
class Opcion<T> {
  const Opcion(this.value, this.label, {this.leading});

  /// Lo que se guarda al elegirla.
  final T value;

  /// Lo que se lee: siempre en palabras, nunca un número suelto.
  final String label;

  /// Muestra opcional a la izquierda: un color, una letra de ejemplo.
  final Widget? leading;
}

/// Grupo de opciones con forma de tarjeta, todas iguales y todas pulsables.
///
/// Sustituye a los campos de texto de los ajustes. Nadie debería tener que
/// escribir «20» para agrandar la letra ni «#1b4332» para elegir un color:
/// quien configura la agenda de un alumno elige entre opciones preparadas, y
/// no hay forma de escribir algo que no valga.
///
/// Cada tarjeta se anuncia como botón con su estado de selección, de modo que
/// con lector de pantalla se recorre igual que un grupo de opciones.
class OptionPicker<T> extends StatelessWidget {
  const OptionPicker({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.hint,
    this.enabled = true,
    this.optionWidth = 148,
    this.vertical = false,
  });

  final String label;
  final String? hint;
  final List<Opcion<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool enabled;

  /// Ancho de cada tarjeta cuando van en fila envolvente.
  final double optionWidth;

  /// Con el dibujo arriba y el nombre debajo, todas las opciones repartidas
  /// en una sola fila. Es la forma que se usa cuando lo que distingue a una
  /// opción de otra es el dibujo y no la palabra.
  final bool vertical;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      if (hint != null)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(hint!, style: Theme.of(context).textTheme.bodyMedium),
        ),
      const SizedBox(height: 8),
      if (vertical)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _Tarjeta<T>(
                  opcion: options[i],
                  elegida: options[i].value == value,
                  enabled: enabled,
                  vertical: true,
                  onTap: () => onChanged(options[i].value),
                ),
              ),
            ],
          ],
        )
      else
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final opcion in options)
              _Tarjeta<T>(
                opcion: opcion,
                elegida: opcion.value == value,
                enabled: enabled,
                ancho: optionWidth,
                onTap: () => onChanged(opcion.value),
              ),
          ],
        ),
    ],
  );
}

/// Alto reservado al dibujo de una opción. Los dibujos de
/// `option_symbols.dart` están hechos para caber justo aquí.
const _altoDelSimbolo = 44.0;

class _Tarjeta<T> extends StatelessWidget {
  const _Tarjeta({
    required this.opcion,
    required this.elegida,
    required this.enabled,
    required this.onTap,
    this.ancho,
    this.vertical = false,
  });

  final Opcion<T> opcion;
  final bool elegida;
  final bool enabled;
  final double? ancho;
  final bool vertical;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(Medidas.radioControl);
    return Semantics(
      button: true,
      selected: elegida,
      label: opcion.label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: radio,
          child: Ink(
            width: ancho,
            padding: EdgeInsets.symmetric(
              horizontal: vertical ? 6 : 10,
              vertical: vertical ? 8 : 8,
            ),
            decoration: BoxDecoration(
              color: elegida
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : null,
              borderRadius: radio,
              border: Border.all(
                color: elegida ? Paleta.bosque : Paleta.trazoControl,
                width: elegida ? Medidas.anilloFoco : Medidas.trazo,
              ),
            ),
            child: vertical ? _enColumna(context) : _enFila(),
          ),
        ),
      ),
    );
  }

  /// El dibujo manda y el nombre acompaña: quien no lee se guía por el
  /// primero y quien lee confirma con el segundo.
  Widget _enColumna(BuildContext context) {
    // Dos líneas de nombre siempre reservadas, crezca o no el texto del
    // sistema: así las cuatro tarjetas de un grupo miden exactamente igual.
    const tamano = 14.0;
    const interlineado = 1.2;
    final lineas = Pantalla.letraGrande(context) ? 1 : 2;
    final altoDelNombre =
        MediaQuery.textScalerOf(context).scale(tamano) * interlineado * lineas;
    return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(height: _altoDelSimbolo, child: Center(child: opcion.leading)),
      const SizedBox(height: 8),
      SizedBox(
        height: altoDelNombre,
        child: Text(
          opcion.label,
          textAlign: TextAlign.center,
          maxLines: lineas,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: tamano,
            height: interlineado,
            fontWeight: elegida ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      // El hueco de la marca existe siempre: si solo lo tuviera la elegida,
      // esa tarjeta mediria mas que las demas.
      SizedBox(
        height: 22,
        child: elegida
            ? const Align(
                alignment: Alignment.bottomCenter,
                child: Icon(Icons.check, size: 18),
              )
            : null,
      ),
    ],
    );
  }

  Widget _enFila() => Row(
    children: [
      if (opcion.leading != null) ...[
        opcion.leading!,
        const SizedBox(width: 10),
      ],
      Expanded(
        child: Text(
          opcion.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: elegida ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      if (elegida) const Icon(Icons.check, size: 20),
    ],
  );
}

/// Cuadrito de color para usar como [Opcion.leading].
class MuestraDeColor extends StatelessWidget {
  const MuestraDeColor(this.hex, {super.key, this.size = 34});

  final String hex;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: colorDesdeHex(hex),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Paleta.trazoControl),
    ),
  );
}
