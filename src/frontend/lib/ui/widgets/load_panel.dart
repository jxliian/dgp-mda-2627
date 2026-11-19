import 'package:flutter/material.dart';
import 'notice.dart';

/// Carga datos y muestra, en este orden: el error con opción de reintentar,
/// el indicador de espera, o el contenido.
class LoadPanel<T> extends StatefulWidget {
  const LoadPanel({super.key, required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(T data) builder;

  @override
  State<LoadPanel<T>> createState() => _LoadPanelState<T>();
}

class _LoadPanelState<T> extends State<LoadPanel<T>> {
  late Future<T> peticion;

  @override
  void initState() {
    super.initState();
    peticion = widget.load();
  }

  void reintentar() => setState(() => peticion = widget.load());

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: peticion,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Notice(
          snapshot.error.toString(),
          error: true,
          action: OutlinedButton.icon(
            onPressed: reintentar,
            icon: const Icon(Icons.refresh),
            label: const Text('Volver a intentar'),
          ),
        );
      }
      // Se mira el estado y no `hasData`: hay cargas cuyo resultado válido es
      // nulo ---por ejemplo, un alumno que todavía no tiene aula--- y con
      // `hasData` se quedaban girando para siempre.
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(48),
          child: Center(
            child: CircularProgressIndicator(semanticsLabel: 'Cargando'),
          ),
        );
      }
      return widget.builder(snapshot.data as T);
    },
  );
}
