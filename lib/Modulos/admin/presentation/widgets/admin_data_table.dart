import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';

/// Una fila de la tabla del panel (`.fq-admin-table > button`).
@immutable
class AdminRow {
  const AdminRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showViewHint = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Normalmente una [FqTag] con el estado.
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showViewHint;
}

/// Tabla generica del panel de administracion.
///
/// Se reutiliza en todas las pantallas de lista (rutas, alertas, nodos, ...).
/// Gestiona los estados de carga, error y vacio para no repetirlos en cada
/// pantalla.
class AdminDataTable extends StatelessWidget {
  const AdminDataTable({
    super.key,
    required this.rows,
    this.loading = false,
    this.error,
    this.onRetry,
    this.emptyTitle = 'Sin registros',
    this.emptyMessage,
    this.emptyAction,
  });

  final List<AdminRow> rows;
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

    return ListView.separated(
      shrinkWrap: true,
      primary: false,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: FqColors.border),
      itemBuilder: (BuildContext context, int i) =>
          _AdminTableRow(row: rows[i]),
    );
  }
}

class _AdminTableRow extends StatefulWidget {
  const _AdminTableRow({required this.row});

  final AdminRow row;

  @override
  State<_AdminTableRow> createState() => _AdminTableRowState();
}

class _AdminTableRowState extends State<_AdminTableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final AdminRow row = widget.row;
    return MouseRegion(
      cursor: row.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: row.onTap,
        child: Container(
          color: _hover ? FqColors.rowHover : FqColors.white,
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mobile = constraints.maxWidth < 560;
              final trailing = row.trailing == null
                  ? null
                  : ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: mobile
                            ? constraints.maxWidth - 43
                            : constraints.maxWidth * 0.36,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: row.trailing!,
                      ),
                    );
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    row.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: FqColors.ink,
                    ),
                  ),
                  if (row.subtitle != null)
                    Text(
                      row.subtitle!,
                      maxLines: mobile ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: FqColors.muted,
                      ),
                    ),
                ],
              );
              if (mobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: FqColors.listIconBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            row.icon,
                            size: 16,
                            color: FqColors.night,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(child: details),
                      ],
                    ),
                    if (trailing != null ||
                        (row.onTap != null && row.showViewHint)) ...<Widget>[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 43),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            ?trailing,
                            if (row.onTap != null && row.showViewHint)
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    'Ver',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: FqColors.river,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 14,
                                    color: FqColors.river,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: FqColors.listIconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(row.icon, size: 16, color: FqColors.night),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: details),
                  if (trailing != null) ...<Widget>[
                    const SizedBox(width: 8),
                    trailing,
                  ],
                  if (row.onTap != null && row.showViewHint) ...<Widget>[
                    const SizedBox(width: 10),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Ver',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: FqColors.river,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: FqColors.river,
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
