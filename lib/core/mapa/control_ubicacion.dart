import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/mapa/ubicacion_mapa.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

enum AccionUbicacion {
  centrar,

  inclinar,

  aplanar,
}

const double radioCentradoMetros = 60;

const double inclinacionMinima = 10;

const double inclinacionNavegacion = 60;
const double zoomNavegacion = 17;
const double zoomCentrado = 16;

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

class BotonMiUbicacion extends StatefulWidget {
  const BotonMiUbicacion({super.key, required this.mapa});

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
