import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/admin/data/insignia_admin_item.dart';

/// ADM-10: Comunicación con los endpoints administrativos de insignias.
///
/// Todas las operaciones requieren autenticación JWT y rol Admin.
class InsigniasAdminApi {
  InsigniasAdminApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  static const String _ruta = '/insignias/admin';

  /// Obtiene todas las insignias, incluidas las inactivas.
  Future<List<InsigniaAdminItem>> listarInsignias() async {
    final dynamic data = await _client.get(_ruta);

    return (data as List<dynamic>)
        .map(
          (dynamic item) => InsigniaAdminItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  /// Obtiene una insignia por su identificador.
  Future<InsigniaAdminItem> obtenerInsignia(int id) async {
    final dynamic data = await _client.get('$_ruta/$id');

    return InsigniaAdminItem.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Crea una nueva insignia.
  ///
  /// El backend valida el código único, el tipo, la métrica y la meta.
  Future<InsigniaAdminItem> crearInsignia({
    required String codigo,
    required String nombre,
    required String descripcion,
    required String emoji,
    required String tipo,
    required String metrica,
    required double meta,
    bool activa = true,
  }) async {
    final Map<String, dynamic> datos = <String, dynamic>{
      'codigo': codigo.trim().toUpperCase(),
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'emoji': emoji.trim(),
      'tipo': tipo,
      'metrica': metrica,
      'meta': meta,
      'activa': activa,
    };

    final dynamic respuesta = await _client.post(_ruta, datos);

    return InsigniaAdminItem.fromJson(
      Map<String, dynamic>.from(respuesta as Map),
    );
  }

  /// Edita los campos de una insignia existente.
  ///
  /// El código único no puede modificarse después de la creación.
  /// Los parámetros opcionales permiten actualizar solo los campos enviados.
  Future<InsigniaAdminItem> editarInsignia({
    required int id,
    String? nombre,
    String? descripcion,
    String? emoji,
    String? tipo,
    String? metrica,
    double? meta,
    bool? activa,
  }) async {
    final Map<String, dynamic> datos = <String, dynamic>{};

    if (nombre != null) {
      datos['nombre'] = nombre.trim();
    }

    if (descripcion != null) {
      datos['descripcion'] = descripcion.trim();
    }

    if (emoji != null) {
      datos['emoji'] = emoji.trim();
    }

    if (tipo != null) {
      datos['tipo'] = tipo;
    }

    if (metrica != null) {
      datos['metrica'] = metrica;
    }

    if (meta != null) {
      datos['meta'] = meta;
    }

    if (activa != null) {
      datos['activa'] = activa;
    }

    final dynamic respuesta = await _client.patch('$_ruta/$id', datos);

    return InsigniaAdminItem.fromJson(
      Map<String, dynamic>.from(respuesta as Map),
    );
  }

  /// Activa o desactiva una insignia.
  ///
  /// Solo modifica el estado, sin alterar sus demás propiedades.
  Future<InsigniaAdminItem> cambiarEstado(InsigniaAdminItem insignia) {
    return editarInsignia(id: insignia.id, activa: !insignia.activa);
  }
}
