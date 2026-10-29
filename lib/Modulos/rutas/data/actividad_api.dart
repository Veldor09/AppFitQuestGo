import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

/// API de recorridos: registra que el usuario completo una ruta.
///
/// Endpoint: `POST /rutas/:id/recorridos` (JWT). Cuerpo: distanciaKm,
/// duracionSegundos, iniciadoEn, finalizadoEn (ISO 8601) y puntos recorridos.
class ActividadApi {
  ActividadApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<void> registrarRecorrido({
    required int idRuta,
    required double distanciaKm,
    required int duracionSegundos,
    required DateTime iniciadoEn,
    required DateTime finalizadoEn,
    required List<PuntoRuta> puntos,
  }) async {
    await _client.post('/rutas/$idRuta/recorridos', <String, dynamic>{
      'distanciaKm': distanciaKm,
      'duracionSegundos': duracionSegundos,
      'iniciadoEn': iniciadoEn.toUtc().toIso8601String(),
      'finalizadoEn': finalizadoEn.toUtc().toIso8601String(),
      'puntos': <Map<String, double>>[
        for (final PuntoRuta p in puntos)
          <String, double>{'lat': p.lat, 'lng': p.lng},
      ],
    });
  }
}
