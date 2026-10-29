import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/geo/formato_distancia.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

class GuiaActiva {
  const GuiaActiva({
    required this.nombre,
    required this.metros,
    required this.segundos,
    this.lineaRecta = false,
  });

  final String nombre;
  final double metros;

  final double segundos;
  final bool lineaRecta;
}

class BannerGuia extends StatelessWidget {
  const BannerGuia({super.key, required this.guia, required this.onCerrar});

  final GuiaActiva guia;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String distancia = formatearDistancia(
      guia.metros,
      locale: Localizations.localeOf(context).toString(),
    );
    final int minutos = (guia.segundos / 60).ceil();
    final String detalle = guia.lineaRecta || guia.segundos <= 0
        ? l10n.guiaLineaRecta(distancia)
        : l10n.guiaDetalle(distancia, minutos);
    return Container(
      key: const ValueKey<String>('banner-guia'),
      margin: const EdgeInsets.fromLTRB(9, 0, 9, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: FqColors.night,
        borderRadius: BorderRadius.circular(19),
        boxShadow: FqColors.softShadow,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: FqColors.volt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.directions_walk_rounded,
              color: FqColors.night,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.guiaHacia(guia.nombre),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: FqColors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: FqColors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey<String>('cerrar-guia'),
            tooltip: l10n.fichaCerrar,
            icon: Icon(
              Icons.close_rounded,
              color: FqColors.white.withValues(alpha: 0.85),
              size: 20,
            ),
            onPressed: onCerrar,
          ),
        ],
      ),
    );
  }
}
