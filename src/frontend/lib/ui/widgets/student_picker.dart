import 'package:flutter/material.dart';
import '../../models/domain.dart';
import '../theme.dart';
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
  });

  final List<AppUser> students;
  final ValueChanged<AppUser> onPick;
  final bool enabled;
  final String empty;

  @override
  State<StudentPicker> createState() => _StudentPickerState();
}

class _StudentPickerState extends State<StudentPicker> {
  final busqueda = TextEditingController();

  @override
  void dispose() {
    busqueda.dispose();
    super.dispose();
  }

  /// Deja el texto en minúsculas y sin tildes, para comparar sin sorpresas.
  static String _llano(String texto) {
    const con = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const sin = 'aaaaaeeeeiiiiooooouuuunc';
    final buffer = StringBuffer();
    for (final letra in texto.toLowerCase().split('')) {
      final i = con.indexOf(letra);
      buffer.write(i == -1 ? letra : sin[i]);
    }
    return buffer.toString();
  }

  List<AppUser> get _encontrados {
    final texto = _llano(busqueda.text.trim());
    if (texto.isEmpty) return widget.students;
    return widget.students
        .where(
          (alumno) =>
              _llano(alumno.displayName).contains(texto) ||
              _llano(alumno.username).contains(texto),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final encontrados = _encontrados;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: busqueda,
          enabled: widget.enabled,
          onChanged: (_) => setState(() {}),
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
        for (final alumno in encontrados)
          Padding(
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
      ],
    );
  }
}
