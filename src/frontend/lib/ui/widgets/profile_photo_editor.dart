import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../models/domain.dart';
import '../../services/profile_photos.dart';
import 'notice.dart';
import 'user_avatar.dart';

/// Selector común para cuentas nuevas, administración y ajustes propios.
class ProfilePhotoEditor extends StatefulWidget {
  const ProfilePhotoEditor({
    super.key,
    required this.user,
    required this.onSelected,
    this.photo,
    this.enabled = true,
    this.label = 'Cambiar la foto',
    this.onBusyChanged,
    this.localOnly = true,
  });

  final AppUser user;
  final Uint8List? photo;
  final bool enabled;
  final String label;
  final Future<void> Function(Uint8List) onSelected;
  final ValueChanged<bool>? onBusyChanged;
  final bool localOnly;

  @override
  State<ProfilePhotoEditor> createState() => _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends State<ProfilePhotoEditor> {
  bool busy = false;
  String? error;

  Future<void> select() async {
    if (busy || !widget.enabled) return;
    setState(() {
      busy = true;
      error = null;
    });
    widget.onBusyChanged?.call(true);
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Imágenes PNG, JPEG o WebP',
            extensions: ['png', 'jpg', 'jpeg', 'webp'],
            mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
          ),
        ],
      );
      if (file == null || !mounted) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException('Elige una imagen de hasta 5 MB.');
      }
      final bytes = await prepareProfilePhoto(await file.readAsBytes());
      if (!mounted) return;
      await widget.onSelected(bytes);
    } on Object {
      if (mounted) {
        setState(
          () => error =
              'No se ha podido guardar la foto. Elige una imagen PNG, JPEG o WebP '
              'de hasta 5 MB y comprueba el espacio disponible.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      children: [
        UserAvatar(user: widget.user, size: 130, preview: widget.photo),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.enabled && !busy ? select : null,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(busy ? 'Guardando foto…' : widget.label),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            widget.localOnly
                ? 'La foto se guarda solo en este navegador o equipo. '
                      'No se comparte con otros dispositivos.'
                : 'La foto se guarda en el servidor y se comparte con los '
                      'usuarios que tienen acceso al alumno.',
            textAlign: TextAlign.center,
          ),
        ),
        if (error != null) Notice(error!, error: true),
      ],
    ),
  );
}
