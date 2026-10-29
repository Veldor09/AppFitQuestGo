import 'package:fit_quest_go/core/api/api_client.dart';

class DashboardApi {
  DashboardApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, dynamic>> obtenerResumen() async {
    final dynamic respuesta = await _client.get('/admin/dashboard');

    return Map<String, dynamic>.from(respuesta as Map);
  }
}
