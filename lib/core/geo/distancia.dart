import 'dart:math' as math;

const double _radioTierraMetros = 6371000;

double _aRadianes(double grados) => grados * math.pi / 180;

/// Distancia en metros entre dos coordenadas (formula de haversine).
double distanciaMetros(double lat1, double lng1, double lat2, double lng2) {
  final double senoLat = math.sin(_aRadianes(lat2 - lat1) / 2);
  final double senoLng = math.sin(_aRadianes(lng2 - lng1) / 2);
  final double h =
      senoLat * senoLat +
      math.cos(_aRadianes(lat1)) *
          math.cos(_aRadianes(lat2)) *
          senoLng *
          senoLng;
  return _radioTierraMetros * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}
