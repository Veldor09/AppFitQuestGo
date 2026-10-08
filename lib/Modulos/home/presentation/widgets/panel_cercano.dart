import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/tipos_alerta.dart';
import 'package:fit_quest_go/core/geo/formato_distancia.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/home/application/cercanos.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/decoracion_flotante.dart';

/// El cuadro "Cerca de ti" de abajo del mapa: la ruta y la alerta mas cercanas
/// con la distancia a cada una, y el boton "+" para reportar algo donde estas.
///
/// Mientras [hayUbicacion] es falso dice que esta buscando el GPS; con
/// ubicacion y sin [ruta] o [alerta], dice que no hay ninguna cerca. Es solo
/// presentacion: quien la usa calcula lo cercano y decide que abre cada toque.
class PanelCercano extends StatelessWidget {
  const PanelCercano({
    super.key,
    required this.hayUbicacion,
    required this.ruta,
    required this.alerta,
    required this.onRuta,
    required this.onAlerta,
    required this.onAgregar,
  });

  final bool hayUbicacion;
  final RutaCercana? ruta;
  final AlertaCercana? alerta;
  final VoidCallback onRuta;
  final VoidCallback onAlerta;
  final VoidCallback onAgregar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String idioma = Localizations.localeOf(context).toString();
    final RutaCercana? r = ruta;
    final AlertaCercana? a = alerta;
    return Container(
      margin: const EdgeInsets.fromLTRB(9, 0, 9, 10),
      padding: const EdgeInsets.fromLTRB(16, 15, 4, 15),
      decoration: decoracionFlotante(radius: 19),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  l10n.homeCercaDeTi,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.homeMantenPresionado,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 9, color: FqColors.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: <Widget>[
              Expanded(
                child: _Casilla(
                  key: const ValueKey<String>('cerca-ruta'),
                  icono: Icons.route_rounded,
                  titulo: r?.ruta.nombre,
                  detalle: r == null
                      ? null
                      : formatearDistancia(r.metros, locale: idioma),
                  mensaje: hayUbicacion
                      ? l10n.homeSinRutasCerca
                      : l10n.homeBuscandoUbicacion,
                  onTap: r == null ? null : onRuta,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _Casilla(
                  key: const ValueKey<String>('cerca-alerta'),
                  icono: Icons.warning_amber_rounded,
                  titulo: a == null
                      ? null
                      : tipoAlertaLabel(
                          l10n,
                          a.alerta.tipo,
                          otro: a.alerta.tipoOtro,
                        ),
                  detalle: a == null
                      ? null
                      : formatearDistancia(a.metros, locale: idioma),
                  mensaje: hayUbicacion
                      ? l10n.homeSinAlertasCerca
                      : l10n.homeBuscandoUbicacion,
                  onTap: a == null ? null : onAlerta,
                ),
              ),
              const SizedBox(width: 7),
              Tooltip(
                message: l10n.homeReportarAqui,
                child: GestureDetector(
                  key: const ValueKey<String>('cerca-agregar'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onAgregar,
                  child: Container(
                    width: 57,
                    height: 57,
                    decoration: BoxDecoration(
                      color: FqColors.volt,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.add_rounded, size: 32),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Una de las dos casillas: con [titulo] y [detalle] cuando hay algo cerca (y
/// se puede tocar), o solo con [mensaje] cuando no.
class _Casilla extends StatelessWidget {
  const _Casilla({
    super.key,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.mensaje,
    required this.onTap,
  });

  final IconData icono;
  final String? titulo;
  final String? detalle;
  final String mensaje;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool hayDato = titulo != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: FqColors.paper,
          border: Border.all(color: FqColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Icon(icono, size: 20, color: hayDato ? null : FqColors.muted),
            const SizedBox(width: 7),
            Expanded(
              child: hayDato
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          titulo!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (detalle != null)
                          Text(
                            detalle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: FqColors.muted,
                            ),
                          ),
                      ],
                    )
                  : Text(
                      mensaje,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: FqColors.muted,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
