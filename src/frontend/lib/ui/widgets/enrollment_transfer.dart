import 'package:flutter/material.dart';
import '../../models/domain.dart';
import '../../models/student_search.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import 'form_actions.dart';
import 'icon_action.dart';
import 'load_panel.dart';
import 'notice.dart';
import 'paged_items.dart';
import 'section_title.dart';
import 'user_avatar.dart';

/// Matrículas de un aula con las dos listas a la vista: a la izquierda los
/// alumnos que se pueden matricular y a la derecha los que ya están.
///
/// Cada alumno se pasa de un lado al otro con una flecha, en lugar de buscarlo
/// en un desplegable y confirmar en un botón aparte.
class EnrollmentTransfer extends StatefulWidget {
  const EnrollmentTransfer({
    super.key,
    required this.className,
    this.enabled = true,
    this.onChanged,
  });

  final String className;
  final bool enabled;

  /// Se avisa tras cada cambio para que la pantalla recargue sus totales.
  final VoidCallback? onChanged;

  @override
  State<EnrollmentTransfer> createState() => _EnrollmentTransferState();
}

typedef _Listas = ({List<AppUser> matriculados, List<AppUser> disponibles});

class _EnrollmentTransferState extends State<EnrollmentTransfer> {
  int revision = 0;
  bool ocupado = false;
  String busquedaIzquierda = '';
  String busquedaDerecha = '';
  String? error;

  Future<_Listas> _cargar() async {
    final repositorio = AppScope.of(context).repository;
    final aula = await repositorio.classDetail(widget.className);
    final disponibles = await repositorio.unassignedStudents();
    return (
      matriculados: aula.students,
      disponibles: disponibles
          .where(
            (alumno) =>
                !aula.students.any((otro) => otro.username == alumno.username),
          )
          .toList(),
    );
  }

  Future<void> _mover(AppUser alumno, {required bool retirar}) async {
    if (retirar) {
      final confirmado = await confirmDelete(
        context,
        'Retirar alumno del aula',
        'Se retirará a ${alumno.displayName} y las tareas asignadas por esta '
            'aula. Su cuenta se conserva.',
      );
      if (!confirmado || !mounted) return;
    }
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      await AppScope.of(context).repository.enroll(
        widget.className,
        alumno.username,
        remove: retirar,
      );
      if (mounted) {
        AppScope.of(context).classroomsChanged();
        setState(() => revision++);
        widget.onChanged?.call();
      }
    } on Object catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (error != null) Notice(error!, error: true),
      LoadPanel<_Listas>(
        key: ValueKey('matriculas/$revision'),
        load: _cargar,
        builder: (listas) => LayoutBuilder(
          builder: (context, restricciones) {
            final izquierda = _columna(
              titulo: 'Alumnos sin aula',
              ayuda: 'Tócalos para matricularlos en ${widget.className}.',
              alumnos: filterStudents(listas.disponibles, busquedaIzquierda),
              total: listas.disponibles.length,
              busqueda: busquedaIzquierda,
              onBuscar: (valor) =>
                  setState(() => busquedaIzquierda = valor),
              vacio: 'No queda ningún alumno sin aula.',
              retirar: false,
            );
            final derecha = _columna(
              titulo: 'Alumnos del aula',
              ayuda: 'Total: ${listas.matriculados.length} alumnos',
              alumnos: filterStudents(listas.matriculados, busquedaDerecha),
              total: listas.matriculados.length,
              busqueda: busquedaDerecha,
              onBuscar: (valor) => setState(() => busquedaDerecha = valor),
              vacio: 'Todavía no hay alumnos en esta aula.',
              retirar: true,
            );
            if (restricciones.maxWidth < 760) {
              return Column(children: [izquierda, derecha]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: izquierda),
                const SizedBox(width: 24),
                Expanded(child: derecha),
              ],
            );
          },
        ),
      ),
    ],
  );

  Widget _columna({
    required String titulo,
    required String ayuda,
    required List<AppUser> alumnos,
    required int total,
    required String busqueda,
    required ValueChanged<String> onBuscar,
    required String vacio,
    required bool retirar,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionTitle(titulo, hint: ayuda),
      if (total > _desdeCuandoSeBusca)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Buscar alumno',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: onBuscar,
          ),
        ),
      PagedItems<AppUser>(
        key: ValueKey('$titulo/$busqueda/$revision'),
        items: alumnos,
        pageSize: 4,
        empty: busqueda.trim().isEmpty
            ? vacio
            : 'Ningún alumno coincide con «${busqueda.trim()}».',
        builder: (alumno) => _ficha(alumno, retirar: retirar),
      ),
    ],
  );

  static const _desdeCuandoSeBusca = 4;

  Widget _ficha(AppUser alumno, {required bool retirar}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(Medidas.radioControl),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: Medidas.trazo,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          if (retirar)
            IconAction(
              icon: Icons.arrow_back,
              label: 'Retirar a ${alumno.displayName}',
              onPressed: widget.enabled && !ocupado
                  ? () => _mover(alumno, retirar: true)
                  : null,
            ),
          if (retirar) const SizedBox(width: 10),
          UserAvatar(user: alumno, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alumno.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  alumno.username,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (!retirar) ...[
            const SizedBox(width: 10),
            IconAction(
              icon: Icons.arrow_forward,
              label: 'Matricular a ${alumno.displayName}',
              onPressed: widget.enabled && !ocupado
                  ? () => _mover(alumno, retirar: false)
                  : null,
            ),
          ],
        ],
      ),
    ),
  );
}
