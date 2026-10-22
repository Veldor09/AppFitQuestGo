import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/mapa/ubicacion_mapa.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// Que hace el boton "mi ubicacion" en este momento.
enum AccionUbicacion {
  /// El mapa esta en otra parte (o ya inclinado): vuelve a ti, de frente al
  /// norte y sin inclinacion.
  centrar,

  /// Ya estas centrado: el mapa se inclina "semihorizontal" y gira hacia
  /// donde vas, como en una guia de navegacion.
  inclinar,

  /// Estas inclinado y sigues cerca de ti: vuelve a la vista cenital al norte.
  aplanar,
}

/// A cuantos metros del centro del mapa se considera que ya estas "centrado".
const double radioCentradoMetros = 60;

/// Desde que inclinacion (grados) el mapa se considera inclinado.
const double inclinacionMinima = 10;

/// Inclinacion y zoom de la vista de navegacion.
const double inclinacionNavegacion = 60;
const double zoomNavegacion = 17;
const double zoomCentrado = 16;

/// Como el boton de ubicacion de Google Maps: un toque te trae a tu posicion;
/// un segundo toque, ya centrado, inclina el mapa y lo gira hacia donde miras;
/// otro toque lo vuelve a poner plano. Se decide mirando la camara, sin
/// recordar el ultimo toque, asi que si mueves el mapa con el dedo el siguiente
/// toque simplemente te vuelve a traer.
AccionUbicacion decidirAccionUbicacion({
  required PosicionGps usuario,
  required PosicionGps centroMapa,
  required double inclinacion,
}) {
  final double metros = distanciaMetros(
    usuario.lat,
    usuario.lng,
    centroMapa.lat,
    centroMapa.lng,
  );
  final bool centrado = metros <= radioCentradoMetros;
  final bool inclinado = inclinacion >= inclinacionMinima;
  if (!centrado) return AccionUbicacion.centrar;
  return inclinado ? AccionUbicacion.aplanar : AccionUbicacion.inclinar;
}

/// Boton redondo de "mi ubicacion" para poner encima de un mapa de Mapbox.
class BotonMiUbicacion extends StatefulWidget {
  const BotonMiUbicacion({super.key, required this.mapa});

  /// El mapa de la pantalla; null mientras todavia no existe.
  final MapboxMap? Function() mapa;

  @override
  State<BotonMiUbicacion> createState() => _BotonMiUbicacionState();
}

class _BotonMiUbicacionState extends State<BotonMiUbicacion> {
  bool _ocupado = false;
  bool _inclinado = false;

  Future<void> _alTocar() async {
    final MapboxMap? mapa = widget.mapa();
    if (mapa == null || _ocupado) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() => _ocupado = true);
    try {
      final ({PosicionGps posicion, double? rumbo})? lectura =
          await obtenerPosicionYRumbo();
      if (lectura == null) {
        notificarInfo(l10n.planificarActivaUbicacion);
        return;
      }
      final PosicionGps usuario = lectura.posicion;
      final CameraState camara = await mapa.getCameraState();
      final AccionUbicacion accion = decidirAccionUbicacion(
        usuario: usuario,
        centroMapa: (
          lat: camara.center.coordinates.lat.toDouble(),
          lng: camara.center.coordinates.lng.toDouble(),
        ),
        inclinacion: camara.pitch,
      );
      await _ejecutar(mapa, accion, usuario, lectura.rumbo, camara.bearing);
      if (mounted) setState(() => _inclinado = accion == AccionUbicacion.inclinar);
    } catch (_) {
      // Sin ubicacion por ahora: el mapa queda como estaba.
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _ejecutar(
    MapboxMap mapa,
    AccionUbicacion accion,
    PosicionGps usuario,
    double? rumbo,
    double rumboCamara,
  ) async {
    // El punto azul, con la flecha de hacia donde miras.
    await mapa.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        puckBearingEnabled: true,
        puckBearing: PuckBearing.HEADING,
      ),
    );
    final Point centro = Point(coordinates: Position(usuario.lng, usuario.lat));
    switch (accion) {
      case AccionUbicacion.inclinar:
        // Vista de navegacion: inclinada, cerca, y girada hacia donde vas (si
        // no te mueves, el rumbo que ya tenia el mapa).
        await mapa.easeTo(
          CameraOptions(
            center: centro,
            zoom: zoomNavegacion,
            pitch: inclinacionNavegacion,
            bearing: rumbo ?? rumboCamara,
          ),
          MapAnimationOptions(duration: 900),
        );
      case AccionUbicacion.centrar:
      case AccionUbicacion.aplanar:
        await mapa.flyTo(
          CameraOptions(
            center: centro,
            zoom: accion == AccionUbicacion.centrar ? zoomCentrado : null,
            bearing: 0,
            pitch: 0,
          ),
          MapAnimationOptions(duration: 900),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Material(
      color: FqColors.white,
      elevation: 3,
      shadowColor: const Color(0x3313233F),
      shape: const CircleBorder(),
      child: InkWell(
        key: const ValueKey<String>('boton-mi-ubicacion'),
        customBorder: const CircleBorder(),
        onTap: _alTocar,
        child: Tooltip(
          message: l10n.mapaMiUbicacion,
          child: SizedBox(
            width: 46,
            height: 46,
            child: _ocupado
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _inclinado
                        ? Icons.navigation_rounded
                        : Icons.my_location_rounded,
                    size: 23,
                    color: _inclinado ? FqColors.river : FqColors.night,
                  ),
          ),
        ),
      ),
    );
  }
}
