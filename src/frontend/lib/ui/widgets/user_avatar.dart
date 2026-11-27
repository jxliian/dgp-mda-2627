import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/domain.dart';
import '../../state/app_state.dart';
import '../theme.dart';

/// Foto de perfil de una persona. Si no hay foto, dibuja una silueta.
///
/// La API comprueba los permisos de consulta. Si no permite ver la imagen,
/// se muestra la silueta sin interrumpir la pantalla.
class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.size = 72,
    this.preview,
  });

  final AppUser user;
  final double size;
  final Uint8List? preview;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  Future<Uint8List?>? imagen;
  int version = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    if (version != state.avatarVersion) {
      version = state.avatarVersion;
      _cargar(state);
    }
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.username != widget.user.username ||
        oldWidget.user.role != widget.user.role ||
        oldWidget.user.avatarUrl != widget.user.avatarUrl) {
      _cargar(AppScope.of(context));
    }
  }

  void _cargar(AppState state) {
    imagen = state.profilePhoto(widget.user, loadRemote: _puedeVerla(state));
  }

  bool _puedeVerla(AppState state) {
    // La API comprueba los vínculos del usuario con la cuenta consultada.
    // Una cuenta que no es de alumno y no tiene ruta de foto no se pide: el
    // servidor solo guarda la del alumnado y la petición acabaría en un 404.
    if (!state.demo &&
        widget.user.role != UserRole.student &&
        widget.user.avatarUrl == null) {
      return false;
    }
    return state.demo ||
        state.user != null ||
        widget.user.role == UserRole.student && widget.user.avatarUrl != null;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Foto de ${widget.user.displayName}',
    image: true,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Medidas.radioTarjeta),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: Medidas.trazoGrueso,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          Medidas.radioTarjeta - Medidas.trazoGrueso,
        ),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: FutureBuilder<Uint8List?>(
            key: ObjectKey(imagen),
            future: imagen,
            builder: (context, snapshot) =>
                _dibujar(widget.preview ?? snapshot.data),
          ),
        ),
      ),
    ),
  );

  Widget _dibujar(Uint8List? bytes) {
    if (bytes == null) return _silueta();
    if (String.fromCharCodes(bytes.take(100)).contains('<svg')) {
      return SvgPicture.memory(bytes, fit: BoxFit.cover);
    }
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _silueta(),
    );
  }

  Widget _silueta() => Container(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Icon(
      Icons.person_outline,
      size: widget.size * .6,
      color: Theme.of(context).colorScheme.onPrimaryContainer,
    ),
  );
}
