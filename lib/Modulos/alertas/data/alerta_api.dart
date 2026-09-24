import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';

class AlertaApi {
  AlertaApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Alertas vigentes: sirve tanto para el mapa como para la supervision
  /// del admin (no hay cola de moderacion separada, ver AlertaController).
  /// Alertas reportadas por el usuario actual (PRF-02).
  Future<List<Alerta>> misAlertas() async {
    final dynamic data = await _client.get('/alertas/mias');
    return (data as List<dynamic>)
        .map((dynamic e) => Alerta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Alerta>> listar() async {
    final dynamic data = await _client.get('/alertas');
    return (data as List<dynamic>)
        .map((dynamic e) => Alerta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Alerta> reportar({
    required String tipo,
    required String gravedad,
    required double lat,
    required double lng,
    String? descripcion,
  }) async {
    final dynamic data = await _client.post('/alertas', {
      'tipo': tipo,
      'gravedad': gravedad,
      'lat': lat,
      'lng': lng,
      if (descripcion != null && descripcion.trim().isNotEmpty)
        'descripcion': descripcion.trim(),
    });
    return Alerta.fromJson(data as Map<String, dynamic>);
  }

  Future<Alerta> confirmar(int id) async {
    final dynamic data = await _client.patch('/alertas/$id/confirmar', null);
    return Alerta.fromJson(data as Map<String, dynamic>);
  }

  Future<Alerta> desmentir(int id) async {
    final dynamic data = await _client.patch('/alertas/$id/desmentir', null);
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
