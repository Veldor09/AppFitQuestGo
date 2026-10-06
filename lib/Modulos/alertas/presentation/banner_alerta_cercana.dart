import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/catalogos/tipos_alerta.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';

/// Tarjeta que aparece sobre el mapa cuando el usuario se acerca a una alerta
/// activa: "Alerta cerca de ti · ¿Sigue ahi?" con "Si, sigue ahi" /
/// "Ya no esta" (voto con validacion de cercania en el servidor) y una X para
/// cerrarla sin votar. Es solo presentacion: quien la usa decide que hace cada
/// boton.
class BannerAlertaCercana extends StatelessWidget {
  const BannerAlertaCercana({
    super.key,
    required this.alerta,
    required this.metros,
    required this.votando,
    required this.onSigue,
    required this.onNoEsta,
    required this.onCerrar,
  });

  final Alerta alerta;
  final int metros;

  /// Hay un voto en vuelo: se desactivan los botones para no votar dos veces.
  final bool votando;
  final VoidCallback onSigue;
  final VoidCallback onNoEsta;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(9, 0, 9, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
      decoration: BoxDecoration(
        color: FqColors.white.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: FqColors.risk.withValues(alpha: .55), width: 1.5),
        boxShadow: FqColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                color: FqColors.risk,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.alertasCercaTitulo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${tipoAlertaLabel(l10n, alerta.tipo, otro: alerta.tipoOtro)} · ${l10n.alertasCercaDistancia(metros)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: FqColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: votando ? null : onCerrar,
                tooltip: l10n.alertasAhoraNo,
                icon: const Icon(Icons.close_rounded, size: 18),
                color: FqColors.muted,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.alertasSigueAhi,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: FqButton.secondary(
                    label: l10n.alertasBotonNoEsta,
                    dense: true,
                    onPressed: votando ? null : onNoEsta,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FqButton.primary(
                    label: l10n.alertasBotonSigue,
                    dense: true,
                    onPressed: votando ? null : onSigue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
