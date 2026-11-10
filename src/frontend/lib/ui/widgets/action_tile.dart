import 'package:flutter/material.dart';
import '../theme.dart';

/// Ficha pulsable: el elemento con el que se navega en toda la aplicación.
///
/// Lleva un filo de color a la izquierda que da identidad a la lista sin
/// recurrir a sombras ni degradados. Toda la ficha es un único objetivo
/// táctil, salvo la acción opcional de la derecha.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.leading,
    this.vertical = false,
    this.badges = const [],
    this.edge = Paleta.bosque,
    this.height,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final String? subtitle;

  /// Acción secundaria (por ejemplo, eliminar). Queda fuera del área pulsable.
  final Widget? trailing;

  /// Sustituye al icono: una foto o un pictograma.
  final Widget? leading;

  /// Disposición en columna, para rejillas de fotos o de días.
  final bool vertical;
  final List<Widget> badges;
  final Color edge;

  /// Altura fija, para las fichas que deben llenar la pantalla.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filo de color: identifica la ficha sin añadir texto ni sombras.
            SizedBox(
              width: Medidas.filoTarjeta,
              child: ColoredBox(color: edge),
            ),
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: height ?? Medidas.alturaBoton,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    // Centrado: en una ficha alta, el contenido pegado arriba
                    // deja un vacío que se lee como un error de maquetación.
                    child: Center(
                      child: vertical
                          ? _contenidoVertical(context)
                          : _contenidoHorizontal(context, scheme),
                    ),
                  ),
                ),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: trailing!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _contenidoHorizontal(BuildContext context, ColorScheme scheme) => Row(
    children: [
      _imagen(scheme),
      const SizedBox(width: 20),
      Expanded(child: _textos(context)),
      if (trailing == null && onTap != null)
        Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
    ],
  );

  Widget _contenidoVertical(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _imagen(Theme.of(context).colorScheme),
      const SizedBox(height: 18),
      _textos(context),
    ],
  );

  Widget _imagen(ColorScheme scheme) =>
      leading ??
      ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(Medidas.radioControl),
            border: Border.all(
              color: scheme.outlineVariant,
              width: Medidas.trazo,
            ),
          ),
          child: Icon(
            icon,
            size: vertical
                ? Medidas.iconoFichaVertical
                : Medidas.iconoFicha,
            color: scheme.onPrimaryContainer,
          ),
        ),
      );

  Widget _textos(BuildContext context) {
    final alineacionTexto = vertical ? TextAlign.center : TextAlign.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: vertical
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: alineacionTexto,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: .15,
            height: 1.25,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: alineacionTexto,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: vertical ? WrapAlignment.center : WrapAlignment.start,
            children: badges,
          ),
        ],
      ],
    );
  }
}
