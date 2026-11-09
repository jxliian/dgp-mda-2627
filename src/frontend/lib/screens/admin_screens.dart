import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/validation.dart';
import '../state/app_state.dart';
import '../ui/components.dart';
import '../ui/navigation.dart';
import 'settings_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  String search = '';
  UserRole? role;
  bool showClasses = false, busy = false;
  int revision = 0;
  String? error, message;
  Future<void> editUser([AppUser? user]) async {
    final result = await openPage<bool>(context, UserEditorScreen(user: user));
    if (result == true && mounted) {
      setState(() {
        revision++;
        message = 'Usuario guardado.';
      });
    }
  }

  Future<void> editClass([Classroom? classroom]) async {
    final result = await openPage<bool>(
      context,
      ClassEditorScreen(classroom: classroom),
    );
    if (mounted) {
      setState(() {
        revision++;
        if (result == true) message = 'Aula guardada.';
      });
    }
  }

  Future<void> remove({AppUser? user, Classroom? classroom}) async {
    final repository = AppScope.of(context).repository;
    final name = user?.displayName ?? classroom!.name;
    if (!await confirmDelete(
      context,
      'Eliminar ${user == null ? 'aula' : 'usuario'}',
      '¿Quieres eliminar «$name»? ${user == null ? 'Se retirarán sus matrículas y tareas grupales. Las cuentas se conservarán.' : 'Se eliminará su cuenta y sus asociaciones.'}',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      if (user != null) {
        await repository.deleteUser(user);
      } else {
        await repository.deleteClass(classroom!.name);
      }
      if (mounted) {
        setState(() {
          revision++;
          message = 'Eliminado correctamente.';
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PageShell(
      title: 'Gestión de usuarios y aulas',
      subtitle: 'Bienvenido: ${state.user!.displayName}',
      showBack: false,
      footer: const AppFooter(),
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ChoiceChip(
                label: const Text('Usuarios'),
                selected: !showClasses,
                onSelected: (_) => setState(() => showClasses = false),
              ),
              ChoiceChip(
                label: const Text('Aulas'),
                selected: showClasses,
                onSelected: (_) => setState(() => showClasses = true),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: InputDecoration(
              labelText: showClasses
                  ? 'Buscar aula'
                  : 'Buscar por nombre o usuario',
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => search = v.toLowerCase()),
          ),
          if (!showClasses) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('Todos los roles'),
                  selected: role == null,
                  onSelected: (_) => setState(() => role = null),
                ),
                for (final r in UserRole.values)
                  ChoiceChip(
                    label: Text(r.plural),
                    selected: role == r,
                    onSelected: (_) => setState(() => role = r),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (error != null) Notice(error!, error: true),
          if (message != null) Notice(message!),
          if (showClasses)
            LoadPanel<List<Classroom>>(
              key: ValueKey('classes/$revision'),
              load: state.repository.classes,
              builder: (classes) => PagedItems(
                items: classes
                    .where((c) => c.name.toLowerCase().contains(search))
                    .toList(),
                empty: 'No hay aulas que coincidan con la búsqueda.',
                builder: (c) => ActionTile(
                  title: c.name,
                  subtitle: '${c.students.length} alumnos',
                  icon: Icons.school_outlined,
                  onTap: busy ? null : () => editClass(c),
                  trailing: IconButton(
                    tooltip: 'Eliminar aula ${c.name}',
                    onPressed: busy ? null : () => remove(classroom: c),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
            )
          else
            LoadPanel<List<AppUser>>(
              key: ValueKey('users/$revision'),
              load: state.repository.users,
              builder: (users) => PagedItems(
                items: users
                    .where(
                      (u) =>
                          (role == null || role == u.role) &&
                          '${u.username} ${u.displayName}'
                              .toLowerCase()
                              .contains(search),
                    )
                    .toList(),
                empty: 'No hay usuarios que coincidan con la búsqueda.',
                builder: (u) => ActionTile(
                  title: u.displayName,
                  subtitle: '${u.username} · ${u.role.label}',
                  icon: Icons.person_outline,
                  leading: u.role == UserRole.student
                      ? UserAvatar(user: u)
                      : null,
                  onTap: busy ? null : () => editUser(u),
                  trailing: IconButton(
                    tooltip: 'Eliminar a ${u.displayName}',
                    onPressed: busy ? null : () => remove(user: u),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: busy
                ? null
                : () => showClasses ? editClass() : editUser(),
            icon: const Icon(Icons.add),
            label: Text(showClasses ? 'Crear aula' : 'Crear usuario'),
          ),
        ],
      ),
    );
  }
}

class UserEditorScreen extends StatefulWidget {
  const UserEditorScreen({super.key, this.user});
  final AppUser? user;
  @override
  State<UserEditorScreen> createState() => _UserEditorScreenState();
}

class _UserEditorScreenState extends State<UserEditorScreen> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController();
  final fullName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  late UserRole role;
  late AccessSettings settings;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final user = widget.user;
    username.text = user?.username ?? '';
    fullName.text = user?.fullName ?? '';
    email.text = user?.email ?? '';
    role = user?.role ?? UserRole.student;
    settings = user?.access.copy() ?? AccessSettings();
  }

  @override
  void dispose() {
    username.dispose();
    fullName.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final state = AppScope.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    final payload = <String, dynamic>{
      'username': username.text.trim(),
      'full_name': fullName.text.trim(),
      if (widget.user == null) 'role': role.name,
      if (password.text.isNotEmpty) 'password': password.text,
      if (role == UserRole.student)
        ...settings.toJson()
      else
        'email': email.text.trim(),
    };
    try {
      await state.repository.saveUser(payload, previous: widget.user);
      if (state.user != null && widget.user?.username == state.user?.username) {
        await state.refreshProfile();
      }
      if (mounted) Navigator.pop(context, true);
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: widget.user == null ? 'Crear usuario' : 'Modificar usuario',
    subtitle: 'Administración',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.user?.role == UserRole.student)
            Center(child: UserAvatar(user: widget.user!, size: 110)),
          const SizedBox(height: 16),
          TextFormField(
            controller: username,
            enabled: !busy,
            validator: usernameError,
            autocorrect: false,
            maxLength: 50,
            decoration: const InputDecoration(labelText: 'Nombre de usuario *'),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: fullName,
            enabled: !busy,
            validator: fullNameError,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Nombre y apellidos *',
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<UserRole>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Rol *'),
            items: UserRole.values
                .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                .toList(),
            onChanged: widget.user != null || busy
                ? null
                : (r) => setState(() => role = r!),
          ),
          if (widget.user != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'El rol se fija al crear la cuenta y no se puede cambiar.',
              ),
            ),
          if (role != UserRole.student) ...[
            const SizedBox(height: 18),
            TextFormField(
              controller: email,
              enabled: !busy,
              validator: emailError,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico *',
              ),
            ),
          ],
          const SizedBox(height: 18),
          TextFormField(
            controller: password,
            enabled: !busy,
            obscureText: true,
            validator: (v) =>
                widget.user != null && v!.isEmpty ? null : passwordError(v),
            decoration: InputDecoration(
              labelText: widget.user == null
                  ? 'Contraseña *'
                  : 'Nueva contraseña (opcional)',
              helperText: role == UserRole.student
                  ? 'Una contraseña numérica permite usar el teclado de dibujos.'
                  : null,
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: confirmation,
            enabled: !busy,
            obscureText: true,
            validator: (v) =>
                v == password.text ? null : 'Las contraseñas no coinciden.',
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
            ),
          ),
          if (role == UserRole.student)
            AccessEditor(settings: settings, permissions: true, enabled: !busy),
          if (widget.user != null && role != UserRole.admin) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => openPage(
                      context,
                      AssociationsScreen(user: widget.user!),
                    ),
              icon: const Icon(Icons.link),
              label: const Text('Gestionar asociaciones'),
            ),
          ],
          if (widget.user == null)
            const Notice(
              'Guarda la cuenta y vuelve a abrirla para gestionar sus asociaciones.',
            ),
          if (error != null) Notice(error!, error: true),
          FormActions(busy: busy, onSave: save, label: 'Guardar usuario'),
        ],
      ),
    ),
  );
}

