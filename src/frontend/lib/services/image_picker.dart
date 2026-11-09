import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'api_client.dart';

Future<Uint8List?> pickPicture() async {
  final file = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(
        label: 'Imágenes PNG, JPEG o WebP',
        extensions: ['png', 'jpg', 'jpeg', 'webp'],
      ),
    ],
  );
  if (file == null) return null;
  if (await file.length() > 5 * 1024 * 1024) {
    throw const ApiException('La imagen no puede superar los 5 MB.');
  }
  return file.readAsBytes();
}
