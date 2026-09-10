import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';

class NodoApi {
  NodoApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Nodo>> listar() async {
    final dynamic data = await _client.get('/nodos');
    return (data as List<dynamic>)
        .map((dynamic e) => Nodo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Nodo> proponer({
    required String nombre,
    required String categoria,
    required double lat,
    required double lng,
    String? descripcion,
  }) async {
    final dynamic data = await _client.post('/nodos', {
      'nombre': nombre,
      'categoria': categoria,
      'lat': lat,
      'lng': lng,
      if (descripcion != null && descripcion.trim().isNotEmpty)
        'descripcion': descripcion.trim(),
    });
    return Nodo.fromJson(data as Map<String, dynamic>);
  }

  /// ADM-07 · Cola de moderacion. Solo Admin.
  Future<List<Nodo>> listarPendientes() async {
    final dynamic data = await _client.get('/nodos/pendientes');
    return (data as List<dynamic>)
        .map((dynamic e) => Nodo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// ADM-07 · Aprobar / rechazar. Solo Admin.
  Future<Nodo> cambiarEstado(int id, String estado) async {
    final dynamic data = await _client.patch('/nodos/$id/estado', {
      'estado': estado,
    });
    return Nodo.fromJson(data as Map<String, dynamic>);
  }
}
