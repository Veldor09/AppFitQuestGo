import 'dart:math' as math;

import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';

const double _metrosPorGradoLat = 111320;

/// Simplifica un trazo dibujado a mano alzada con Ramer-Douglas-Peucker: quita
/// los puntos que se desvian menos de [toleranciaM] metros de la recta entre
/// sus vecinos conservados. Un dedo genera cientos de puntos por segundo; asi
/// el trazo viaja y se guarda con un puñado, sin cambiar su forma a la vista.
///
/// Siempre conserva el primer y el ultimo punto. Con 2 puntos o menos
/// devuelve el trazo tal cual.
List<PuntoGeo> simplificarTrazo(
  List<PuntoGeo> puntos, {
  double toleranciaM = 3,
}) {
  if (puntos.length <= 2) return List<PuntoGeo>.of(puntos);

  // Plano local en metros alrededor de la latitud media: a la escala de un
  // evento (unos km) el error frente a la esfera es despreciable.
  final double latMedia =
      puntos.map((PuntoGeo p) => p.lat).reduce((double a, double b) => a + b) /
      puntos.length;
  final double escalaLng =
      _metrosPorGradoLat * math.cos(latMedia * math.pi / 180);
  final List<(double, double)> xy = <(double, double)>[
    for (final PuntoGeo p in puntos)
      (p.lng * escalaLng, p.lat * _metrosPorGradoLat),
  ];

  final List<bool> conservar = List<bool>.filled(puntos.length, false);
  conservar[0] = true;
  conservar[puntos.length - 1] = true;

  // Pila en vez de recursion: un trazo largo no desborda la pila de llamadas.
  final List<(int, int)> pendientes = <(int, int)>[(0, puntos.length - 1)];
  while (pendientes.isNotEmpty) {
    final (int inicio, int fin) = pendientes.removeLast();
    double maxima = 0;
    int indice = -1;
    for (int i = inicio + 1; i < fin; i++) {
      final double d = _distanciaASegmento(xy[i], xy[inicio], xy[fin]);
      if (d > maxima) {
        maxima = d;
        indice = i;
      }
    }
    if (indice != -1 && maxima > toleranciaM) {
      conservar[indice] = true;
      pendientes
        ..add((inicio, indice))
        ..add((indice, fin));
    }
  }

  return <PuntoGeo>[
    for (int i = 0; i < puntos.length; i++)
      if (conservar[i]) puntos[i],
  ];
}

double _distanciaASegmento(
  (double, double) p,
  (double, double) a,
  (double, double) b,
) {
  final double dx = b.$1 - a.$1;
  final double dy = b.$2 - a.$2;
  final double largo2 = dx * dx + dy * dy;
  if (largo2 == 0) {
    return math.sqrt(math.pow(p.$1 - a.$1, 2) + math.pow(p.$2 - a.$2, 2));
  }
  final double t = (((p.$1 - a.$1) * dx + (p.$2 - a.$2) * dy) / largo2).clamp(
    0.0,
    1.0,
  );
  final double cx = a.$1 + t * dx;
  final double cy = a.$2 + t * dy;
  return math.sqrt(math.pow(p.$1 - cx, 2) + math.pow(p.$2 - cy, 2));
}

/// Quita el ultimo punto de un area si repite el primero: el backend guarda
/// el poligono abierto (se cierra solo al dibujarlo).
List<PuntoGeo> abrirArea(List<PuntoGeo> puntos) {
  if (puntos.length > 1 && puntos.first == puntos.last) {
    return puntos.sublist(0, puntos.length - 1);
  }
  return puntos;
}
