import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Apaga lo que Mapbox dibuja por defecto encima de cada mapa: la brujula
/// negra y la barra de escala ("5 km / 12 mi"). Estorban arriba, junto al
/// buscador y la barra de estado, y la app no las usa.
///
/// El logo y la atribucion de Mapbox NO se tocan: sus terminos de uso exigen
/// mostrarlos.
///
/// Se llama al crear cada mapa (`onMapCreated`). Si por cualquier motivo no se
/// pueden apagar, el mapa sigue funcionando igual.
Future<void> ocultarAdornos(MapboxMap mapa) async {
  try {
    await mapa.compass.updateSettings(CompassSettings(enabled: false));
    await mapa.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
  } catch (_) {
    // Un adorno de mas es solo estetico: no debe romper el mapa.
  }
}
