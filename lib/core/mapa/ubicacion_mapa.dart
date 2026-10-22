import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
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
Stream<PosicionGps> posicionesGps({
  int distanciaMinimaM = 10,
  bool segundoPlano = false,
  String? tituloNotificacion,
  String? mensajeNotificacion,
}) async* {
  if (!await asegurarPermisoUbicacion()) return;
  final geo.LocationSettings settings;
  if (defaultTargetPlatform == TargetPlatform.android) {
    settings = geo.AndroidSettings(
      accuracy: geo.LocationAccuracy.high,
      distanceFilter: distanciaMinimaM,
      intervalDuration: const Duration(seconds: 3),
      foregroundNotificationConfig: segundoPlano
          ? geo.ForegroundNotificationConfig(
              notificationTitle: tituloNotificacion ?? 'FitQuest Go · Grabación GPS activa',
              notificationText: mensajeNotificacion ?? 'Registrando tu recorrido en segundo plano...',
              notificationIcon: const geo.AndroidResource(name: 'ic_launcher'),
              enableWakeLock: true,
            )
          : null,
    );
  } else {
    settings = geo.LocationSettings(
      accuracy: geo.LocationAccuracy.high,
      distanceFilter: distanciaMinimaM,
    );
  }
  yield* geo.Geolocator.getPositionStream(
    locationSettings: settings,
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

    final geo.Position posicion = await geo.Geolocator.getCurrentPosition(
      timeLimit: const Duration(seconds: 5),
    );
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

/// Abre los ajustes del sistema para encender la ubicacion o los permisos de la app.
Future<void> abrirConfiguracionUbicacion() async {
  try {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      await geo.Geolocator.openLocationSettings();
    } else {
      await geo.Geolocator.openAppSettings();
    }
  } catch (_) {}
}

/// Obtiene rapidamente la ultima ubicacion conocida o la posicion actual
/// para inicializar la camara y estado sin esperar al stream periodico.
Future<PosicionGps?> obtenerPosicionActualRapida() async {
  try {
    if (!await asegurarPermisoUbicacion()) return null;
    final geo.Position? previa = await geo.Geolocator.getLastKnownPosition();
    if (previa != null) return (lat: previa.latitude, lng: previa.longitude);
    final geo.Position actual = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        timeLimit: Duration(seconds: 4),
      ),
    );
    return (lat: actual.latitude, lng: actual.longitude);
  } catch (_) {
    return null;
  }
}

/// La posicion de ahora mismo y, si el dispositivo se esta moviendo, hacia
/// donde va (grados desde el norte). A diferencia de
/// [obtenerPosicionActualRapida] no se conforma con la ultima conocida, que
/// puede ser de hace rato: si el GPS no responde a tiempo cae a esa, sin rumbo.
Future<({PosicionGps posicion, double? rumbo})?> obtenerPosicionYRumbo() async {
  try {
    if (!await asegurarPermisoUbicacion()) return null;
    final geo.Position actual = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        timeLimit: Duration(seconds: 5),
      ),
    );
    // El rumbo del GPS solo vale con el dispositivo en movimiento.
    final bool enMarcha = actual.speed > 0.5 && actual.heading >= 0;
    return (
      posicion: (lat: actual.latitude, lng: actual.longitude),
      rumbo: enMarcha ? actual.heading : null,
    );
  } catch (_) {
    final PosicionGps? previa = await obtenerPosicionActualRapida();
    return previa == null ? null : (posicion: previa, rumbo: null);
  }
}
