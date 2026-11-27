import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../models/domain.dart';
import '../../services/profile_photos.dart';
import '../theme.dart';
import 'action_tile.dart';
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
    this.onError,
    this.localOnly = true,
    this.asTile = false,
    this.vertical = false,
    this.height,
    this.edge = Paleta.terracota,
  });

  final AppUser user;
  final Uint8List? photo;
  final bool enabled;
  final String label;
  final Future<void> Function(Uint8List) onSelected;
  final ValueChanged<bool>? onBusyChanged;
  final ValueChanged<String?>? onError;
  final bool localOnly;

  /// En los ajustes del alumnado se muestra como ficha grande pulsable
  /// simétrica al resto de opciones, en lugar de botón suelto.
  final bool asTile;
  final bool vertical;
  final double? height;
  final Color edge;

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
    widget.onError?.call(null);
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
        const message =
            'No se ha podido guardar la foto. Elige una imagen PNG, JPEG o WebP '
            'de hasta 5 MB y comprueba el espacio disponible.';
        if (widget.onError != null) {
          widget.onError!(message);
        } else {
          setState(() => error = message);
        }
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  String get _dondeSeGuarda => widget.localOnly
      ? 'Solo en esta demostración.'
      : 'Se guarda en el servidor.';

  @override
  Widget build(BuildContext context) {
    if (widget.asTile) {
      final apretado = Pantalla.letraGrande(context);
      final tamanoFoto = widget.vertical
          ? (apretado ? 80.0 : 148.0)
          : (apretado ? 84.0 : 104.0);
      final activo = widget.enabled && !busy;
      final ficha = Semantics(
        button: true,
        enabled: activo,
        child: ActionTile(
          title: busy ? 'Guardando foto…' : widget.label,
          subtitle: _dondeSeGuarda,
          icon: Icons.add_a_photo_outlined,
          leading: UserAvatar(
            user: widget.user,
            size: tamanoFoto,
            preview: widget.photo,
          ),
          vertical: widget.vertical,
          height: widget.height,
          edge: widget.edge,
          onTap: activo ? select : null,
        ),
      );
      if (error == null) return ficha;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [ficha, Notice(error!, error: true)],
      );
    }
    return Center(
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
              // Dónde se guarda, en cuatro palabras: el párrafo largo que
              // había aquí ocupaba media columna para decir lo mismo.
              _dondeSeGuarda,
              textAlign: TextAlign.center,
            ),
          ),
          if (error != null) Notice(error!, error: true),
        ],
      ),
    );
  }
}
