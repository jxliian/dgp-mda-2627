import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';

/// Elegir un aula en una pantalla propia, en lugar de un desplegable.
///
/// Devuelve el nombre del aula elegida, o `null` si se vuelve sin elegir.
class ClassPickerScreen extends StatefulWidget {
  const ClassPickerScreen({super.key, required this.title, this.current});

  final String title;

  /// Aula en la que ya está, para marcarla y no ofrecerla como novedad.
  final String? current;

  @override
  State<ClassPickerScreen> createState() => _ClassPickerScreenState();
}

class _ClassPickerScreenState extends State<ClassPickerScreen> {
  String busqueda = '';

  @override
  Widget build(BuildContext context) => PageShell(
    title: widget.title,
    subtitle: 'Aulas del centro',
    child: Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar aula',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (valor) =>
              setState(() => busqueda = valor.trim().toLowerCase()),
        ),
        const SizedBox(height: 18),
        LoadPanel<List<Classroom>>(
          load: AppScope.of(context).repository.classes,
          builder: (aulas) {
            final visibles = aulas
                .where((aula) => aula.name.toLowerCase().contains(busqueda))
                .toList();
            return PagedItems<Classroom>(
              key: ValueKey(busqueda),
              items: visibles,
              pageSize: 4,
              empty: aulas.isEmpty
                  ? 'Todavía no hay aulas creadas.'
                  : 'Ningún aula coincide con la búsqueda.',
              builder: _ficha,
            );
          },
        ),
      ],
    ),
  );

  Widget _ficha(Classroom aula) {
    final esLaSuya = aula.name == widget.current;
    return ActionTile(
      title: aula.name,
      subtitle: '${aula.studentCount} alumnos',
      icon: Icons.school_outlined,
      edge: esLaSuya ? Paleta.bosque : Paleta.terracota,
      badges: [
        if (esLaSuya)
          const StatusBadge(
            'Aula actual',
            tone: BadgeTone.done,
            icon: Icons.check_circle_outline,
          ),
      ],
      onTap: esLaSuya ? null : () => Navigator.pop(context, aula.name),
    );
  }
}
