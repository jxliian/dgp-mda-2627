import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/domain.dart';

/// Fotos locales: no se envían al servidor ni se mezclan con la demostración.
class ProfilePhotos {
  final _demo = <String, Uint8List>{};

  String _key(String server, AppUser user) =>
      'autovida/profile-photo/${jsonEncode([server, user.role.name, user.username])}';

  Future<Uint8List?> read(
    String server,
    AppUser user, {
    bool demo = false,
  }) async {
    final key = _key(server, user);
    if (demo) return _demo[key];
    final value = (await SharedPreferences.getInstance()).getString(key);
    if (value == null) return null;
    try {
      return base64Decode(value);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(
    String server,
    AppUser user,
    Uint8List image, {
    bool demo = false,
  }) async {
    final key = _key(server, user);
    if (demo) {
      _demo[key] = Uint8List.fromList(image);
      return;
    }
    final saved = await (await SharedPreferences.getInstance()).setString(
      key,
      base64Encode(image),
    );
    if (!saved) {
      throw StateError('No se ha podido guardar la foto en este equipo.');
    }
  }

  Future<void> remove(String server, AppUser user, {bool demo = false}) async {
    final key = _key(server, user);
    if (demo) {
      _demo.remove(key);
    } else {
      final removed = await (await SharedPreferences.getInstance()).remove(key);
      if (!removed) throw StateError('No se ha podido retirar la foto local.');
    }
  }

  void clearDemo() => _demo.clear();
}

/// Valida el contenido y guarda una copia PNG reducida, sin metadatos originales.
Future<Uint8List> prepareProfilePhoto(Uint8List bytes) async {
  if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
    throw const FormatException('Elige una imagen de hasta 5 MB.');
  }
  final png =
      bytes.length >= 8 &&
      const [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ].asMap().entries.every((entry) => bytes[entry.key] == entry.value);
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
  final webp =
      bytes.length >= 12 &&
      String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
      String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP';
  if (!png && !jpeg && !webp) {
    throw const FormatException('Elige una imagen PNG, JPEG o WebP.');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final largest = descriptor.width > descriptor.height
          ? descriptor.width
          : descriptor.height;
      final scale = largest > 512 ? 512 / largest : 1.0;
      final codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round().clamp(1, 512),
        targetHeight: (descriptor.height * scale).round().clamp(1, 512),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data == null) {
            throw const FormatException('No se puede leer la imagen.');
          }
          return data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}
