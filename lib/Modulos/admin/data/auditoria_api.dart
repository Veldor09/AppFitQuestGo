import 'package:fit_quest_go/core/api/api_client.dart';

/// Cliente de consulta de registros de auditoría administrativa.
///
/// Los registros son de solo lectura y no pueden
/// eliminarse ni archivarse desde esta API.
class AuditoriaApi {
  AuditoriaApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Consulta el historial completo de auditoría.
  ///
  /// Admite filtros por administrador, acción, entidad
  /// y rango de fechas, además de paginación.
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
      if (accion != null && accion.trim().isNotEmpty) 'accion': accion.trim(),
      if (entidad != null && entidad.trim().isNotEmpty)
        'entidad': entidad.trim(),
      if (fechaDesde != null)
        'fechaDesde': fechaDesde.toUtc().toIso8601String(),
      if (fechaHasta != null)
        'fechaHasta': fechaHasta.toUtc().toIso8601String(),
    };

    final Uri uri = Uri(path: '/admin/auditoria', queryParameters: parametros);

    final dynamic respuesta = await _client.get(uri.toString());

    return Map<String, dynamic>.from(respuesta as Map);
  }
}
