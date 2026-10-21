import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

/// Descarga y borra las teselas de Mapbox de la zona de una ruta, para poder
/// ver el mapa sin conexion. Cada ruta es una "tile region" (`ruta_<id>`).
///
/// Todo es tolerante a fallos: devuelve false en vez de lanzar, porque la
/// descarga es un extra y no debe romper guardar la ruta.
class MapasOfflineServicio {
  MapasOfflineServicio._();

  static final MapasOfflineServicio instancia = MapasOfflineServicio._();

  /// Zooms descargados: 12 (vista general) a 14 (detalle de sendero).
  /// Mantenerlo acotado evita descargar teselas innecesarias y protege
  /// totalmente la cuota gratuita de Mapbox.
  static const int _zoomMin = 12;
  static const int _zoomMax = 14;

  /// Margen alrededor del trazo (~500 metros), justo para ver el contexto de la ruta.
  static const double _margenGrados = 0.005;

  String _idRegion(int idRuta) => 'ruta_$idRuta';

  Future<bool> descargarZonaDeRuta(
    Ruta ruta, {
    void Function(double progreso)? alProgresar,
  }) async {
    if (ruta.puntos.length < 2) return false;
    try {
      double minLat = ruta.puntos.first.lat, maxLat = minLat;
      double minLng = ruta.puntos.first.lng, maxLng = minLng;
      for (final PuntoRuta p in ruta.puntos) {
        if (p.lat < minLat) minLat = p.lat;
        if (p.lat > maxLat) maxLat = p.lat;
        if (p.lng < minLng) minLng = p.lng;
        if (p.lng > maxLng) maxLng = p.lng;
      }
      minLat -= _margenGrados;
      maxLat += _margenGrados;
      minLng -= _margenGrados;
      maxLng += _margenGrados;

      final Polygon zona = Polygon(
        coordinates: <List<Position>>[
          <Position>[
            Position(minLng, minLat),
            Position(maxLng, minLat),
            Position(maxLng, maxLat),
            Position(minLng, maxLat),
            Position(minLng, minLat),
          ],
        ],
      );

      final TileStore tileStore = await TileStore.createDefault();
      await tileStore.loadTileRegion(
        _idRegion(ruta.id),
        TileRegionLoadOptions(
          geometry: zona.toJson(),
          descriptorsOptions: <TilesetDescriptorOptions>[
            TilesetDescriptorOptions(
              styleURI: MapboxStyles.STANDARD,
              minZoom: _zoomMin,
              maxZoom: _zoomMax,
            ),
          ],
          acceptExpired: true,
          networkRestriction: NetworkRestriction.NONE,
        ),
        (TileRegionLoadProgress p) {
          if (p.requiredResourceCount > 0) {
            alProgresar?.call(p.completedResourceCount / p.requiredResourceCount);
          }
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> eliminarZonaDeRuta(int idRuta) async {
    try {
      final TileStore tileStore = await TileStore.createDefault();
      await tileStore.removeRegion(_idRegion(idRuta));
    } catch (_) {}
  }
}
