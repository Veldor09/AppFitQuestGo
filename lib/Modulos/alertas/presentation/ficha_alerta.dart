import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/tipos_alerta.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';

/// Abre la ficha corta de una alerta (al elegirla en la busqueda o en el cuadro
/// "Cerca de ti"). [metros] es la distancia desde quien mira, si se conoce.
Future<void> mostrarFichaAlerta(
  BuildContext context,
  Alerta alerta, {
  double? metros,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext _) => FichaAlerta(alerta: alerta, metros: metros),
  );
}

/// Ficha corta de una alerta: su tipo, su gravedad, quien la reporto, a cuantos
/// metros esta y la descripcion. Es solo de lectura: votar si sigue ahi se hace
/// desde el aviso que sale al acercarse.
class FichaAlerta extends StatelessWidget {
  const FichaAlerta({super.key, required this.alerta, this.metros});

  final Alerta alerta;
  final double? metros;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String gravedad = gravedadLabel(l10n, alerta.gravedad);
    final String? autor = alerta.creadoPorNombre;
    final String? descripcion = alerta.descripcion?.trim();
    final double? distancia = metros;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: FqColors.risk.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(_icono(alerta.tipo), color: FqColors.risk),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        tipoAlertaLabel(
                          l10n,
                          alerta.tipo,
                          otro: alerta.tipoOtro,
                        ),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        autor == null
                            ? l10n.alertasGravedadConValor(gravedad)
                            : l10n.alertasGravedadReportadaPor(gravedad, autor),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FqColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (distancia != null) ...<Widget>[
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.near_me_outlined,
                    size: 16,
                    color: FqColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.alertasCercaDistancia(distancia.round()),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if (descripcion != null && descripcion.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                descripcion,
                style: const TextStyle(fontSize: 13.5, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _icono(String tipo) {
    for (final OpcionCatalogo o in tiposAlerta) {
      if (o.clave == tipo) return o.icono;
    }
    return Icons.warning_amber_rounded;
  }
}
