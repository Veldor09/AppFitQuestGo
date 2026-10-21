import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/mapa/mapbox_config.dart';

/// Camino por calles entre dos puntos: trazo, distancia (m) y duracion (s).
class RutaVial {
  const RutaVial({
    required this.puntos,
    required this.distanciaMetros,
    required this.duracionSegundos,
    this.esLineaRecta = false,
  });

  final List<PosicionGps> puntos;
  final double distanciaMetros;
  final double duracionSegundos;

  /// True cuando no se pudo consultar Mapbox y es solo la linea directa.
  final bool esLineaRecta;
}

/// Consulta la API Directions de Mapbox para llegar al inicio de una ruta.
///
/// Cuidado con la cuota gratuita: hace UNA sola peticion por llamada, sin
/// reintentos, y no consulta nada si el usuario ya esta cerca del destino.
/// Nunca lanza: si falla (sin red, error, timeout) devuelve la linea recta.
class MapboxDirectionsService {
  MapboxDirectionsService({http.Client? client, String? accessToken})
      : _client = client ?? http.Client(),
        _token = accessToken ?? kMapboxAccessToken;

  final http.Client _client;
  final String _token;

  /// Debajo de esta distancia no se llama a la API: ya estas practicamente en el inicio.
  static const double umbralCercaniaMetros = 30;
  static const Duration _tiempoMaximo = Duration(seconds: 8);

  /// Devuelve null si el origen ya esta a menos de [umbralCercaniaMetros] del
  /// destino (no hay nada que guiar). [perfil]: `driving` o `walking`.
  Future<RutaVial?> rutaHastaInicio({
    required PosicionGps origen,
    required PosicionGps destino,
    String perfil = 'driving',
  }) async {
    final double directa =
        distanciaMetros(origen.lat, origen.lng, destino.lat, destino.lng);
    if (directa < umbralCercaniaMetros) return null;

    try {
      final Uri url = Uri.https(
        'api.mapbox.com',
        '/directions/v5/mapbox/$perfil/'
            '${origen.lng},${origen.lat};${destino.lng},${destino.lat}',
        <String, String>{
          'geometries': 'geojson',
          'overview': 'full',
          'access_token': _token,
        },
      );
      final http.Response res = await _client.get(url).timeout(_tiempoMaximo);
      if (res.statusCode != 200) return _lineaRecta(origen, destino, directa);

      final Map<String, dynamic> cuerpo =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> rutas = (cuerpo['routes'] as List<dynamic>?) ?? <dynamic>[];
      if (rutas.isEmpty) return _lineaRecta(origen, destino, directa);

      final Map<String, dynamic> r = rutas.first as Map<String, dynamic>;
      final List<dynamic> coords =
          ((r['geometry'] as Map<String, dynamic>)['coordinates'] as List<dynamic>);
      final List<PosicionGps> puntos = <PosicionGps>[
        for (final dynamic c in coords)
          (
            lat: ((c as List<dynamic>)[1] as num).toDouble(),
            lng: (c[0] as num).toDouble(),
          ),
      ];
      if (puntos.length < 2) return _lineaRecta(origen, destino, directa);

      return RutaVial(
        puntos: puntos,
        distanciaMetros: (r['distance'] as num).toDouble(),
        duracionSegundos: (r['duration'] as num).toDouble(),
      );
    } catch (_) {
      return _lineaRecta(origen, destino, directa);
    }
  }

  RutaVial _lineaRecta(PosicionGps origen, PosicionGps destino, double metros) {
    return RutaVial(
      puntos: <PosicionGps>[origen, destino],
      distanciaMetros: metros,
      duracionSegundos: 0,
      esLineaRecta: true,
    );
  }
}