class AssociationsScreen extends StatefulWidget {
  const AssociationsScreen({super.key, required this.user});
  final AppUser user;
  @override
  State<AssociationsScreen> createState() => _AssociationsScreenState();
}

class _AssociationsScreenState extends State<AssociationsScreen> {
  int revision = 0;
  bool busy = false;
  String? error, message;
  String? selected;
  Future<void> link(String username, {bool remove = false}) async {
    final state = AppScope.of(context);
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      final student = widget.user.role == UserRole.student
          ? widget.user.username
          : username;
      final parent = widget.user.role == UserRole.parent
          ? widget.user.username
          : username;
      await state.repository.linkParent(student, parent, remove: remove);
      if (mounted) {
        setState(() {
          selected = null;
          revision++;
          message = remove ? 'Asociación retirada.' : 'Asociación añadida.';
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isStaff = widget.user.role == UserRole.staff;
    return PageShell(
      title: 'Asociaciones de ${widget.user.displayName}',
      child: Column(
        children: [
          if (isStaff)
            const Notice(
              'Los alumnos del personal se asignan mediante las aulas. Puedes cambiar el personal de cada aula desde Gestión de aulas.',
            ),
          LoadPanel<List<AppUser>>(
            key: ValueKey(revision),
            load: () => widget.user.role == UserRole.student
                ? state.repository.parents(widget.user.username)
                : state.repository.linkedStudents(widget.user),
            builder: (linked) => Column(
              children: [
                for (final user in linked)
                  ActionTile(
                    title: user.displayName,
                    subtitle: user.username,
                    icon: Icons.person_outline,
                    onTap: null,
                    trailing: isStaff
                        ? null
                        : IconButton(
                            tooltip:
                                'Retirar asociación con ${user.displayName}',
                            onPressed: busy
                                ? null
                                : () => link(user.username, remove: true),
                            icon: const Icon(Icons.link_off),
                          ),
                  ),
                if (!isStaff)
                  LoadPanel<List<AppUser>>(
                    key: ValueKey('available/$revision'),
                    load: state.repository.users,
                    builder: (users) {
                      final candidates = users
                          .where(
                            (u) =>
                                u.role ==
                                    (widget.user.role == UserRole.student
                                        ? UserRole.parent
                                        : UserRole.student) &&
                                !linked.any((l) => l.username == u.username),
                          )
                          .toList();
                      if (candidates.isEmpty) {
                        return const Notice(
                          'No hay más cuentas disponibles para asociar.',
                        );
                      }
                      return Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: selected,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Cuenta para asociar',
                            ),
                            items: candidates
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u.username,
                                    child: Text(u.displayName),
                                  ),
                                )
                                .toList(),
                            onChanged: busy
                                ? null
                                : (v) => setState(() => selected = v),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: selected == null || busy
                                ? null
                                : () => link(selected!),
                            icon: const Icon(Icons.add),
                            label: const Text('Añadir asociación'),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          if (error != null) Notice(error!, error: true),
          if (message != null) Notice(message!),
        ],
      ),
    );
  }
}

class ClassEditorScreen extends StatefulWidget {
  const ClassEditorScreen({super.key, this.classroom});
  final Classroom? classroom;
  @override
  State<ClassEditorScreen> createState() => _ClassEditorScreenState();
}

class _ClassEditorScreenState extends State<ClassEditorScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  String? currentName, selectedStaff, selectedStudent, error, message;
  bool busy = false;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    currentName = widget.classroom?.name;
    name.text = currentName ?? '';
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final repository = AppScope.of(context).repository;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.saveClass(name.text.trim(), previous: currentName);
      if (mounted) {
        setState(() {
          currentName = name.text.trim();
          revision++;
          message = 'Aula guardada. Ya puedes asignar su personal.';
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> staff(String username, {bool remove = false}) async {
    final repository = AppScope.of(context).repository;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (remove) {
        await repository.removeStaff(currentName!, username);
      } else {
        await repository.addStaff(currentName!, username);
      }
      if (mounted) {
        setState(() {
          selectedStaff = null;
          revision++;
          message = 'Personal del aula actualizado.';
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> enroll(String username, {bool remove = false}) async {
    final repository = AppScope.of(context).repository;
    if (remove &&
        !await confirmDelete(
          context,
          'Retirar alumno del aula',
          'Se retirará al alumno y las tareas asignadas por esta aula. Su cuenta se conservará.',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.enroll(currentName!, username, remove: remove);
      if (mounted) {
        setState(() {
          selectedStudent = null;
          revision++;
          message = 'Alumnos del aula actualizados.';
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PageShell(
      title: currentName == null ? 'Crear aula' : 'Modificar aula',
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: name,
              maxLength: 50,
              enabled: !busy,
              validator: requiredText,
              decoration: const InputDecoration(labelText: 'Nombre del aula *'),
            ),
            const SizedBox(height: 20),
            if (currentName != null)
              LoadPanel<Classroom>(
                key: ValueKey(revision),
                load: () => state.repository.classDetail(currentName!),
                builder: (classroom) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal del aula',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    for (final u in classroom.staff)
                      ListTile(
                        title: Text(u.displayName),
                        subtitle: Text(u.username),
                        trailing: IconButton(
                          tooltip: 'Retirar a ${u.displayName}',
                          onPressed: busy
                              ? null
                              : () => staff(u.username, remove: true),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    LoadPanel<List<AppUser>>(
                      key: ValueKey('staff/$revision'),
                      load: state.repository.users,
                      builder: (users) {
                        final candidates = users
                            .where(
                              (u) =>
                                  u.role == UserRole.staff &&
                                  !classroom.staff.any(
                                    (s) => s.username == u.username,
                                  ),
                            )
                            .toList();
                        if (candidates.isEmpty) {
                          return const Notice(
                            'No hay más miembros del personal para asignar.',
                          );
                        }
                        return Column(
                          children: [
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: selectedStaff,
                              decoration: const InputDecoration(
                                labelText: 'Añadir personal',
                              ),
                              items: candidates
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u.username,
                                      child: Text(u.displayName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() => selectedStaff = v),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: busy || selectedStaff == null
                                  ? null
                                  : () => staff(selectedStaff!),
                              icon: const Icon(Icons.add),
                              label: const Text('Asignar personal'),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Alumnos del aula',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    for (final u in classroom.students)
                      ListTile(
                        leading: UserAvatar(user: u, size: 48),
                        title: Text(u.displayName),
                        trailing: IconButton(
                          tooltip: 'Retirar a ${u.displayName} del aula',
                          onPressed: busy
                              ? null
                              : () => enroll(u.username, remove: true),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    LoadPanel<List<AppUser>>(
                      key: ValueKey('students/$revision'),
                      load: state.repository.users,
                      builder: (users) {
                        final candidates = users
                            .where(
                              (u) =>
                                  u.role == UserRole.student &&
                                  !classroom.students.any(
                                    (s) => s.username == u.username,
                                  ),
                            )
                            .toList();
                        if (candidates.isEmpty) {
                          return const Notice(
                            'No hay más alumnos disponibles.',
                          );
                        }
                        return Column(
                          children: [
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: selectedStudent,
                              decoration: const InputDecoration(
                                labelText: 'Añadir alumno',
                              ),
                              items: candidates
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u.username,
                                      child: Text(u.displayName),
                                    ),
                                  )
                                  .toList(),
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() => selectedStudent = v),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: busy || selectedStudent == null
                                  ? null
                                  : () => enroll(selectedStudent!),
                              icon: const Icon(Icons.add),
                              label: const Text('Matricular alumno'),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            if (error != null) Notice(error!, error: true),
            if (message != null) Notice(message!),
            FormActions(busy: busy, onSave: save, label: 'Guardar aula'),
            if (currentName != null)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Terminar y volver a la gestión'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
