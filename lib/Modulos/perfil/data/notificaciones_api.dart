import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificacion.dart';

/// Buzón de notificaciones del usuario autenticado (NOT-01).
class NotificacionesApi {
  NotificacionesApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Notificacion>> listar() async {
    final dynamic data = await _client.get('/notificaciones');
    return (data as List<dynamic>)
        .map((dynamic e) => Notificacion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> conteoNoLeidas() async {
    final dynamic data = await _client.get('/notificaciones/no-leidas/conteo');
    return ((data as Map<String, dynamic>)['conteo'] as num).toInt();
  }

  Future<void> marcarLeida(int id) async {
    await _client.patch('/notificaciones/$id/leer', null);
  }

  Future<void> marcarTodasLeidas() async {
    await _client.post('/notificaciones/leer-todas', null);
  }

  Future<void> eliminar(int id) => _client.delete('/notificaciones/$id');
}
