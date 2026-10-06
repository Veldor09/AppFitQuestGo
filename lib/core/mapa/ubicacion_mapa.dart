import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/geo/posicion_gps.dart';

Future<bool>? _permisoEnCurso;

/// `true` si el servicio de ubicacion esta activo y la app tiene permiso (lo
/// pide si falta). Las llamadas simultaneas comparten una sola solicitud: el
/// sistema rechaza una segunda `requestPermission` mientras la primera sigue
/// abierta, y el mapa y el aviso de alertas cercanas piden a la vez al abrir
/// Home.
Future<bool> asegurarPermisoUbicacion() {
  return _permisoEnCurso ??= _pedirPermiso().whenComplete(
    () => _permisoEnCurso = null,
  );
}

Future<bool> _pedirPermiso() async {
  try {
    if (!await geo.Geolocator.isLocationServiceEnabled()) return false;

    geo.LocationPermission permiso = await geo.Geolocator.checkPermission();
    if (permiso == geo.LocationPermission.denied) {
      permiso = await geo.Geolocator.requestPermission();
    }
    return permiso != geo.LocationPermission.denied &&
        permiso != geo.LocationPermission.deniedForever;
  } catch (_) {
    return false;
  }
}

/// Posiciones del dispositivo mientras la app esta abierta, con un filtro de
/// `distanciaMinimaM` metros entre una y otra. Termina sin emitir nada si no
/// hay servicio de ubicacion o permiso.
Stream<PosicionGps> posicionesGps({int distanciaMinimaM = 10}) async* {
  if (!await asegurarPermisoUbicacion()) return;
  yield* geo.Geolocator.getPositionStream(
    locationSettings: geo.LocationSettings(
      accuracy: geo.LocationAccuracy.high,
      distanceFilter: distanciaMinimaM,
    ),
  ).map((geo.Position p) => (lat: p.latitude, lng: p.longitude));
}

/// Activa el "location puck" (punto azul) y, si hay permiso de ubicacion,
/// mueve la camara a la posicion GPS actual del dispositivo.
///
/// Si el servicio de ubicacion esta apagado, el permiso fue denegado o falla
/// por cualquier otro motivo, no hace nada: el mapa queda en la camara que
/// ya tenia (silencioso, sin romper la pantalla).
Future<void> centrarEnUbicacionActual(MapboxMap controller) async {
  try {
    await controller.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );

    if (!await asegurarPermisoUbicacion()) return;

    final geo.Position posicion = await geo.Geolocator.getCurrentPosition();
    await controller.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(posicion.longitude, posicion.latitude)),
        zoom: 15,
      ),
      MapAnimationOptions(duration: 1200),
    );
  } catch (_) {
    // Sin ubicacion por ahora: el mapa queda en la camara por defecto.
  }
}
