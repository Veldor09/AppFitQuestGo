import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';

@immutable
class AdminTableColumn {
  const AdminTableColumn(this.label, {this.width = 160});

  final String label;
  final double width;
}

@immutable
class AdminRow {
  const AdminRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.values = const <String>[],
    this.trailing,
    this.onTap,
    this.showViewHint = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Una celda por cada columna despues de la primera.
  final List<String> values;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showViewHint;
}

/// Tabla con columnas fijas: en telefono se desplaza horizontalmente.
/// Cada celda limita su texto, por lo que ninguna fila invade otra columna.
class AdminDataTable extends StatelessWidget {
  const AdminDataTable({
    super.key,
    required this.rows,
    this.columns = const <AdminTableColumn>[
      AdminTableColumn('Nombre', width: 220),
      AdminTableColumn('Detalle', width: 280),
    ],
    this.loading = false,
    this.error,
    this.onRetry,
    this.emptyTitle = 'Sin registros',
    this.emptyMessage,
    this.emptyAction,
  });

  final List<AdminRow> rows;

  /// Incluye la columna principal; Acciones se añade siempre al final.
  final List<AdminTableColumn> columns;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final String emptyTitle;
  final String? emptyMessage;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return FqEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No se pudo cargar',
        message: error,
        action: onRetry == null
            ? null
            : TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      );
    }
    if (rows.isEmpty) {
      return FqEmptyState(
        icon: Icons.inbox_outlined,
        title: emptyTitle,
        message:
            emptyMessage ??
            'Aun no hay datos. Se mostraran aqui cuando el backend los provea.',
        action: emptyAction,
      );
    }

    assert(columns.isNotEmpty);
    return LayoutBuilder(
      builder: (context, constraints) {
        final table = DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(FqColors.rowHover),
          headingRowHeight: 46,
          dataRowMinHeight: 54,
          dataRowMaxHeight: 76,
          horizontalMargin: 14,
          columnSpacing: 18,
          dividerThickness: 1,
          columns: <DataColumn>[
            for (final column in columns)
              DataColumn(
                label: SizedBox(
                  width: column.width,
                  child: Text(
                    column.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: FqColors.muted,
                    ),
                  ),
                ),
              ),
            const DataColumn(
              label: SizedBox(width: 110, child: Text('ACCIONES')),
            ),
          ],
          rows: <DataRow>[
            for (final row in rows)
              DataRow(
                onSelectChanged: row.onTap == null ? null : (_) => row.onTap!(),
                cells: <DataCell>[
                  DataCell(
                    SizedBox(
                      width: columns.first.width,
                      child: Row(
                        children: <Widget>[
                          Icon(row.icon, size: 18, color: FqColors.night),
                          const SizedBox(width: 8),
                          Expanded(child: _CellText(row.title, bold: true)),
                        ],
                      ),
                    ),
                  ),
                  for (var i = 1; i < columns.length; i++)
                    DataCell(
                      SizedBox(
                        width: columns[i].width,
                        child: _CellText(
                          i - 1 < row.values.length
                              ? row.values[i - 1]
                              : i == 1
                              ? row.subtitle ?? '—'
                              : '—',
                        ),
                      ),
                    ),
                  DataCell(
                    SizedBox(
                      width: 110,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (row.onTap != null && row.showViewHint)
                            TextButton(
                              onPressed: row.onTap,
                              child: const Text('Ver'),
                            ),
                          if (row.trailing != null)
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: row.trailing!,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (constraints.maxWidth < 700)
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Text(
                  'Desliza la tabla para ver más columnas →',
                  style: TextStyle(fontSize: 10, color: FqColors.muted),
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: table,
            ),
          ],
        );
      },
    );
  }
}

class _CellText extends StatelessWidget {
  const _CellText(this.value, {this.bold = false});

  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Text(
    value.isEmpty ? '—' : value,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: 12,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      color: bold ? FqColors.ink : FqColors.muted,
    ),
  );
}
