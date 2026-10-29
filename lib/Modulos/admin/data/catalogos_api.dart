import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogo_item.dart';

/// Comunicacion con los endpoints de ADM-11.
///
/// Las operaciones administrativas requieren un usuario con rol Admin.
/// La consulta de elementos activos tambien permite usuarios autenticados.
class CatalogosApi {
  CatalogosApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Devuelve el resumen de los catalogos disponibles.
  Future<List<Map<String, dynamic>>> listarCatalogos() async {
    final dynamic data = await _client.get('/catalogos');

    return (data as List<dynamic>)
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  /// Devuelve todos los elementos, incluidos los desactivados.
  /// Solo Admin.
  Future<List<CatalogoItem>> listarItems(String catalogo) async {
    final dynamic data = await _client.get('/catalogos/$catalogo');

    return (data as List<dynamic>)
        .map(
          (dynamic item) => CatalogoItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  /// Devuelve solo los elementos activos.
  /// Disponible para usuarios autenticados.
  Future<List<CatalogoItem>> listarItemsActivos(String catalogo) async {
    final dynamic data = await _client.get('/catalogos/$catalogo/activos');

    return (data as List<dynamic>)
        .map(
          (dynamic item) => CatalogoItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  /// Crea un elemento nuevo en el catalogo indicado.
  /// Solo Admin.
  Future<CatalogoItem> crearItem({
    required String catalogo,
    required String clave,
    required String nombre,
  }) async {
    final dynamic data = await _client.post('/catalogos/$catalogo', {
      'clave': clave.trim(),
      'nombre': nombre.trim(),
    });

    return CatalogoItem.fromJson(data as Map<String, dynamic>);
  }

  /// Actualiza el nombre y/o estado de un elemento existente.
  /// Solo Admin.
  Future<CatalogoItem> editarItem({
    required String catalogo,
    required int id,
    required String nombre,
    required bool activo,
  }) async {
    final dynamic data = await _client.patch('/catalogos/$catalogo/$id', {
      'nombre': nombre.trim(),
      'activo': activo,
    });

    return CatalogoItem.fromJson(data as Map<String, dynamic>);
  }

  /// Activa o desactiva un elemento sin modificar su nombre.
  /// Solo Admin.
  Future<CatalogoItem> cambiarEstado(CatalogoItem item) {
    return editarItem(
      catalogo: item.catalogo,
      id: item.id,
      nombre: item.nombre,
      activo: !item.activo,
    );
  }
}
