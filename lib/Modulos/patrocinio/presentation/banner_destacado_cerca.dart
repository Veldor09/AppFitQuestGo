import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/geo/formato_distancia.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/patrocinio/application/proximidad_destacados.dart';

/// Tarjeta que aparece sobre el mapa cuando pasas a 1 km o menos de algo
/// destacado: "Destacado cerca de ti · Nombre · 296 m". Tocarla abre su ficha y
/// la X la cierra. Es solo presentacion: quien la usa decide que hace cada toque.
class BannerDestacadoCerca extends StatelessWidget {
  const BannerDestacadoCerca({
    super.key,
    required this.destacado,
    required this.onTap,
    required this.onCerrar,
  });

  final DestacadoCercano destacado;
  final VoidCallback onTap;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String idioma = Localizations.localeOf(context).toString();
    return Container(
      margin: const EdgeInsets.fromLTRB(9, 0, 9, 8),
      decoration: BoxDecoration(
        color: FqColors.white.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: FqColors.amber, width: 1.5),
        boxShadow: FqColors.softShadow,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              key: const ValueKey<String>('banner-destacado'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(19),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.star_rounded,
                      color: FqColors.amber,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.patrocinioCercaTitulo,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${destacado.nombre} · ${formatearDistancia(destacado.metros, locale: idioma)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: FqColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onCerrar,
            tooltip: l10n.alertasAhoraNo,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: FqColors.muted,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
