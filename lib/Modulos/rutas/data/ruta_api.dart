import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

class RutaApi {
  RutaApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Ruta>> explorar() async {
    final dynamic data = await _client.get('/rutas/explorar');
    return _lista(data);
  }

  Future<List<Ruta>> misRutas() async {
    final dynamic data = await _client.get('/rutas/mias');
    return _lista(data);
  }

  /// ADM-04 · Cola de moderacion. Solo Admin.
  Future<List<Ruta>> listarPendientes() async {
    final dynamic data = await _client.get('/rutas/pendientes');
    return _lista(data);
  }

  Future<Ruta> obtener(int id) async {
    final dynamic data = await _client.get('/rutas/$id');
    return Ruta.fromJson(data as Map<String, dynamic>);
  }

  Future<Ruta> crear({
    required String nombre,
    required List<String> actividades,
    String? dificultad,
    required double distanciaKm,
    required List<PuntoRuta> puntos,
  }) async {
    final dynamic data = await _client.post('/rutas', {
      'nombre': nombre,
      'actividades': actividades,
      'dificultad': ?dificultad,
      'distanciaKm': distanciaKm,
      'puntos': <Map<String, double>>[
        for (final PuntoRuta p in puntos) {'lat': p.lat, 'lng': p.lng},
      ],
    });
    return Ruta.fromJson(data as Map<String, dynamic>);
  }

  Future<Ruta> solicitarPublicacion(int id) async {
    final dynamic data = await _client.patch('/rutas/$id/publicar', null);
    return Ruta.fromJson(data as Map<String, dynamic>);
  }

  /// ADM-05 · Aprobar / rechazar. Solo Admin.
  Future<Ruta> cambiarEstado(int id, String estado) async {
    final dynamic data = await _client.patch('/rutas/$id/estado', {
      'estado': estado,
    });
    return Ruta.fromJson(data as Map<String, dynamic>);
  }

  List<Ruta> _lista(dynamic data) {
    return (data as List<dynamic>)
        .map((dynamic e) => Ruta.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
