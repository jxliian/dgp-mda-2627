import 'package:flutter/material.dart';
import '../theme.dart';

/// Dibujos que explican una opción sin leerla.
///
/// Un alumno que no lee no puede elegir entre «Dos a la vez» y «Tres a la
/// vez». Entre dos tarjetas y tres tarjetas, sí. Estos dibujos enseñan el
/// resultado de la opción, no un icono que haya que interpretar: el tamaño de
/// letra se ve en una letra de ese tamaño, las tareas por página en esa misma
/// cantidad de tarjetas, y los días en los días de una semana.
///
/// Son decorativos a efectos de lectores de pantalla: la tarjeta que los
/// contiene ya lleva el nombre de la opción.
class SimboloDeLetra extends StatelessWidget {
  const SimboloDeLetra(this.tamano, {super.key});

  final int tamano;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Text(
      'Aa',
      style: TextStyle(
        // El tamaño real llega a 32 y no cabría en la tarjeta: se enseña la
        // proporción, que es lo que se compara.
        fontSize: (tamano * 0.9).clamp(15, 30).toDouble(),
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    ),
  );
}

/// Tantas tarjetas apiladas como tareas se ven de una vez.
class SimboloDeTareas extends StatelessWidget {
  const SimboloDeTareas(this.cuantas, {super.key});

  /// Cero significa «todas»: se dibujan cuatro y la última se va.
  final int cuantas;

  @override
  Widget build(BuildContext context) {
    final todas = cuantas == 0;
    final filas = todas ? 4 : cuantas;
    final color = Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < filas; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Container(
                width: 42,
                height: 7,
                decoration: BoxDecoration(
                  color: todas && i == filas - 1
                      ? color.withValues(alpha: .35)
                      : color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Los siete días de la semana, con los que se pueden elegir marcados.
class SimboloDeDias extends StatelessWidget {
  const SimboloDeDias(this.cuantos, {super.key});

  /// Cero significa «solo hoy»: se marca uno.
  final int cuantos;

  @override
  Widget build(BuildContext context) {
    final marcados = cuantos == 0 ? 1 : cuantos;
    final color = Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: Wrap(
        spacing: 3,
        runSpacing: 3,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < 7; i++)
            Container(
              width: 11,
              height: 16,
              decoration: BoxDecoration(
                color: i < marcados ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: i < marcados ? color : Paleta.trazoControl,
                  width: Medidas.trazo,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
