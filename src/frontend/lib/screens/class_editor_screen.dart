import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/validation.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';

/// Alta y edición de un aula, con su personal y sus alumnos
/// (SCRUM-322, 323, 324 y 331).
class ClassEditorScreen extends StatefulWidget {
  const ClassEditorScreen({super.key, this.classroom});

  final Classroom? classroom;

  @override
  State<ClassEditorScreen> createState() => _ClassEditorScreenState();
}

class _ClassEditorScreenState extends State<ClassEditorScreen> {
  final form = GlobalKey<FormState>();
  final nombre = TextEditingController();
  String? nombreGuardado;
  String? personalElegido;
  String? alumnoElegido;
  int revision = 0;
  bool ocupado = false;
  String? aviso;
  String? error;

  /// El aula no tiene miembros hasta que existe con un nombre guardado.
  bool get existe => nombreGuardado != null;

  /// En algunos servidores la matrícula la hace solo el personal del aula.
  bool get puedeMatricular => AppScope.of(context).repository.canEnrollStudents;
  bool get puedeRetirarPersonal =>
      AppScope.of(context).repository.canRemoveStaff;

  @override
  void initState() {
    super.initState();
    nombreGuardado = widget.classroom?.name;
    nombre.text = nombreGuardado ?? '';
  }

  @override
  void dispose() {
    nombre.dispose();
    super.dispose();
  }

  Future<void> _operar(
    Future<void> Function() accion, {
    required String exito,
  }) async {
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      await accion();
      if (mounted) {
        setState(() {
          revision++;
          personalElegido = null;
          alumnoElegido = null;
          aviso = exito;
        });
        AppScope.of(context).classroomsChanged();
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> guardarNombre() async {
    if (!form.currentState!.validate()) return;
    final nuevo = nombre.text.trim();
    await _operar(() async {
      await AppScope.of(
        context,
      ).repository.saveClass(nuevo, previous: nombreGuardado);
      nombreGuardado = nuevo;
    }, exito: 'Aula guardada. Ya puedes asignar su personal.');
  }

  Future<void> cambiarPersonal(String username, {required bool retirar}) {
    final repositorio = AppScope.of(context).repository;
    return _operar(
      () => retirar
          ? repositorio.removeStaff(nombreGuardado!, username)
          : repositorio.addStaff(nombreGuardado!, username),
      exito: 'Personal del aula actualizado.',
    );
  }

  Future<void> matricular(String username) => _operar(
    () => AppScope.of(context).repository.enroll(nombreGuardado!, username),
    exito: 'Alumnos del aula actualizados.',
  );

  Future<void> retirarAlumno(AppUser alumno) async {
    final confirmado = await confirmDelete(
      context,
      'Retirar alumno del aula',
      'Se retirará a ${alumno.displayName} y las tareas asignadas por esta '
          'aula. Su cuenta se conserva.',
    );
    if (!confirmado || !mounted) return;
    await _operar(
      () => AppScope.of(
        context,
      ).repository.enroll(nombreGuardado!, alumno.username, remove: true),
      exito: 'Alumnos del aula actualizados.',
    );
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: existe ? 'Modificar aula' : 'Crear aula',
    subtitle: 'Administración',
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: nombre,
            maxLength: 50,
            enabled: !ocupado,
            validator: requiredText,
            decoration: const InputDecoration(labelText: 'Nombre del aula *'),
          ),
          if (existe) _miembros(),
          if (error != null) Notice(error!, error: true),
          if (aviso != null) Notice(aviso!),
          FormActions(
            busy: ocupado,
            onSave: guardarNombre,
            label: 'Guardar aula',
          ),
          if (existe)
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

  Widget _miembros() => LoadPanel<Classroom>(
    key: ValueKey(revision),
    load: () => AppScope.of(context).repository.classDetail(nombreGuardado!),
    builder: (aula) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          'Personal del aula',
          hint: 'Asigna el profesorado responsable de esta clase.',
        ),
        _selector(
          etiqueta: 'Añadir personal',
          rol: UserRole.staff,
          yaPresentes: aula.staff,
          elegido: personalElegido,
          onChanged: (valor) => setState(() => personalElegido = valor),
          onConfirm: () => cambiarPersonal(personalElegido!, retirar: false),
          textoBoton: 'Asignar personal',
          vacio: 'No hay más miembros del personal para asignar.',
        ),
        const SectionTitle('Personal asociado al aula'),
        if (!aula.staffComplete)
          const Notice(
            'Se muestran las asignaciones confirmadas durante esta sesión. '
            'Para consultar todo el personal existente, el aula debe tener alumnos.',
          ),
        if (aula.staffComplete && aula.staff.isEmpty)
          const Notice('No hay personal asociado a esta aula.'),
        for (final miembro in aula.staff)
          _filaDeMiembro(
            miembro,
            onRemove: puedeRetirarPersonal
                ? () => cambiarPersonal(miembro.username, retirar: true)
                : null,
          ),
        SectionTitle(
          'Alumnos del aula',
          hint: puedeMatricular
              ? 'Matricula o retira alumnos de esta clase.'
              : 'Las matrículas las gestiona el personal asignado al aula.',
        ),
        Text('Total: ${aula.studentCount} alumnos'),
        for (final alumno in aula.students)
          _filaDeMiembro(
            alumno,
            avatar: true,
            onRemove: puedeMatricular ? () => retirarAlumno(alumno) : null,
          ),
        if (puedeMatricular)
          _selector(
            etiqueta: 'Añadir alumno',
            rol: UserRole.student,
            yaPresentes: aula.students,
            elegido: alumnoElegido,
            onChanged: (valor) => setState(() => alumnoElegido = valor),
            onConfirm: () => matricular(alumnoElegido!),
            textoBoton: 'Matricular alumno',
            vacio: 'No hay más alumnos disponibles.',
          ),
      ],
    ),
  );

  Widget _filaDeMiembro(
    AppUser persona, {
    required VoidCallback? onRemove,
    bool avatar = false,
  }) => ListTile(
    leading: avatar ? UserAvatar(user: persona, size: 48) : null,
    title: Text(persona.displayName),
    subtitle: Text(persona.username),
    trailing: onRemove == null
        ? null
        : IconAction(
            icon: Icons.delete_outline,
            label: 'Retirar a ${persona.displayName}',
            onPressed: ocupado ? null : onRemove,
          ),
  );

  Widget _selector({
    required String etiqueta,
    required UserRole rol,
    required List<AppUser> yaPresentes,
    required String? elegido,
    required ValueChanged<String?> onChanged,
    required VoidCallback onConfirm,
    required String textoBoton,
    required String vacio,
  }) => LoadPanel<List<AppUser>>(
    key: ValueKey('${rol.name}/$revision'),
    load: rol == UserRole.student
        ? AppScope.of(context).repository.unassignedStudents
        : AppScope.of(context).repository.users,
    builder: (todos) {
      final candidatos = todos
          .where(
            (u) =>
                u.role == rol &&
                !yaPresentes.any((p) => p.username == u.username),
          )
          .toList();
      if (candidatos.isEmpty) return Notice(vacio);
      return Column(
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: elegido,
            decoration: InputDecoration(labelText: etiqueta),
            items: candidatos
                .map(
                  (u) => DropdownMenuItem(
                    value: u.username,
                    child: Text(u.displayName),
                  ),
                )
                .toList(),
            onChanged: ocupado ? null : onChanged,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: ocupado || elegido == null ? null : onConfirm,
            icon: const Icon(Icons.add),
            label: Text(textoBoton),
          ),
        ],
      );
    },
  );
}
