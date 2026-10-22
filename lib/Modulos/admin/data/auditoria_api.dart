
import 'package:fit_quest_go/core/api/api_client.dart';

/// Cliente para consultar y archivar los registros
/// de auditoría administrativa.
class AuditoriaApi {
  AuditoriaApi([ApiClient? client])
      : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Consulta los registros de auditoría no archivados.
  ///
  /// Admite filtros y paginación.
  Future<Map<String, dynamic>> consultar({
    int? administradorId,
    String? accion,
    String? entidad,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int pagina = 1,
    int limite = 20,
  }) async {
    final Map<String, String> parametros = <String, String>{
      'pagina': pagina.toString(),
      'limite': limite.toString(),
      if (administradorId != null)
        'administradorId': administradorId.toString(),
      if (accion != null && accion.trim().isNotEmpty)
        'accion': accion.trim(),
      if (entidad != null && entidad.trim().isNotEmpty)
        'entidad': entidad.trim(),
      if (fechaDesde != null)
        'fechaDesde': fechaDesde.toUtc().toIso8601String(),
      if (fechaHasta != null)
        'fechaHasta': fechaHasta.toUtc().toIso8601String(),
    };

    final Uri uri = Uri(
      path: '/admin/auditoria',
      queryParameters: parametros,
    );

    final dynamic respuesta =
        await _client.get(uri.toString());

    return Map<String, dynamic>.from(respuesta as Map);
  }

  /// Archiva un registro de auditoría por su ID.
  ///
  /// El backend conserva el registro en PostgreSQL,
  /// incluyendo el administrador responsable y la fecha.
  ///
  /// Solo puede ejecutarse con una sesión de administrador.
  Future<Map<String, dynamic>> archivar(int id) async {
    if (id <= 0) {
      throw ArgumentError.value(
        id,
        'id',
        'El ID del registro debe ser mayor que cero',
      );
    }

    final dynamic respuesta =
        await _client.delete('/admin/auditoria/$id');

    return Map<String, dynamic>.from(respuesta as Map);
  }
}
