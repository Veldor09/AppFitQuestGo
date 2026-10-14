import 'package:fit_quest_go/core/api/api_client.dart';

class ReporteContenidoApi {
  ReporteContenidoApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Map<String, dynamic>>> listar() async {
    final dynamic respuesta = await _client.get('/reportes-contenido');

    return (respuesta as List<dynamic>)
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> obtener(int id) async {
    final dynamic respuesta = await _client.get('/reportes-contenido/$id');
    return Map<String, dynamic>.from(respuesta as Map);
  }

  Future<Map<String, dynamic>> cambiarEstado(int id, String estado) async {
    final dynamic respuesta = await _client.patch(
      '/reportes-contenido/$id/estado',
      <String, dynamic>{'estado': estado},
    );

    return Map<String, dynamic>.from(respuesta as Map);
  }
}
