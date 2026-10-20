import 'dart:math' as math;

import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

const double _radioTierraM = 6371000;

/// Distancia en metros del punto [p] al segmento [a]-[b]. Usa una proyeccion
/// plana local (equirectangular), precisa de sobra para tramos de senderos.
double distanciaPuntoASegmentoM(PosicionGps p, PuntoRuta a, PuntoRuta b) {
  final double lat0 = p.lat * math.pi / 180;
  final double kx = _radioTierraM * math.cos(lat0) * math.pi / 180;
  final double ky = _radioTierraM * math.pi / 180;

  final double ax = (a.lng - p.lng) * kx, ay = (a.lat - p.lat) * ky;
  final double bx = (b.lng - p.lng) * kx, by = (b.lat - p.lat) * ky;
  final double dx = bx - ax, dy = by - ay;
  final double largo2 = dx * dx + dy * dy;

  // Segmento degenerado (dos puntos iguales): distancia al punto.
  if (largo2 == 0) return math.sqrt(ax * ax + ay * ay);

  // Proyeccion del origen (el usuario) sobre el segmento, acotada a [0, 1].
  final double t = (-(ax * dx + ay * dy) / largo2).clamp(0.0, 1.0);
  final double cx = ax + t * dx, cy = ay + t * dy;
  return math.sqrt(cx * cx + cy * cy);
}

/// Distancia minima en metros del punto [p] al trazo completo.
double distanciaATrazoM(PosicionGps p, List<PuntoRuta> trazo) {
  if (trazo.isEmpty) return double.infinity;
  if (trazo.length == 1) {
    return distanciaPuntoASegmentoM(p, trazo.first, trazo.first);
  }
  double min = double.infinity;
  for (int i = 0; i < trazo.length - 1; i++) {
    final double d = distanciaPuntoASegmentoM(p, trazo[i], trazo[i + 1]);
    if (d < min) min = d;
  }
  return min;
}

/// Punto mas cercano en el segmento [a]-[b] a la posicion [p].
PosicionGps puntoMasCercanoEnSegmento(PosicionGps p, PuntoRuta a, PuntoRuta b) {
  final double lat0 = p.lat * math.pi / 180;
  final double kx = _radioTierraM * math.cos(lat0) * math.pi / 180;
  final double ky = _radioTierraM * math.pi / 180;

  final double ax = (a.lng - p.lng) * kx, ay = (a.lat - p.lat) * ky;
  final double bx = (b.lng - p.lng) * kx, by = (b.lat - p.lat) * ky;
  final double dx = bx - ax, dy = by - ay;
  final double largo2 = dx * dx + dy * dy;

  if (largo2 == 0) return (lat: a.lat, lng: a.lng);

  final double t = (-(ax * dx + ay * dy) / largo2).clamp(0.0, 1.0);
  return (
    lat: a.lat + t * (b.lat - a.lat),
    lng: a.lng + t * (b.lng - a.lng),
  );
}

/// Punto mas cercano en todo el trazo de la ruta a la posicion [p].
PosicionGps puntoMasCercanoEnTrazo(PosicionGps p, List<PuntoRuta> trazo) {
  if (trazo.isEmpty) return p;
  if (trazo.length == 1) return (lat: trazo.first.lat, lng: trazo.first.lng);

  double min = double.infinity;
  PosicionGps masCercano = (lat: trazo.first.lat, lng: trazo.first.lng);

  for (int i = 0; i < trazo.length - 1; i++) {
    final double d = distanciaPuntoASegmentoM(p, trazo[i], trazo[i + 1]);
    if (d < min) {
      min = d;
      masCercano = puntoMasCercanoEnSegmento(p, trazo[i], trazo[i + 1]);
    }
  }
  return masCercano;
}

enum EventoDesviacion {
  /// Nada que avisar.
  ninguno,

  /// Se salio del sendero (o sigue fuera y toca recordarlo).
  desviado,

  /// Volvio al sendero tras estar desviado.
  regreso,
}

/// Detecta si el usuario se aleja del trazo y decide cuando avisar.
///
/// Para no saturar con avisos: histeresis (se considera desviado al pasar
/// [umbralM], y de regreso solo al bajar de [umbralM] * [factorRegreso]) y un
/// intervalo minimo [intervaloAviso] entre recordatorios.
class DesviacionRutaDetector {
  DesviacionRutaDetector({
    required this.trazo,
    this.umbralM = 40,
    this.factorRegreso = 0.75,
    this.intervaloAviso = const Duration(seconds: 45),
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? DateTime.now;

  final List<PuntoRuta> trazo;
  final double umbralM;
  final double factorRegreso;
  final Duration intervaloAviso;
  final DateTime Function() _ahora;

  bool _desviado = false;
  DateTime? _ultimoAviso;
  double _distanciaM = 0;

  bool get desviado => _desviado;

  /// Distancia al trazo en la ultima posicion evaluada.
  double get distanciaAlTrazoM => _distanciaM;

  /// Evalua una nueva posicion GPS y devuelve que, si acaso, hay que avisar.
  EventoDesviacion evaluar(PosicionGps posicion) {
    _distanciaM = distanciaATrazoM(posicion, trazo);
    final DateTime ahora = _ahora();

    if (!_desviado) {
      if (_distanciaM > umbralM) {
        _desviado = true;
        _ultimoAviso = ahora;
        return EventoDesviacion.desviado;
      }
      return EventoDesviacion.ninguno;
    }

    if (_distanciaM <= umbralM * factorRegreso) {
      _desviado = false;
      _ultimoAviso = null;
      return EventoDesviacion.regreso;
    }

    final DateTime? ultimo = _ultimoAviso;
    if (ultimo == null || ahora.difference(ultimo) >= intervaloAviso) {
      _ultimoAviso = ahora;
      return EventoDesviacion.desviado;
    }
    return EventoDesviacion.ninguno;
  }

  void reiniciar() {
    _desviado = false;
    _ultimoAviso = null;
    _distanciaM = 0;
  }
}
