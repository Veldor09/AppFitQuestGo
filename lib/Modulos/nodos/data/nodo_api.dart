import 'dart:typed_data';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';

class NodoApi {
  NodoApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Nodos propuestos por el usuario actual (PRF-02).
  Future<List<Nodo>> misNodos() async {
    final dynamic data = await _client.get('/nodos/mios');
    return (data as List<dynamic>)
        .map((dynamic e) => Nodo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Nodo>> listar() async {
    final dynamic data = await _client.get('/nodos');
    return (data as List<dynamic>)
        .map((dynamic e) => Nodo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `categoria` es una clave de la lista cerrada; `categoriaOtro` solo viaja
  /// (y solo cuenta) cuando la clave es `otro`.
  Future<Nodo> proponer({
    required String nombre,
    required String categoria,
    String? categoriaOtro,
    required double lat,
    required double lng,
    String? descripcion,
    String? beneficio,
  }) async {
    final dynamic data = await _client.post('/nodos', {
      'nombre': nombre,
      'categoria': categoria,
      if (categoria == 'otro' &&
          categoriaOtro != null &&
          categoriaOtro.trim().isNotEmpty)
        'categoriaOtro': categoriaOtro.trim(),
      'lat': lat,
      'lng': lng,
      if (descripcion != null && descripcion.trim().isNotEmpty)
        'descripcion': descripcion.trim(),
      if (beneficio != null && beneficio.trim().isNotEmpty)
        'beneficio': beneficio.trim(),
    });
    return Nodo.fromJson(data as Map<String, dynamic>);
  }

  /// Modulo 5 · Edita un Nodo de Abastecimiento propio. Se envia el formulario
  /// completo: una descripcion o un beneficio vacios los borran.
  Future<Nodo> actualizar(
    int id, {
    required String nombre,
    required String categoria,
    String? categoriaOtro,
    required double lat,
    required double lng,
    String? descripcion,
    String? beneficio,
  }) async {
    final dynamic data = await _client.patch('/nodos/$id', {
      'nombre': nombre,
      'categoria': categoria,
      if (categoria == 'otro' &&
          categoriaOtro != null &&
          categoriaOtro.trim().isNotEmpty)
        'categoriaOtro': categoriaOtro.trim(),
      'lat': lat,
      'lng': lng,
      'descripcion': descripcion?.trim() ?? '',
      'beneficio': beneficio?.trim() ?? '',
    });
    return Nodo.fromJson(data as Map<String, dynamic>);
  }

  /// Modulo 5 · Da de baja un Nodo de Abastecimiento propio.
  Future<void> eliminar(int id) async {
    await _client.delete('/nodos/$id');
  }

  /// Adjunta la foto (JPEG, PNG o WebP, hasta 3 MB) a un nodo propio.
  Future<Nodo> subirFoto(int id, Uint8List bytes) async {
    final dynamic data = await _client.subirArchivo(
      '/nodos/$id/foto',
      campo: 'foto',
      bytes: bytes,
      nombreArchivo: 'foto.jpg',
    );
    return Nodo.fromJson(data as Map<String, dynamic>);
  }

  /// Bytes de la foto del nodo; 404 (`ApiException`) si no tiene o no te toca verla.
  Future<Uint8List> foto(int id) => _client.getBytes('/nodos/$id/foto');

  /// NOD-04 · "Sigue ahi": confirma que el punto existe. El servidor exige estar
  /// a menos de 150 m con la posicion enviada, no haberlo votado ni haberlo
  /// propuesto.
  Future<Nodo> confirmar(int id, {required double lat, required double lng}) {
    return _votar(id, 'confirmar', lat, lng);
  }

  /// NOD-04 · "Ya no existe": con suficientes votos el punto sale del mapa.
  Future<Nodo> marcarObsoleto(int id, {required double lat, required double lng}) {
    return _votar(id, 'obsoleto', lat, lng);
  }

  Future<Nodo> _votar(int id, String voto, double lat, double lng) async {
    final dynamic data = await _client.patch('/nodos/$id/$voto', <String, dynamic>{
      'lat': lat,
      'lng': lng,
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
