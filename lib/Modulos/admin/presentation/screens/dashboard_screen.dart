import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_panel.dart';
import 'package:fit_quest_go/core/widgets/fq_live_map_view.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_kpi.dart';

/// ADM-01 · Dashboard. Estado general del sistema y colas prioritarias.
///
/// Maqueta sin backend: los indicadores muestran "—" y las colas no traen
/// numeros. La estructura (KPIs + panel de mapa + panel de colas) queda lista
/// para conectarse.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<AdminKpi> kpis = <AdminKpi>[
      AdminKpi(label: l10n.admKpiUsuarios, icon: Icons.people_alt_outlined),
      AdminKpi(label: l10n.admKpiRutas, icon: Icons.route_outlined),
      AdminKpi(
        label: l10n.admKpiAlertasActivas,
        icon: Icons.warning_amber_rounded,
      ),
      AdminKpi(
        label: l10n.admKpiPendientes,
        icon: Icons.pending_actions_outlined,
      ),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AdminKpiRow(items: kpis),
          const SizedBox(height: FqGap.lg),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final Widget mapa = FqPanel(
                title: l10n.admActividadEnVivo,
                trailing: FqTag(l10n.admEnLinea, tone: FqTagTone.green),
                child: const FqLiveMapView(height: 260),
              );
              final Widget colas = FqPanel(
                title: l10n.admColasPrioritarias,
                trailing: _VerTodas(texto: l10n.admVerTodas),
                padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
                child: Column(
                  children: <Widget>[
                    _QueueRow(
                      icon: Icons.route_outlined,
                      label: l10n.admRutasPorRevisar,
                    ),
                    const SizedBox(height: 7),
                    _QueueRow(
                      icon: Icons.location_on_outlined,
                      label: l10n.admNodosPendientes,
                    ),
                    const SizedBox(height: 7),
                    _QueueRow(
                      icon: Icons.flag_outlined,
                      label: l10n.admReportesNuevos,
                    ),
                  ],
                ),
              );

              if (c.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    mapa,
                    const SizedBox(height: FqGap.md),
                    colas,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 135, child: mapa),
                  const SizedBox(width: FqGap.md),
                  Expanded(flex: 85, child: colas),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VerTodas extends StatelessWidget {
  const _VerTodas({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: FqColors.river,
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: FqColors.queueBg,
        borderRadius: FqRadius.allMd,
        border: Border.all(color: FqColors.border),
      ),
      padding: const EdgeInsets.all(7),
      child: Row(
        children: <Widget>[
          Container(
            width: 29,
            height: 29,
            decoration: BoxDecoration(
              color: FqColors.listIconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: FqColors.night),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: FqColors.ink,
              ),
            ),
          ),
          const Text(
            '—',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: FqColors.muted,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, size: 15, color: FqColors.muted),
        ],
      ),
    );
  }
}
