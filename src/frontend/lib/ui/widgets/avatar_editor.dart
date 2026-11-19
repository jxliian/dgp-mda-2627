import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import '../../models/domain.dart';
import '../../state/app_state.dart';
import 'notice.dart';
import 'section_title.dart';
import 'user_avatar.dart';

/// Foto de una persona con su botón de cambiarla, igual para cualquier rol.
///
/// La misma pieza vale para la propia foto, desde los ajustes, y para la de
/// otra cuenta, desde administración: solo cambia quién la sube.
class AvatarEditor extends StatefulWidget {
  const AvatarEditor({
    super.key,
    required this.user,
    required this.upload,
    this.allowed = true,
    this.busy = false,
    this.note,
    this.size = 150,
    this.title = 'Foto',
  });

  final AppUser user;

  /// Envía la imagen elegida. Lo concreta quien use el editor.
  final Future<void> Function(Uint8List bytes, String filename) upload;

  /// Si el servidor acepta cambiar esta foto.
  final bool allowed;
  final bool busy;

  /// Explicación que se muestra cuando no se puede cambiar.
  final String? note;
  final double size;
  final String title;

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  bool subiendo = false;
  String? error;
  String? aviso;

  static const _maximoBytes = 5 * 1024 * 1024;

  Future<void> cambiar() async {
    try {
      final archivo = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Imágenes PNG, JPEG o WebP',
            extensions: ['png', 'jpg', 'jpeg', 'webp'],
          ),
        ],
      );
      if (archivo == null) return;
      if (await archivo.length() > _maximoBytes) {
        throw StateError('La imagen no puede superar los 5 MB.');
      }
      if (!mounted) return;
      setState(() {
        subiendo = true;
        error = null;
        aviso = null;
      });
      await widget.upload(await archivo.readAsBytes(), archivo.name);
      if (!mounted) return;
      AppScope.of(context).photoChanged();
      setState(() => aviso = 'La foto se ha actualizado.');
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SectionTitle(widget.title, centered: true),
      UserAvatar(user: widget.user, size: widget.size),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: widget.allowed && !widget.busy && !subiendo
            ? cambiar
            : null,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(subiendo ? 'Subiendo…' : 'Cambiar la foto'),
      ),
      if (!widget.allowed && widget.note != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            widget.note!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      if (error != null) Notice(error!, error: true),
      if (aviso != null) Notice(aviso!),
    ],
  );
}
