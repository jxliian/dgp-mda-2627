import 'package:flutter/material.dart';
import '../theme.dart';
import 'icon_action.dart';
import 'notice.dart';

/// Lista paginada: muestra pocos elementos a la vez para no saturar.
///
/// Las flechas están **siempre en el mismo sitio**: a izquierda y derecha del
/// contenido, a su misma altura. El hueco de las flechas se reserva aunque no
/// haya más de una página, de modo que el contenido no se desplaza al cambiar
/// de pantalla ni al aparecer la paginación. Las flechas llevan texto
/// descriptivo y el cambio de página se anuncia a los lectores de pantalla.
class PagedItems<T> extends StatefulWidget {
  const PagedItems({
    super.key,
    required this.items,
    required this.builder,
    this.pageSize = 3,
    this.grid = false,
    this.maxColumns = 4,
    this.empty = 'No hay elementos para mostrar.',
  });

  final List<T> items;
  final Widget Function(T item) builder;
  final int pageSize;
  final bool grid;

  /// Columnas como mucho en modo rejilla. Bajarlo agranda cada tarjeta.
  final int maxColumns;
  final String empty;

  @override
  State<PagedItems<T>> createState() => _PagedItemsState<T>();
}

class _PagedItemsState<T> extends State<PagedItems<T>> {
  int page = 0;

  /// Ancho reservado a cada flecha, ocupada o no.
  static const _columnaDeFlecha = 72.0;

  /// Con la letra agrandada cada elemento ocupa proporcionalmente más, así
  /// que caben menos por página. Se reparte en más páginas en vez de obligar
  /// a desplazar: las flechas ya están donde el alumno las conoce.
  int get _porPagina {
    final base = widget.pageSize < 1 ? 1 : widget.pageSize;
    final escala = Pantalla.escalaDeTexto(context);
    if (escala <= 1.2) return base;
    return (base / escala).ceil().clamp(1, base);
  }

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
    return LayoutBuilder(
      builder: (context, restricciones) {
        // En tablet las flechas van siempre a los lados. En un móvil no caben
        // sin estrangular la lista, así que van siempre debajo: dentro de un
        // mismo dispositivo nunca cambian de sitio.
        final aLosLados = restricciones.maxWidth >= Pantalla.media;
        return Column(
          children: [
            if (aLosLados)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _hueco(anterior: true),
                  Expanded(child: contenido),
                  _hueco(anterior: false),
                ],
              )
            else
              contenido,
            if (_hayVariasPaginas) ...[
              const SizedBox(height: 12),
              if (!aLosLados)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _flecha(anterior: true),
                    _flecha(anterior: false),
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
          ],
        );
      },
    );
  }

  /// El hueco existe siempre; la flecha solo cuando hay más de una página.
  Widget _hueco({required bool anterior}) => SizedBox(
    width: _columnaDeFlecha,
    child: _hayVariasPaginas
        ? Align(
            alignment: Alignment.center,
            child: _flecha(anterior: anterior),
          )
        : null,
  );

  Widget _flecha({required bool anterior}) {
    final puede = anterior ? page > 0 : page < _paginas - 1;
    return IconAction(
      icon: anterior ? Icons.chevron_left : Icons.chevron_right,
      label: anterior ? 'Página anterior' : 'Página siguiente',
      onPressed: puede
          ? () => setState(() => anterior ? page-- : page++)
          : null,
    );
  }

  Widget _columna(List<T> visibles) =>
      Column(children: visibles.map(widget.builder).toList());

  Widget _rejilla(List<T> visibles) => LayoutBuilder(
    builder: (context, restricciones) {
      final cabenPorAncho =
          ((restricciones.maxWidth + 18) / (Pantalla.anchoDeTarjeta + 18))
              .floor();
      final columnas = cabenPorAncho.clamp(1, widget.maxColumns);
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
