import 'package:flutter/material.dart';
import '../../models/domain.dart';
import '../../models/student_search.dart';
import '../theme.dart';
import 'paged_items.dart';
import 'user_avatar.dart';

/// Buscador de alumnos para matricular: se escribe parte del nombre y la
/// lista se reduce sola, en lugar de tener que saberse el usuario de memoria.
///
/// La búsqueda no distingue mayúsculas ni acentos, porque quien la usa suele
/// escribir «lucia» aunque la ficha ponga «Lucía».
class StudentPicker extends StatefulWidget {
  const StudentPicker({
    super.key,
    required this.students,
    required this.onPick,
    this.enabled = true,
    this.empty = 'No hay alumnos disponibles para matricular.',
    this.dropdown = false,
  });

  final List<AppUser> students;
  final ValueChanged<AppUser> onPick;
  final bool enabled;
  final String empty;
  final bool dropdown;

  @override
  State<StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<StudentPicker> {
  final busqueda = TextEditingController();
  String? elegido;

  @override
  void dispose() {
    busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final encontrados = filterStudents(widget.students, busqueda.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: busqueda,
          enabled: widget.enabled,
          onChanged: (_) => setState(() => elegido = null),
          decoration: const InputDecoration(
            labelText: 'Buscar alumno por nombre o usuario',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.students.isEmpty)
          Text(widget.empty)
        else if (encontrados.isEmpty)
          Text('Ningún alumno coincide con «${busqueda.text.trim()}».')
        else
          Semantics(
            liveRegion: true,
            child: Text(
              encontrados.length == 1
                  ? '1 alumno encontrado'
                  : '${encontrados.length} alumnos encontrados',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 8),
        if (widget.dropdown)
          _desplegable(encontrados)
        else if (encontrados.isNotEmpty)
          PagedItems<AppUser>(
            key: ValueKey(busqueda.text),
            items: encontrados,
            pageSize: 3,
            builder: (alumno) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: widget.enabled ? () => widget.onPick(alumno) : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(Medidas.alturaBotonMenor),
                  alignment: Alignment.centerLeft,
                ),
                child: Row(
                  children: [
                    UserAvatar(user: alumno, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${alumno.displayName} · ${alumno.username}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.person_add_alt),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _desplegable(List<AppUser> encontrados) {
    final seleccion = encontrados
        .where((a) => a.username == elegido)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(
            '${busqueda.text}/${encontrados.map((a) => a.username).join(',')}',
          ),
          initialValue: seleccion?.username,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Alumno sin aula'),
          items: [
            for (final alumno in encontrados)
              DropdownMenuItem(
                value: alumno.username,
                child: Text('${alumno.displayName} · ${alumno.username}'),
              ),
          ],
          onChanged: widget.enabled && encontrados.isNotEmpty
              ? (value) => setState(() => elegido = value)
              : null,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: widget.enabled && seleccion != null
              ? () => widget.onPick(seleccion)
              : null,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Matricular alumno seleccionado'),
        ),
      ],
    );
  }
}
