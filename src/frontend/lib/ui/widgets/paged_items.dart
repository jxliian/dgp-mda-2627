import 'package:flutter/material.dart';
import 'icon_action.dart';
import 'notice.dart';

/// Lista paginada: muestra pocos elementos a la vez para no saturar.
///
/// Sigue los bocetos del centro: las flechas van a los lados de la lista, a su
/// misma altura, y el número de página debajo. Las flechas llevan texto
/// descriptivo y el cambio de página se anuncia a los lectores de pantalla.
class PagedItems<T> extends StatefulWidget {
  const PagedItems({
    super.key,
    required this.items,
    required this.builder,
    this.pageSize = 3,
    this.grid = false,
    this.empty = 'No hay elementos para mostrar.',
  });

  final List<T> items;
  final Widget Function(T item) builder;
  final int pageSize;
  final bool grid;
  final String empty;

  @override
  State<PagedItems<T>> createState() => _PagedItemsState<T>();
}

class _PagedItemsState<T> extends State<PagedItems<T>> {
  int page = 0;

  int get _porPagina => widget.pageSize < 1 ? 1 : widget.pageSize;
  int get _paginas => (widget.items.length / _porPagina).ceil();
  bool get _hayVariasPaginas => _paginas > 1;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return Notice(widget.empty);
    if (page >= _paginas) page = _paginas - 1;
    final visibles = widget.items
        .skip(page * _porPagina)
        .take(_porPagina)
        .toList();
    final contenido = widget.grid ? _rejilla(visibles) : _columna(visibles);
    if (!_hayVariasPaginas) return contenido;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconAction(
              icon: Icons.chevron_left,
              label: 'Página anterior',
              onPressed: page > 0 ? () => setState(() => page--) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: contenido),
            const SizedBox(width: 12),
            IconAction(
              icon: Icons.chevron_right,
              label: 'Página siguiente',
              onPressed: page < _paginas - 1
                  ? () => setState(() => page++)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            'Página ${page + 1} de $_paginas',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _columna(List<T> visibles) =>
      Column(children: visibles.map(widget.builder).toList());

  Widget _rejilla(List<T> visibles) => LayoutBuilder(
    builder: (context, restricciones) {
      final columnas = switch (restricciones.maxWidth) {
        < 460 => 1,
        < 760 => 2,
        _ => 4,
      };
      final ancho = (restricciones.maxWidth - (columnas - 1) * 18) / columnas;
      return Wrap(
        spacing: 18,
        runSpacing: 8,
        children: visibles
            .map((item) => SizedBox(width: ancho, child: widget.builder(item)))
            .toList(),
      );
    },
  );
}
