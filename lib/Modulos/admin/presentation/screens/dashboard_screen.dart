import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_panel.dart';
import 'package:fit_quest_go/core/widgets/fq_live_map_view.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_kpi.dart';

/// ADM-01 · Dashboard. Estado general del sistema y colas prioritarias.
///
/// Maqueta sin backend: los indicadores muestran "—" y las colas no traen
/// numeros. La estructura (KPIs + panel de mapa + panel de colas) queda lista
/// para conectarse.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const List<AdminKpi> _kpis = <AdminKpi>[
    AdminKpi(label: 'usuarios', icon: Icons.people_alt_outlined),
    AdminKpi(label: 'rutas', icon: Icons.route_outlined),
    AdminKpi(label: 'alertas activas', icon: Icons.warning_amber_rounded),
    AdminKpi(label: 'pendientes', icon: Icons.pending_actions_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AdminKpiRow(items: _kpis),
          const SizedBox(height: FqGap.lg),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final Widget mapa = FqPanel(
                title: 'Actividad en vivo',
                trailing: const FqTag('En linea', tone: FqTagTone.green),
                child: const FqLiveMapView(height: 260),
              );
              final Widget colas = FqPanel(
                title: 'Colas prioritarias',
                trailing: const _VerTodas(),
                padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
                child: Column(
                  children: const <Widget>[
                    _QueueRow(
                      icon: Icons.route_outlined,
                      label: 'Rutas por revisar',
                    ),
                    SizedBox(height: 7),
                    _QueueRow(
                      icon: Icons.location_on_outlined,
                      label: 'Nodos pendientes',
                    ),
                    SizedBox(height: 7),
                    _QueueRow(
                      icon: Icons.flag_outlined,
                      label: 'Reportes nuevos',
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
  const _VerTodas();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Ver todas',
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
