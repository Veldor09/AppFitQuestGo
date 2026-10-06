import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/clima/data/alerta_clima.dart';

/// Tarjeta sobre el mapa que avisa del clima de la zona: lluvia fuerte,
/// tormenta electrica o calor extremo (ahora o en las proximas horas), con un
/// consejo y el credito del proveedor de los datos. La X la cierra. Es solo
/// presentacion: quien la usa decide cuando mostrarla.
///
/// Ambar para "precaucion" y rojo para "peligro", igual que las alertas del
/// mapa.
class BannerClima extends StatelessWidget {
  const BannerClima({
    super.key,
    required this.alerta,
    required this.fuente,
    required this.masAvisos,
    required this.onCerrar,
  });

  final AlertaClima alerta;

  /// Quien aporta los datos; se muestra como credito (vacio = sin credito).
  final String fuente;

  /// Cuantos avisos mas esperan detras de este.
  final int masAvisos;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Color color = alerta.esPeligro ? FqColors.risk : FqColors.amber;
    final (IconData icono, String titulo, String consejo) = switch (alerta.tipo) {
      TipoClima.lluvia => (
        Icons.water_drop,
        l10n.climaLluviaTitulo,
        l10n.climaConsejoLluvia,
      ),
      TipoClima.tormenta => (
        Icons.thunderstorm,
        l10n.climaTormentaTitulo,
        l10n.climaConsejoTormenta,
      ),
      TipoClima.calor => (
        Icons.thermostat,
        l10n.climaCalorTitulo,
        l10n.climaConsejoCalor,
      ),
    };
    final String cuando = alerta.enHoras == 0
        ? l10n.climaAhora
        : l10n.climaEnHoras(alerta.enHoras);
    final String? medida = _medida(context, l10n);

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(9, 8, 9, 0),
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        decoration: BoxDecoration(
          color: FqColors.white.withValues(alpha: .97),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: color.withValues(alpha: .7), width: 1.5),
          boxShadow: FqColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icono, color: color, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        medida == null ? cuando : '$cuando · $medida',
                        style: const TextStyle(
                          fontSize: 11,
                          color: FqColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (masAvisos > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Text(
                      l10n.climaMasAvisos(masAvisos),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: FqColors.muted,
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
            Padding(
              padding: const EdgeInsets.only(right: 10, top: 2),
              child: Text(
                consejo,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            if (fuente.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.climaFuente(fuente),
                  style: const TextStyle(fontSize: 10, color: FqColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Lo medido, con el separador decimal del idioma: "12 mm/h" o "sensacion
  /// termica de 41,5 °C". La tormenta no lleva medida.
  String? _medida(BuildContext context, AppLocalizations l10n) {
    final double? valor = alerta.valor;
    if (valor == null) return null;
    final String numero = NumberFormat(
      '0.#',
      Localizations.localeOf(context).toString(),
    ).format(valor);
    return switch (alerta.tipo) {
      TipoClima.lluvia => '$numero mm/h',
      TipoClima.calor => l10n.climaMedidaCalor(numero),
      TipoClima.tormenta => null,
    };
  }
}
