import 'package:flutter/material.dart';
import '../models/domain.dart';
import '../models/student_search.dart';
import '../state/app_state.dart';
import '../ui/ui.dart';
import 'login_screen.dart';

/// Elegir una cuenta en una pantalla propia, con el filtro de rol ya puesto.
///
/// Sustituye a los desplegables de asociación: en un desplegable largo no se
/// ve a quién se está eligiendo, y el rol que corresponde ya se sabe de
/// antemano. Devuelve la cuenta elegida o `null`.
class PersonPickerScreen extends StatefulWidget {
  const PersonPickerScreen({
    super.key,
    required this.title,
    required this.role,
    this.exclude = const [],
  });

  final String title;

  /// Rol que se busca. Es el filtro que ya viene aplicado.
  final UserRole role;

  /// Cuentas que no se ofrecen porque ya están asociadas.
  final List<String> exclude;

  @override
  State<PersonPickerScreen> createState() => _PersonPickerScreenState();
}

class _PersonPickerScreenState extends State<PersonPickerScreen> {
  String busqueda = '';

  @override
  Widget build(BuildContext context) => PageShell(
    title: widget.title,
    subtitle: 'Filtro aplicado: ${widget.role.plural}',
    child: Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            StatusBadge(
              widget.role.plural,
              tone: BadgeTone.main,
              icon: roleIcon(widget.role),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar por nombre o usuario',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (valor) => setState(() => busqueda = valor),
        ),
        const SizedBox(height: 18),
        LoadPanel<List<AppUser>>(
          load: AppScope.of(context).repository.users,
          builder: (todos) {
            final candidatos = filterStudents(
              todos
                  .where(
                    (cuenta) =>
                        cuenta.role == widget.role &&
                        !widget.exclude.contains(cuenta.username),
                  )
                  .toList(),
              busqueda,
            );
            return PagedItems<AppUser>(
              key: ValueKey(busqueda),
              items: candidatos,
              pageSize: 4,
              empty: 'No hay ${widget.role.plural.toLowerCase()} disponibles.',
              builder: (cuenta) => ActionTile(
                title: cuenta.displayName,
                subtitle: cuenta.username,
                icon: roleIcon(cuenta.role),
                edge: Paleta.terracota,
                leading: cuenta.role == UserRole.student
                    ? UserAvatar(user: cuenta, size: 64)
                    : null,
                onTap: () => Navigator.pop(context, cuenta),
              ),
            );
          },
        ),
      ],
    ),
  );
}
