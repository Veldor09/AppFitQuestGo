import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';

class EventoApi {
  EventoApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  List<Evento> _lista(dynamic data) => (data as List<dynamic>)
      .map((dynamic e) => Evento.fromJson(e as Map<String, dynamic>))
      .toList();

  /// Eventos vigentes y futuros, el mas proximo primero (los ve cualquiera).
  Future<List<Evento>> listar() async => _lista(await _client.get('/eventos'));

  /// Todos los eventos de la empresa, tambien los ya terminados.
  Future<List<Evento>> mios() async =>
      _lista(await _client.get('/eventos/mios'));

  Future<Evento> detalle(int id) async {
    final dynamic data = await _client.get('/eventos/$id');
    return Evento.fromJson(data as Map<String, dynamic>);
  }

  Map<String, dynamic> _cuerpo({
    required String nombre,
    String? descripcion,
    required String categoria,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required List<ZonaEvento> areas,
    required List<ZonaEvento> recorridos,
  }) => <String, dynamic>{
    'nombre': nombre.trim(),
    'descripcion': descripcion?.trim() ?? '',
    'categoria': categoria,
    // El servidor guarda instantes absolutos: se envia en UTC.
    'fechaInicio': fechaInicio.toUtc().toIso8601String(),
    'fechaFin': fechaFin.toUtc().toIso8601String(),
    'areas': <Map<String, dynamic>>[
      for (final ZonaEvento z in areas) z.toJson(),
    ],
    'recorridos': <Map<String, dynamic>>[
      for (final ZonaEvento z in recorridos) z.toJson(),
    ],
  };

  Future<Evento> crear({
    required String nombre,
    String? descripcion,
    required String categoria,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required List<ZonaEvento> areas,
    required List<ZonaEvento> recorridos,
  }) async {
    final dynamic data = await _client.post(
      '/eventos',
      _cuerpo(
        nombre: nombre,
        descripcion: descripcion,
        categoria: categoria,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        areas: areas,
        recorridos: recorridos,
      ),
    );
    return Evento.fromJson(data as Map<String, dynamic>);
  }

  /// Reemplaza todos los datos del evento (la pantalla de edicion siempre
  /// envia el formulario completo).
  Future<Evento> actualizar(
    int id, {
    required String nombre,
    String? descripcion,
    required String categoria,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    required List<ZonaEvento> areas,
    required List<ZonaEvento> recorridos,
  }) async {
    final dynamic data = await _client.patch(
      '/eventos/$id',
      _cuerpo(
        nombre: nombre,
        descripcion: descripcion,
        categoria: categoria,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        areas: areas,
        recorridos: recorridos,
      ),
    );
    return Evento.fromJson(data as Map<String, dynamic>);
  }

  Future<void> eliminar(int id) async {
    await _client.delete('/eventos/$id');
  }
}
