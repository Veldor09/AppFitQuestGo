import 'package:flutter/material.dart';

import 'package:fit_quest_go/Modulos/admin/data/dashboard_api.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_kpi.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_live_map_view.dart';
import 'package:fit_quest_go/core/widgets/fq_panel.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// ADM-01 · Dashboard administrativo conectado al backend.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.api});

  /// Permite utilizar una API simulada durante las pruebas.
  /// En producción se utiliza DashboardApi normalmente.
  final DashboardApi? api;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardApi _api = widget.api ?? DashboardApi();

  Map<String, dynamic>? _resumen;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final Map<String, dynamic> resumen = await _api.obtenerResumen();

      if (!mounted) return;

      setState(() {
        _resumen = resumen;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _cargando = false;
      });
    }
  }

  String? _valor(String clave) {
    if (_resumen == null) return null;
    return _resumen![clave]?.toString();
  }

  String? _valorCola(String clave) {
    final dynamic colas = _resumen?['colas'];

    if (colas is! Map) return null;

    return colas[clave]?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final List<AdminKpi> kpis = <AdminKpi>[
      AdminKpi(
        label: l10n.admKpiUsuarios,
        icon: Icons.people_alt_outlined,
        value: _valor('usuarios'),
      ),
      AdminKpi(
        label: l10n.admKpiRutas,
        icon: Icons.route_outlined,
        value: _valor('rutas'),
      ),
      AdminKpi(
        label: l10n.admKpiAlertasActivas,
        icon: Icons.warning_amber_rounded,
        value: _valor('alertasActivas'),
      ),
      AdminKpi(
        label: l10n.admKpiPendientes,
        icon: Icons.pending_actions_outlined,
        value: _valor('pendientes'),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_cargando) ...<Widget>[
            const LinearProgressIndicator(),
            const SizedBox(height: FqGap.md),
          ],

          if (_error != null) ...<Widget>[
            Material(
              color: FqColors.queueBg,
              borderRadius: FqRadius.allMd,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.error_outline, color: FqColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.admDashErrorEstadisticas('$_error'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _cargarResumen,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(l10n.comunReintentar),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: FqGap.md),
          ],

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
                      icon: Icons.location_on_outlined,
                      label: l10n.admNodosPendientes,
                      value: _valorCola('nodosPendientes'),
                    ),
                    const SizedBox(height: 7),
                    _QueueRow(
                      icon: Icons.flag_outlined,
                      label: l10n.admReportesNuevos,
                      value: _valorCola('reportesNuevos'),
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
  const _QueueRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

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
          Text(
            value ?? '—',
            style: const TextStyle(
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
