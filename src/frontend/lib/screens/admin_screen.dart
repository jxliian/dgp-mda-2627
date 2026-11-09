import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../services/repository.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'class_editor_screen.dart';
import 'login_screen.dart';
import 'user_editor_screen.dart';

/// Inicio de administración: gestión de cuentas y de aulas del centro.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool mostrandoAulas = false;
  String busqueda = '';
  UserRole? rolFiltrado;
  int revision = 0;
  bool ocupado = false;
  String? aviso;
  String? error;

  void _recargar(String? mensaje) => setState(() {
    revision++;
    aviso = mensaje;
  });

  Future<void> editarUsuario([AppUser? usuario]) async {
    final guardado = await openPage<bool>(
      context,
      UserEditorScreen(user: usuario),
    );
    if (guardado == true && mounted) _recargar('Usuario guardado.');
  }

  Future<void> editarAula([Classroom? aula]) async {
    final guardada = await openPage<bool>(
      context,
      ClassEditorScreen(classroom: aula),
    );
    if (mounted) _recargar(guardada == true ? 'Aula guardada.' : null);
  }

  Future<void> eliminarUsuario(AppUser usuario) => _eliminar(
    titulo: 'Eliminar usuario',
    mensaje:
        '¿Quieres eliminar a «${usuario.displayName}»? '
        'Se eliminará su cuenta y sus asociaciones.',
    accion: (repositorio) => repositorio.deleteUser(usuario),
  );

  Future<void> eliminarAula(Classroom aula) => _eliminar(
    titulo: 'Eliminar aula',
    mensaje:
        '¿Quieres eliminar «${aula.name}»? Se retirarán sus matrículas y '
        'tareas grupales. Las cuentas se conservan.',
    accion: (repositorio) => repositorio.deleteClass(aula.name),
  );

  Future<void> _eliminar({
    required String titulo,
    required String mensaje,
    required Future<void> Function(AutovidaRepository repositorio) accion,
  }) async {
    if (!await confirmDelete(context, titulo, mensaje) || !mounted) return;
    setState(() {
      ocupado = true;
      error = null;
      aviso = null;
    });
    try {
      await accion(AppScope.of(context).repository);
      if (mounted) _recargar('Eliminado correctamente.');
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PageShell(
      title: 'Gestión de usuarios y aulas',
      subtitle: 'Bienvenido: ${state.user!.displayName}',
      footer: const AppFooter(),
      child: Column(
        children: [
          _selectorDeVista(),
          const SizedBox(height: 20),
          _buscador(),
          if (!mostrandoAulas) _filtroDeRoles(),
          const SizedBox(height: 24),
          if (error != null) Notice(error!, error: true),
          if (aviso != null) Notice(aviso!),
          if (mostrandoAulas) _listaDeAulas(state) else _listaDeUsuarios(state),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: ocupado
                ? null
                : () => mostrandoAulas ? editarAula() : editarUsuario(),
            icon: const Icon(Icons.add),
            label: Text(mostrandoAulas ? 'Crear aula' : 'Crear usuario'),
          ),
        ],
      ),
    );
  }

  Widget _selectorDeVista() => Wrap(
    spacing: 12,
    runSpacing: 12,
    alignment: WrapAlignment.center,
    children: [
      ChoiceChip(
        label: const Text('Usuarios'),
        selected: !mostrandoAulas,
        onSelected: (_) => setState(() => mostrandoAulas = false),
      ),
      ChoiceChip(
        label: const Text('Aulas'),
        selected: mostrandoAulas,
        onSelected: (_) => setState(() => mostrandoAulas = true),
      ),
    ],
  );

  Widget _buscador() => TextField(
    decoration: InputDecoration(
      labelText: mostrandoAulas ? 'Buscar aula' : 'Buscar por nombre o usuario',
      prefixIcon: const Icon(Icons.search),
    ),
    onChanged: (valor) => setState(() => busqueda = valor.toLowerCase()),
  );

  Widget _filtroDeRoles() => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ChoiceChip(
          label: const Text('Todos los roles'),
          selected: rolFiltrado == null,
          onSelected: (_) => setState(() => rolFiltrado = null),
        ),
        for (final rol in UserRole.values)
          ChoiceChip(
            label: Text(rol.plural),
            selected: rolFiltrado == rol,
            onSelected: (_) => setState(() => rolFiltrado = rol),
          ),
      ],
    ),
  );

  Widget _listaDeAulas(AppState state) => LoadPanel<List<Classroom>>(
    key: ValueKey('aulas/$revision'),
    load: state.repository.classes,
    builder: (aulas) => PagedItems<Classroom>(
      items: aulas
          .where((aula) => aula.name.toLowerCase().contains(busqueda))
          .toList(),
      empty: 'No hay aulas que coincidan con la búsqueda.',
      builder: _fichaDeAula,
    ),
  );

  Widget _listaDeUsuarios(AppState state) => LoadPanel<List<AppUser>>(
    key: ValueKey('usuarios/$revision'),
    load: state.repository.users,
    builder: (usuarios) => PagedItems<AppUser>(
      items: usuarios.where(_coincide).toList(),
      empty: 'No hay usuarios que coincidan con la búsqueda.',
      builder: _fichaDeUsuario,
    ),
  );

  bool _coincide(AppUser usuario) {
    final porRol = rolFiltrado == null || rolFiltrado == usuario.role;
    final texto = '${usuario.username} ${usuario.displayName}'.toLowerCase();
    return porRol && texto.contains(busqueda);
  }

  Widget _fichaDeAula(Classroom aula) => ActionTile(
    title: aula.name,
    subtitle: 'Toca para editar el aula',
    icon: Icons.school_outlined,
    badges: [
      const StatusBadge('Aula', tone: BadgeTone.main, icon: Icons.groups_outlined),
      StatusBadge('${aula.students.length} alumnos', icon: Icons.person_outline),
      StatusBadge(
        '${aula.staff.length} del personal',
        icon: Icons.supervisor_account_outlined,
      ),
    ],
    onTap: ocupado ? null : () => editarAula(aula),
    trailing: IconAction(
      icon: Icons.delete_outline,
      label: 'Eliminar el aula ${aula.name}',
      onPressed: ocupado ? null : () => eliminarAula(aula),
    ),
  );

  Widget _fichaDeUsuario(AppUser usuario) {
    final esAlumno = usuario.role == UserRole.student;
    return ActionTile(
      title: usuario.displayName,
      subtitle: usuario.username,
      icon: roleIcon(usuario.role),
      edge: esAlumno ? Paleta.terracota : Paleta.bosque,
      badges: [
        StatusBadge(
          usuario.role.label,
          tone: esAlumno ? BadgeTone.warm : BadgeTone.main,
          icon: roleIcon(usuario.role),
        ),
      ],
      leading: esAlumno ? UserAvatar(user: usuario) : null,
      onTap: ocupado ? null : () => editarUsuario(usuario),
      trailing: IconAction(
        icon: Icons.delete_outline,
        label: 'Eliminar a ${usuario.displayName}',
        onPressed: ocupado ? null : () => eliminarUsuario(usuario),
      ),
    );
  }
}
