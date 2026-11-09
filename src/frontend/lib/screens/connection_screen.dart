import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';

/// Permite apuntar la aplicación al servidor del centro.
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final form = GlobalKey<FormState>();
  TextEditingController? _direccion;

  TextEditingController get direccion => _direccion!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _direccion ??= TextEditingController(text: AppScope.of(context).serverUrl);
  }

  @override
  void dispose() {
    direccion.dispose();
    super.dispose();
  }

  /// Acepta solo direcciones http o https limpias, sin credenciales ni
  /// parámetros, para no enviar datos de sesión a un destino inesperado.
  String? validarDireccion(String? valor) {
    final uri = Uri.tryParse(valor?.trim() ?? '');
    final valida =
        uri != null &&
        ['http', 'https'].contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.userInfo.isEmpty;
    return valida
        ? null
        : 'Escribe una dirección http o https válida, sin credenciales ni parámetros.';
  }

  void guardar() {
    if (!form.currentState!.validate()) return;
    AppScope.of(context).setServer(direccion.text.trim());
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Conexión al servidor',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Notice(
            'Introduce la dirección de la API de Autovida proporcionada por el equipo.',
          ),
          TextFormField(
            controller: direccion,
            keyboardType: TextInputType.url,
            validator: validarDireccion,
            decoration: const InputDecoration(labelText: 'Dirección de la API'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: guardar,
            icon: const Icon(Icons.check),
            label: const Text('Usar este servidor'),
          ),
        ],
      ),
    ),
  );
}
