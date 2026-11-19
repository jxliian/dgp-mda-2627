import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'class_picker_screen.dart';
import 'person_picker_screen.dart';

/// Asociaciones entre alumnos y tutores o familias (SCRUM-14, 23 y 16).
///
/// Los alumnos del personal del centro no se asocian aquí: se derivan de las
/// aulas; desde aquí se puede asignar el personal a un aula.
class AssociationsScreen extends StatefulWidget {
  const AssociationsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AssociationsScreen> createState() => _AssociationsScreenState();
}

class _AssociationsScreenState extends State<AssociationsScreen> {
  int revision = 0;
  bool ocupado = false;
  String? aviso;
  String? error;

  bool get esPersonal => widget.user.role == UserRole.staff;
  bool get esAlumno => widget.user.role == UserRole.student;

  /// El rol que se puede asociar al de esta cuenta.
  UserRole get rolComplementario =>
      esAlumno ? UserRole.parent : UserRole.student;

  Future<List<AppUser>> _asociados() {
    final repositorio = AppScope.of(context).repository;
    return esAlumno
        ? repositorio.parents(widget.user.username)
        : repositorio.linkedStudents(widget.user);
  }

  Future<void> _asociar(String username, {required bool retirar}) async {
    setState(() {
      ocupado = true;
      error = null;
      aviso = null;
    });
    try {
      final alumno = esAlumno ? widget.user.username : username;
      final tutor = esAlumno ? username : widget.user.username;
      await AppScope.of(
        context,
      ).repository.linkParent(alumno, tutor, remove: retirar);
      if (mounted) {
        setState(() {
          revision++;
          aviso = retirar ? 'Asociación retirada.' : 'Asociación añadida.';
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> _asignarAula() async {
    if (ocupado) return;
    final aula = await openPage<String>(
      context,
      const ClassPickerScreen(title: 'Asignar a un aula'),
    );
    if (aula == null || !mounted) return;
    setState(() {
      ocupado = true;
      error = null;
      aviso = null;
    });
    try {
      await AppScope.of(
        context,
      ).repository.addStaff(aula, widget.user.username);
      if (mounted) AppScope.of(context).classroomsChanged();
      if (mounted) {
        setState(() {
          revision++;
          aviso = 'Personal asignado al aula $aula.';
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Asociaciones de ${widget.user.displayName}',
    subtitle: widget.user.role.label,
    child: Column(
      children: [
        if (esPersonal) const Notice(_personalSeAsignaPorAulas),
        if (esPersonal) _asignacionDeAula(),
        LoadPanel<List<AppUser>>(
          key: ValueKey(revision),
          load: _asociados,
          builder: (asociados) => Column(
            children: [
              for (final persona in asociados) _ficha(persona),
              if (!esPersonal) _nuevaAsociacion(asociados),
            ],
          ),
        ),
        if (error != null) Notice(error!, error: true),
        if (aviso != null) Notice(aviso!),
      ],
    ),
  );

  Widget _asignacionDeAula() => Column(
    children: [
      FilledButton.icon(
        onPressed: ocupado ? null : _asignarAula,
        icon: const Icon(Icons.school_outlined),
        label: const Text('Asignar personal al aula'),
      ),
      const SectionTitle('Alumnos de sus aulas'),
    ],
  );

  Widget _ficha(AppUser persona) => ActionTile(
    title: persona.displayName,
    subtitle: persona.username,
    icon: Icons.person_outline,
    onTap: null,
    trailing: esPersonal
        ? null
        : IconAction(
            icon: Icons.link_off,
            label: 'Retirar la asociación con ${persona.displayName}',
            onPressed: ocupado
                ? null
                : () => _asociar(persona.username, retirar: true),
          ),
  );

  /// La cuenta a asociar se elige en una pantalla con el filtro de rol ya
  /// aplicado, no en un desplegable donde no se ve a quién se elige.
  Widget _nuevaAsociacion(List<AppUser> yaAsociados) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: FilledButton.icon(
      onPressed: ocupado ? null : () => _elegirYAsociar(yaAsociados),
      icon: const Icon(Icons.add),
      label: Text(
        esAlumno ? 'Asociar un tutor familiar' : 'Asociar un alumno',
      ),
    ),
  );

  Future<void> _elegirYAsociar(List<AppUser> yaAsociados) async {
    final elegida = await openPage<AppUser>(
      context,
      PersonPickerScreen(
        title: esAlumno ? 'Elegir tutor familiar' : 'Elegir alumno',
        role: rolComplementario,
        exclude: [
          widget.user.username,
          ...yaAsociados.map((cuenta) => cuenta.username),
        ],
      ),
    );
    if (elegida != null && mounted) {
      await _asociar(elegida.username, retirar: false);
    }
  }

  static const _personalSeAsignaPorAulas =
      'Asigna un aula a este miembro del personal para vincularlo con sus alumnos. '
      'También puedes gestionar el personal desde la edición de cada aula.';
}
