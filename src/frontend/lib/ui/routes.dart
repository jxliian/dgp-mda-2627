import 'package:flutter/material.dart';

/// Abre una pantalla encima de la actual y espera su resultado.
Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));

/// Vuelve a la pantalla de inicio de la sesión actual.
void goHome(BuildContext context) =>
    Navigator.of(context).popUntil((route) => route.isFirst);
