import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
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
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<String> tabs = <String>[
      l10n.admTabPendientes,
      l10n.admTabPublicados,
      l10n.admTabRechazados,
      l10n.admTabArchivados,
    ];
    return AdminListScaffold(
      searchHint: widget.searchHint,
      tabs: tabs,
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
                SnackBar(content: Text(l10n.admAltaPendienteBackend)),
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
