import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';

/// El centro de un area dibujada (un poligono): ahi va su pin.
///
/// Es el centroide del poligono —el promedio ponderado por el area—, que cae
/// "en medio" aunque el trazo tenga mas puntos de un lado que de otro. Si el
/// trazo es casi una linea (area cero) devuelve el promedio de los vertices.
/// A la escala de un evento (unos km) tratar lat/lng como un plano es exacto
/// de sobra.
///
/// [puntos] no repite el primer punto al final (asi se guardan las areas).
PuntoGeo centroideDe(List<PuntoGeo> puntos) {
  if (puntos.isEmpty) {
    throw ArgumentError('Un area sin puntos no tiene centro');
  }
  if (puntos.length < 3) return _promedio(puntos);

  double area2 = 0; // el doble del area con signo
  double cx = 0;
  double cy = 0;
  for (int i = 0; i < puntos.length; i++) {
    final PuntoGeo a = puntos[i];
    final PuntoGeo b = puntos[(i + 1) % puntos.length];
    final double cruz = a.lng * b.lat - b.lng * a.lat;
    area2 += cruz;
    cx += (a.lng + b.lng) * cruz;
    cy += (a.lat + b.lat) * cruz;
  }
  // Un trazo casi recto no tiene area: el promedio de los vertices es el centro.
  if (area2.abs() < 1e-18) return _promedio(puntos);
  return PuntoGeo(lat: cy / (3 * area2), lng: cx / (3 * area2));
}

PuntoGeo _promedio(List<PuntoGeo> puntos) {
  double lat = 0;
  double lng = 0;
  for (final PuntoGeo p in puntos) {
    lat += p.lat;
    lng += p.lng;
  }
  return PuntoGeo(lat: lat / puntos.length, lng: lng / puntos.length);
}
