import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';

class CalificacionApi {
  CalificacionApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Sustituto global para pruebas de pantallas que muestran pulgares sin
  /// recibir la API por parametro (las listas abren fichas por dentro).
  @visibleForTesting
  static CalificacionApi? sustituto;

  /// La API que usan las pantallas cuando nadie les pasa una.
  static CalificacionApi predeterminada() => sustituto ?? CalificacionApi();

  /// Pulgares de una ruta, un nodo o un evento (con el de cada area).
  Future<ResumenCalificacion> resumen(TipoCalificable tipo, int id) async {
    final dynamic data = await _client.get('/calificaciones/${tipo.clave}/$id');
    return ResumenCalificacion.fromJson(data as Map<String, dynamic>);
  }

  /// Pone, cambia o (con [valor] null) retira tu calificacion. Ruta: el
  /// servidor exige que hayas terminado un recorrido (403 si no). Nodo: manda
  /// tu posicion; a mas de 150 m responde 400. Evento: [area] califica esa zona.
  Future<ResumenCalificacion> calificar(
    TipoCalificable tipo,
    int id,
    ValorCalificacion? valor, {
    int? area,
    double? lat,
    double? lng,
  }) async {
    final dynamic data = await _client.put('/calificaciones/${tipo.clave}/$id', {
      'valor': valor?.clave ?? 'ninguno',
      'area': ?area,
      'lat': ?lat,
      'lng': ?lng,
    });
    return ResumenCalificacion.fromJson(data as Map<String, dynamic>);
  }
}
