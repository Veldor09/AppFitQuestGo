import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_list_scaffold.dart';

/// Maqueta reutilizable para las pantallas de lista del panel que aun no tienen
/// backend (rutas, alertas, nodos, eventos, ...).
///
/// Reproduce toda la estructura visible del diseno: barra de busqueda, boton de
/// filtros, pestanas de estado y la tabla, pero con la tabla en estado vacio
/// (sin datos "quemados"). Cuando exista el endpoint basta con pasarle filas.
class AdminListaMaqueta extends StatefulWidget {
  const AdminListaMaqueta({
    super.key,
    required this.searchHint,
    required this.emptyTitle,
    required this.emptyMessage,
    this.nuevoLabel,
  });

  final String searchHint;
  final String emptyTitle;
  final String emptyMessage;

  /// Si se indica, agrega un boton primario "Nuevo" en la barra (ADM-10/ADM-11).
  final String? nuevoLabel;

  @override
  State<AdminListaMaqueta> createState() => _AdminListaMaquetaState();
}

class _AdminListaMaquetaState extends State<AdminListaMaqueta> {
  static const List<String> _tabs = <String>[
    'Pendientes',
    'Publicados',
    'Rechazados',
    'Archivados',
  ];

  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return AdminListScaffold(
      searchHint: widget.searchHint,
      tabs: _tabs,
      tabIndex: _tab,
      onTab: (int i) => setState(() => _tab = i),
      toolbarTrailing: widget.nuevoLabel == null
          ? null
          : FqButton.primary(
              label: widget.nuevoLabel!,
              icon: Icons.add,
              expand: false,
              dense: true,
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Alta de registro: pendiente de backend.'),
                ),
              ),
            ),
      child: AdminDataTable(
        rows: const <AdminRow>[],
        emptyTitle: widget.emptyTitle,
        emptyMessage: widget.emptyMessage,
      ),
    );
  }
}
