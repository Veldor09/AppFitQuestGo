import 'dart:math' as math;

import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

const double _radioTierraM = 6371000;

/// Avance de una persona sobre el trazo de una ruta.
class ProgresoEnRuta {
  const ProgresoEnRuta({
    required this.progresoM,
    required this.restanteM,
    required this.distanciaAlTrazoM,
    this.indiceSegmento = 0,
  });

  /// Metros recorridos sobre el trazo hasta el punto mas cercano a la persona.
  final double progresoM;

  /// Metros que faltan para el final del trazo.
  final double restanteM;

  /// A cuantos metros del trazo esta la persona.
  final double distanciaAlTrazoM;

  /// Indice del segmento del trazo mas cercano al progreso actual.
  final int indiceSegmento;
}

/// Proyecta la posicion sobre el segmento mas cercano del trazo y calcula
/// cuanto lleva recorrido y cuanto falta. Con menos de 2 puntos no hay trazo.
/// Si se pasa [indiceReferencia], prioriza la ventana local de segmentos alrededor
/// de ese indice para evitar saltos indeseados en circuitos cerrados o de ida y vuelta.
ProgresoEnRuta calcularProgreso(
  PosicionGps posicion,
  List<PuntoRuta> trazo, {
  int? indiceReferencia,
}) {
  if (trazo.length < 2) {
    return const ProgresoEnRuta(
      progresoM: 0,
      restanteM: 0,
      distanciaAlTrazoM: double.infinity,
      indiceSegmento: 0,
    );
  }

  final double kx =
      _radioTierraM * math.cos(posicion.lat * math.pi / 180) * math.pi / 180;
  final double ky = _radioTierraM * math.pi / 180;

  final List<double> largos = <double>[];
  final List<double> acumulados = <double>[0];
  double total = 0;
  for (int i = 0; i < trazo.length - 1; i++) {
    final double l = distanciaMetros(
      trazo[i].lat,
      trazo[i].lng,
      trazo[i + 1].lat,
      trazo[i + 1].lng,
    );
    largos.add(l);
    total += l;
    acumulados.add(total);
  }

  ({double dist, double progreso, int segmento}) evaluarSegmento(int i) {
    final PuntoRuta a = trazo[i];
    final PuntoRuta b = trazo[i + 1];
    final double largo = largos[i];

    final double ax = (a.lng - posicion.lng) * kx,
        ay = (a.lat - posicion.lat) * ky;
    final double bx = (b.lng - posicion.lng) * kx,
        by = (b.lat - posicion.lat) * ky;
    final double dx = bx - ax, dy = by - ay;
    final double largo2 = dx * dx + dy * dy;
    final double t = largo2 == 0
        ? 0
        : (-(ax * dx + ay * dy) / largo2).clamp(0.0, 1.0);
    final double cx = ax + t * dx, cy = ay + t * dy;
    final double d = math.sqrt(cx * cx + cy * cy);
    final double prog = acumulados[i] + t * largo;
    return (dist: d, progreso: prog, segmento: i);
  }

  // Si hay un indice de referencia, buscar primero en una ventana local [ref - 2 .. ref + 5]
  // para evitar saltos indeseados en circuitos cerrados (ej. vuelta a la plaza donde inicio == fin).
  if (indiceReferencia != null) {
    final int inicio = math.max(0, indiceReferencia - 2);
    final int fin = math.min(trazo.length - 2, indiceReferencia + 5);
    double mejorDistVentana = double.infinity;
    double mejorProgVentana = 0;
    int mejorSegVentana = inicio;

    for (int i = inicio; i <= fin; i++) {
      final ({double dist, double progreso, int segmento}) res =
          evaluarSegmento(i);
      if (res.dist < mejorDistVentana) {
        mejorDistVentana = res.dist;
        mejorProgVentana = res.progreso;
        mejorSegVentana = res.segmento;
      }
    }

    if (mejorDistVentana <= 50) {
      return ProgresoEnRuta(
        progresoM: mejorProgVentana,
        restanteM: math.max(0, total - mejorProgVentana),
        distanciaAlTrazoM: mejorDistVentana,
        indiceSegmento: mejorSegVentana,
      );
    }
  }

  // Busqueda global si no hay indice de referencia o si el usuario esta a > 50m de la ventana local.
  double mejorDistancia = double.infinity;
  double mejorProgreso = 0;
  int mejorSegmento = 0;

  for (int i = 0; i < trazo.length - 1; i++) {
    final ({double dist, double progreso, int segmento}) res =
        evaluarSegmento(i);
    if (res.dist < mejorDistancia) {
      mejorDistancia = res.dist;
      mejorProgreso = res.progreso;
      mejorSegmento = res.segmento;
    }
  }

  return ProgresoEnRuta(
    progresoM: mejorProgreso,
    restanteM: math.max(0, total - mejorProgreso),
    distanciaAlTrazoM: mejorDistancia,
    indiceSegmento: mejorSegmento,
  );
}

/// Rumbo en grados (0 = norte, 90 = este) para ir de [a] a [b].
double rumboEntre(PosicionGps a, PosicionGps b) {
  final double lat1 = a.lat * math.pi / 180;
  final double lat2 = b.lat * math.pi / 180;
  final double dLng = (b.lng - a.lng) * math.pi / 180;
  final double y = math.sin(dLng) * math.cos(lat2);
  final double x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Reduce un trazo largo a lo sumo a [maximo] puntos tomando uno cada tanto
/// (conserva siempre el primero y el ultimo), para que el envio al servidor
/// no pese de mas.
List<PuntoRuta> adelgazarTrazo(List<PuntoRuta> puntos, {int maximo = 1500}) {
  if (puntos.length <= maximo || maximo < 2) return List<PuntoRuta>.of(puntos);
  final double paso = (puntos.length - 1) / (maximo - 1);
  return <PuntoRuta>[
    for (int i = 0; i < maximo - 1; i++) puntos[(i * paso).floor()],
    puntos.last,
  ];
}
