import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

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

    final bool servicioActivo = await geo.Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) return;

    geo.LocationPermission permiso = await geo.Geolocator.checkPermission();
    if (permiso == geo.LocationPermission.denied) {
      permiso = await geo.Geolocator.requestPermission();
    }
    if (permiso == geo.LocationPermission.denied ||
        permiso == geo.LocationPermission.deniedForever) {
      return;
    }

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
