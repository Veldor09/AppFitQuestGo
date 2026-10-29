import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';

class CalificacionApi {
  CalificacionApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  @visibleForTesting
  static CalificacionApi? sustituto;

  static CalificacionApi predeterminada() => sustituto ?? CalificacionApi();

  Future<ResumenCalificacion> resumen(TipoCalificable tipo, int id) async {
    final dynamic data = await _client.get('/calificaciones/${tipo.clave}/$id');
    return ResumenCalificacion.fromJson(data as Map<String, dynamic>);
  }

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
