import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// Dato de la fila de indicadores (`.fq-admin-kpis .fq-metric`).
@immutable
class AdminKpi {
  const AdminKpi({required this.label, required this.icon, this.value});

  final String label;
  final IconData icon;

  /// `null` mientras no exista backend: se pinta un guion.
  final String? value;
}

/// Fila responsiva de indicadores del dashboard.
class AdminKpiRow extends StatelessWidget {
  const AdminKpiRow({super.key, required this.items});

  final List<AdminKpi> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final int columnas = c.maxWidth < 560 ? 2 : 4;
        const double gap = FqGap.md;
        final double itemW = (c.maxWidth - gap * (columnas - 1)) / columnas;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final AdminKpi kpi in items)
              SizedBox(width: itemW, child: _MetricCard(kpi: kpi)),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.kpi});

  final AdminKpi kpi;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: FqRadius.allLg,
        border: Border.all(color: FqColors.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(kpi.icon, size: 15, color: FqColors.river),
          const SizedBox(height: 4),
          Text(
            kpi.value ?? '—',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: FqColors.ink,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            kpi.label.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 8,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
              color: FqColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
