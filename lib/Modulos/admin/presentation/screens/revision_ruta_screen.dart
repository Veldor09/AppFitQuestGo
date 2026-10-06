import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_field_display.dart';
import 'package:fit_quest_go/core/widgets/fq_map_view.dart';
import 'package:fit_quest_go/core/widgets/fq_panel.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_note.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';

/// ADM-05 · Revision de ruta. Mapa + ficha de decision (aprobar / rechazar).
///
/// Sin [ruta] (acceso directo desde el sidebar) los datos son "—" y las
/// acciones quedan deshabilitadas, igual que la maqueta original. Con una
/// [ruta] cargada (llega desde ADM-04) la ficha es real y Aprobar/Rechazar
/// pegan contra `PATCH /rutas/:id/estado`.
class RevisionRutaScreen extends StatefulWidget {
  const RevisionRutaScreen({super.key, this.ruta, this.api});

  final Ruta? ruta;
  final RutaApi? api;

  @override
  State<RevisionRutaScreen> createState() => _RevisionRutaScreenState();
}

class _RevisionRutaScreenState extends State<RevisionRutaScreen> {
  late final RutaApi _api = widget.api ?? RutaApi();
  bool _procesando = false;

  Future<void> _decidir(AppLocalizations l10n, String estado) async {
    final Ruta? ruta = widget.ruta;
    if (ruta == null) return;
    setState(() => _procesando = true);
    try {
      await _api.cambiarEstado(ruta.id, estado);
      if (!mounted) return;
      notificarExito(
        estado == 'Publicada'
            ? l10n.revisionPublicadaExito(ruta.nombre)
            : l10n.revisionRechazadaExito(ruta.nombre),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      setState(() => _procesando = false);
      if (mounted) notificarError(l10n.usuariosAccionFallida);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Ruta? ruta = widget.ruta;
    // Sin Scaffold propio: este widget se embebe dentro del Scaffold de
    // AdminShell cuando se accede via sidebar (ADM-05). Cuando se llega
    // aqui via push (desde ADM-04, con una ruta real), quien hace el push
    // le pone su propio Scaffold/AppBar alrededor.
    return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final Widget mapa = FqPanel(
              child: Stack(
                children: <Widget>[
                  const FqMapView(height: 320, showRoute: true),
                  if (ruta == null)
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: _ReviewWarning(l10n.revisionAdvertenciaTrazado),
                    ),
                ],
              ),
            );

            final Widget ficha = FqPanel(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FqTag(
                      estadoRutaLabel(l10n, ruta?.estado ?? 'Pendiente'),
                      tone: FqTagTone.amber,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ruta?.nombre ?? l10n.revisionSinRutaTitulo,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: FqColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ruta == null
                        ? l10n.revisionEligeRuta(l10n.admNavGestionRutas)
                        : (ruta.creadoPorNombre != null
                            ? l10n.revisionPropuestaPor(
                                actividadesLabel(l10n, ruta.actividades),
                                ruta.creadoPorNombre!,
                              )
                            : actividadesLabel(l10n, ruta.actividades)),
                    style: const TextStyle(fontSize: 9, color: FqColors.muted),
                  ),
                  const SizedBox(height: FqGap.lg),
                  _MetricGrid(
                    items: <(String, String)>[
                      ('km', ruta?.distanciaKm.toStringAsFixed(1) ?? '—'),
                      (
                        l10n.rutasDificultadLabel,
                        ruta == null ? '—' : dificultadLabel(l10n, ruta.dificultad),
                      ),
                      (l10n.revisionPuntosLabel, ruta?.puntos.length.toString() ?? '—'),
                    ],
                  ),
                  const SizedBox(height: FqGap.lg),
                  AdminNote(
                    title: l10n.revisionVerificacionGps,
                    detail: l10n.revisionAnalisisTrazado,
                    icon: Icons.gps_fixed,
                  ),
                  const SizedBox(height: FqGap.lg),
                  FqFieldDisplay(label: l10n.revisionNotaInterna, multiline: true),
                  const SizedBox(height: FqGap.lg),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FqButton.secondary(
                          label: l10n.revisionPedirCorreccion,
                          dense: true,
                          onPressed: null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: FqButton.danger(
                          label: l10n.comunRechazar,
                          dense: true,
                          onPressed: (ruta == null || _procesando)
                              ? null
                              : () => _decidir(l10n, 'Rechazada'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: FqButton.primary(
                          label: l10n.comunAprobar,
                          dense: true,
                          onPressed: (ruta == null || _procesando)
                              ? null
                              : () => _decidir(l10n, 'Publicada'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );

            if (c.maxWidth < 780) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[mapa, const SizedBox(height: FqGap.lg), ficha],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 115, child: mapa),
                const SizedBox(width: FqGap.lg),
                Expanded(flex: 85, child: ficha),
              ],
            );
          },
        ),
      );
  }
}

class _ReviewWarning extends StatelessWidget {
  const _ReviewWarning(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0C9),
        borderRadius: BorderRadius.circular(9),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded,
              size: 14, color: Color(0xFF8C4E0C)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: Color(0xFF8C4E0C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: FqRadius.allLg,
        border: Border.all(color: FqColors.border),
      ),
      child: ClipRRect(
        borderRadius: FqRadius.allLg,
        child: IntrinsicHeight(
          child: Row(
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: i == items.length - 1
                              ? Colors.transparent
                              : FqColors.border,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: <Widget>[
                        Text(
                          items[i].$2,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: FqColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].$1.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 7,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w600,
                            color: FqColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
