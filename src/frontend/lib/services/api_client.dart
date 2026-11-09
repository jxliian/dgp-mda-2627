import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/domain.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.status});
  final String message;
  final int? code;
  final int? status;
  bool get sessionExpired => code == 1002;
  @override
  String toString() => message;
}

class FeatureUnavailable extends ApiException {
  const FeatureUnavailable(String feature)
    : super(
        '$feature todavía no está disponible en el servidor. Contacta con el administrador.',
      );
}

class ApiClient {
  ApiClient(String baseUrl, {http.Client? client})
    : baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
      _client = client ?? http.Client();
  final Uri baseUri;
  final http.Client _client;
  String? token;
  void Function()? onSessionExpired;
  static const timeout = Duration(seconds: 20);

  Uri uri(String path, [Map<String, String>? query]) {
    final relative = path.startsWith('/') ? path.substring(1) : path;
    return baseUri.resolve(relative).replace(queryParameters: query);
  }

  Future<Json> request(
    String method,
    String path, {
    Json? body,
    Map<String, String>? query,
    bool protected = true,
  }) async {
    final request = http.Request(method, uri(path, query));
    request.headers['Accept'] = 'application/json';
    if (protected && token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    try {
      final response = await http.Response.fromStream(
        await _client.send(request),
      ).timeout(timeout);
      final data = decode(response);
      if (path != '/openapi.json' && data['errorCode'] != 0) {
        throw const ApiException(
          'El servidor no ha confirmado la operación. Vuelve a intentarlo.',
        );
      }
      return data;
    } on TimeoutException {
      throw const ApiException(
        'El servidor tarda en responder. Vuelve a intentarlo.',
      );
    } on http.ClientException {
      throw const ApiException(
        'No se ha podido conectar. Comprueba la conexión y la dirección del servidor.',
      );
    }
  }

  Json decode(http.Response response) {
    Json data;
    try {
      data = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map,
      );
    } on Object {
      throw ApiException(
        'El servidor ha devuelto una respuesta que no se puede leer.',
        status: response.statusCode,
      );
    }
    final code = data['errorCode'];
    // OpenAPI has no envelope; all application endpoints do.
    if (response.statusCode >= 400 || (code != null && code != 0)) {
      if (code == 1002) {
        token = null;
        onSessionExpired?.call();
      }
      throw ApiException(
        response.statusCode >= 500
            ? 'No se ha podido completar la operación. Inténtalo de nuevo.'
            : data['details'] as String? ??
                  'No se ha podido completar la operación.',
        code: code as int?,
        status: response.statusCode,
      );
    }
    return data;
  }

  Future<Uint8List> image(String path) async {
    try {
      final response = await _client
          .get(
            uri(path),
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        decode(response);
      }
      return response.bodyBytes;
    } on TimeoutException {
      throw const ApiException('La imagen tarda en cargar.');
    } on http.ClientException {
      throw const ApiException('No se ha podido cargar la imagen.');
    }
  }

  Future<void> uploadAvatar(Uint8List bytes, String filename) async {
    final request = http.MultipartRequest(
      'PUT',
      uri('/users/students/me/avatar'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    try {
      decode(
        await http.Response.fromStream(
          await _client.send(request),
        ).timeout(timeout),
      );
    } on TimeoutException {
      throw const ApiException(
        'La subida tarda en responder. Vuelve a intentarlo.',
      );
    } on http.ClientException {
      throw const ApiException(
        'No se ha podido subir la foto. Comprueba la conexión.',
      );
    }
  }

  void close() => _client.close();
}

String segment(String value) => Uri.encodeComponent(value);
