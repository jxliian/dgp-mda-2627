import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/domain.dart';
import '../../state/app_state.dart';
import '../theme.dart';

/// Foto de perfil de una persona. Si no hay foto, dibuja una silueta.
///
/// Solo pide la imagen al servidor cuando la sesión actual tiene permiso para
/// verla; así una cuenta sin acceso no provoca errores en pantalla.
class UserAvatar extends StatefulWidget {
  const UserAvatar({super.key, required this.user, this.size = 72});

  final AppUser user;
  final double size;

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
    if (oldWidget.user.username != widget.user.username) {
      _cargar(AppScope.of(context));
    }
  }

  void _cargar(AppState state) {
    imagen = _puedeVerla(state)
        ? state.repository.avatar(widget.user)
        : Future.value(null);
  }

  bool _puedeVerla(AppState state) {
    final esSuya = state.user?.username == widget.user.username;
    final esDelDirectorio =
        widget.user.avatarUrl?.startsWith('/auth/student-directory/') ?? false;
    const rolesConAcceso = {UserRole.staff, UserRole.parent, UserRole.admin};
    return state.demo ||
        esSuya ||
        esDelDirectorio ||
        rolesConAcceso.contains(state.user?.role);
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
            future: imagen,
            builder: (context, snapshot) => _dibujar(snapshot.data),
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
