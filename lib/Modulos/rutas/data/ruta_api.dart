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

  /// RTE-03 · Rutas guardadas / favoritas de la cuenta.
  Future<List<Ruta>> favoritas() async {
    final dynamic data = await _client.get('/rutas/favoritas');
    return _lista(data);
  }

  /// IDs de rutas guardadas / favoritas para pintar el icono de favorito en la UI.
  Future<Set<int>> favoritasIds() async {
    final dynamic data = await _client.get('/rutas/favoritas/ids');
    if (data is List) {
      return data
          .where((dynamic e) => e != null)
          .map((dynamic e) => (e as num).toInt())
          .toSet();
    }
    return <int>{};
  }

  /// Alternar estado de favorita para una ruta (guardar / desguardar).
  Future<bool> toggleFavorita(int id) async {
    final dynamic data = await _client.post('/rutas/$id/favorita', null);
    if (data is Map<String, dynamic> && data['favorita'] is bool) {
      return data['favorita'] as bool;
    }
    return false;
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
    String? visibilidad,
  }) async {
    final dynamic data = await _client.post('/rutas', {
      'nombre': nombre,
      'actividades': actividades,
      'dificultad': ?dificultad,
      'distanciaKm': distanciaKm,
      'visibilidad': ?visibilidad,
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
    if (data is! List) return const <Ruta>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> e) => Ruta.fromJson(e))
        .toList();
  }
}
