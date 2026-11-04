import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/Modulos/usuarios/presentation/widgets/paginacion_bar.dart';

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

class AdminDataTable extends StatefulWidget {
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
    this.paginar = true,
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
  final bool paginar;

  @override
  State<AdminDataTable> createState() => _AdminDataTableState();
}

class _AdminDataTableState extends State<AdminDataTable> {
  static const List<int> _opcionesFilas = <int>[5, 10, 15, 20];
  int _pagina = 0;
  int _filasPorPagina = 5;

  @override
  void didUpdateWidget(covariant AdminDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Una busqueda o un filtro puede reducir la lista mientras se ve otra pagina.
    final paginas = widget.rows.isEmpty
        ? 1
        : ((widget.rows.length - 1) ~/ _filasPorPagina) + 1;
    if (_pagina >= paginas) _pagina = paginas - 1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (widget.error != null) {
      return FqEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No se pudo cargar',
        message: widget.error,
        action: widget.onRetry == null
            ? null
            : TextButton(
                onPressed: widget.onRetry,
                child: const Text('Reintentar'),
              ),
      );
    }
    if (widget.rows.isEmpty) {
      return FqEmptyState(
        icon: Icons.inbox_outlined,
        title: widget.emptyTitle,
        message:
            widget.emptyMessage ??
            'Aun no hay datos. Se mostraran aqui cuando el backend los provea.',
        action: widget.emptyAction,
      );
    }

    assert(widget.columns.isNotEmpty);
    final filas = widget.paginar
        ? widget.rows.skip(_pagina * _filasPorPagina).take(_filasPorPagina)
        : widget.rows;
    final double ancho = widget.columns.fold<double>(
      252,
      (sum, c) => sum + c.width,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabla = SizedBox(
          width: ancho < constraints.maxWidth ? constraints.maxWidth : ancho,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: FqColors.border)),
                ),
                child: Row(
                  children: <Widget>[
                    for (final c in widget.columns)
                      SizedBox(
                        width: c.width,
                        child: Text(c.label.toUpperCase(), style: _headerStyle),
                      ),
                    const Expanded(
                      child: Text(
                        'ACCIONES',
                        textAlign: TextAlign.right,
                        style: _headerStyle,
                      ),
                    ),
                  ],
                ),
              ),
              for (final row in filas)
                Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: FqColors.white,
                    border: Border(bottom: BorderSide(color: FqColors.border)),
                  ),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: widget.columns.first.width,
                        child: InkWell(
                          onTap: row.onTap,
                          child: _CellText(row.title, bold: true),
                        ),
                      ),
                      for (var i = 1; i < widget.columns.length; i++)
                        SizedBox(
                          width: widget.columns[i].width,
                          child: _CellText(
                            i - 1 < row.values.length
                                ? row.values[i - 1]
                                : i == 1
                                ? row.subtitle ?? '—'
                                : '—',
                          ),
                        ),
                      Expanded(child: _RowActions(row: row)),
                    ],
                  ),
                ),
            ],
          ),
        );
        return Column(
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: tabla,
            ),
            if (widget.paginar)
              PaginacionBar(
                total: widget.rows.length,
                pagina: _pagina,
                filasPorPagina: _filasPorPagina,
                opciones: _opcionesFilas,
                onFilasPorPagina: (n) => setState(() {
                  _filasPorPagina = n;
                  _pagina = 0;
                }),
                onPagina: (p) => setState(() => _pagina = p),
              ),
          ],
        );
      },
    );
  }
}

const TextStyle _headerStyle = TextStyle(
  fontSize: 8,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.7,
  color: FqColors.muted,
);

class _RowActions extends StatelessWidget {
  const _RowActions({required this.row});
  final AdminRow row;

  @override
  Widget build(BuildContext context) {
    final trailing = row.trailing;
    final menu = trailing is PopupMenuButton<String> ? trailing : null;
    final options =
        menu
            ?.itemBuilder(context)
            .whereType<PopupMenuItem<String>>()
            .where((item) => item.enabled && item.value != null)
            .toList() ??
        const <PopupMenuItem<String>>[];
    final hasMenuView = options.any((item) => item.value == 'ver');
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: <Widget>[
        if (row.onTap != null && row.showViewHint && !hasMenuView)
          _ActionText(label: 'Ver', color: FqColors.river, onTap: row.onTap),
        for (final option in options)
          _ActionText(
            label: option.child is Text
                ? (option.child as Text).data ?? option.value!
                : option.value!,
            color: option.value == 'ver'
                ? FqColors.river
                : (option.value == 'desactivar' ||
                      option.value == 'resolver' ||
                      option.value == 'eliminar')
                ? FqColors.risk
                : FqColors.ink,
            onTap: () => menu?.onSelected?.call(option.value!),
          ),
        if (menu == null && trailing != null) trailing,
      ],
    );
  }
}

class _ActionText extends StatelessWidget {
  const _ActionText({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(7),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ),
  );
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
