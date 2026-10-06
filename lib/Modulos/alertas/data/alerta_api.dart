import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';

class AlertaApi {
  AlertaApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Alertas vigentes: sirve tanto para el mapa como para la supervision
  /// del admin (no hay cola de moderacion separada, ver AlertaController).
  Future<List<Alerta>> listar() async {
    final dynamic data = await _client.get('/alertas');
    return (data as List<dynamic>)
        .map((dynamic e) => Alerta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `tipo` es una clave de la lista cerrada; `tipoOtro` solo viaja (y solo
  /// cuenta) cuando la clave es `otro`.
  Future<Alerta> reportar({
    required String tipo,
    String? tipoOtro,
    required String gravedad,
    required double lat,
    required double lng,
    String? descripcion,
  }) async {
    final dynamic data = await _client.post('/alertas', {
      'tipo': tipo,
      if (tipo == 'otro' && tipoOtro != null && tipoOtro.trim().isNotEmpty)
        'tipoOtro': tipoOtro.trim(),
      'gravedad': gravedad,
      'lat': lat,
      'lng': lng,
      if (descripcion != null && descripcion.trim().isNotEmpty)
        'descripcion': descripcion.trim(),
    });
    return Alerta.fromJson(data as Map<String, dynamic>);
  }

  /// ALR-04 "Sigue ahi". El servidor valida con la posicion enviada que quien
  /// vota esta a menos de 150 m (400 si no) y que no haya votado antes (409).
  Future<Alerta> confirmar(
    int id, {
    required double lat,
    required double lng,
  }) async {
    final dynamic data = await _client.patch('/alertas/$id/confirmar', {
      'lat': lat,
      'lng': lng,
    });
    return Alerta.fromJson(data as Map<String, dynamic>);
  }

  /// ALR-04/05 "Ya no esta". Mismas reglas de cercania y voto unico.
  Future<Alerta> desmentir(
    int id, {
    required double lat,
    required double lng,
  }) async {
    final dynamic data = await _client.patch('/alertas/$id/desmentir', {
      'lat': lat,
      'lng': lng,
    });
    return Alerta.fromJson(data as Map<String, dynamic>);
  }

  /// ADM-06 "Marcar resuelta". Solo Admin.
  Future<Alerta> cambiarEstado(int id, String estado) async {
    final dynamic data = await _client.patch('/alertas/$id/estado', {
      'estado': estado,
    });
    return Alerta.fromJson(data as Map<String, dynamic>);
  }

  /// ADM-06 "Eliminar". Solo Admin.
  Future<void> eliminar(int id) => _client.delete('/alertas/$id');
}
