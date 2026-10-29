import 'package:fit_quest_go/core/api/api_client.dart';

/// Una solicitud o suscripcion tal como la ve el administrador.
class SuscripcionAdmin {
  const SuscripcionAdmin({
    required this.id,
    required this.estado,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.usuarioEmail,
    required this.usuarioRol,
    required this.planNombre,
    required this.planAudiencia,
    required this.moneda,
    required this.pais,
    this.numeroSolicitud,
    this.monto,
    this.iniciaEn,
    this.venceEn,
    this.creadoEn,
  });

  factory SuscripcionAdmin.fromJson(Map<String, dynamic> json) {
    DateTime? fecha(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
    return SuscripcionAdmin(
      id: (json['id'] as num).toInt(),
      numeroSolicitud: json['numeroSolicitud'] as String?,
      estado: json['estado'] as String,
      usuarioId: (json['usuarioId'] as num).toInt(),
      usuarioNombre: (json['usuarioNombre'] as String?) ?? '',
      usuarioEmail: (json['usuarioEmail'] as String?) ?? '',
      usuarioRol: (json['usuarioRol'] as num?)?.toInt() ?? 1,
      planNombre: (json['planNombre'] as String?) ?? '',
      planAudiencia: (json['planAudiencia'] as String?) ?? 'usuario',
      moneda: (json['moneda'] as String?) ?? 'CRC',
      pais: (json['pais'] as String?) ?? '',
      monto: json['monto'] == null ? null : num.tryParse('${json['monto']}'),
      iniciaEn: fecha(json['iniciaEn']),
      venceEn: fecha(json['venceEn']),
      creadoEn: fecha(json['creadoEn']),
    );
  }

  final int id;

  /// Los 6 digitos que la persona puso en el detalle del SINPE Movil.
  final String? numeroSolicitud;
  final String estado;
  final int usuarioId;
  final String usuarioNombre;
  final String usuarioEmail;
  final int usuarioRol;
  final String planNombre;
  final String planAudiencia;
  final String moneda;
  final String pais;

  /// Lo que debe haber recibido el administrador por SINPE.
  final num? monto;
  final DateTime? iniciaEn;
  final DateTime? venceEn;
  final DateTime? creadoEn;
}

/// Gestion de suscripciones (admin): listar solicitudes y activarlas,
/// rechazarlas o suspenderlas. Todo requiere sesion de administrador.
class SuscripcionesAdminApi {
  SuscripcionesAdminApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  static const String _ruta = '/admin/patrocinio/suscripciones';

  /// Las mas recientes primero. [estado] filtra por estado exacto
  /// (`Solicitada`, `Activa`...); [q] busca por numero de solicitud, nombre o correo.
  Future<List<SuscripcionAdmin>> listar({String? estado, String? q}) async {
    final Map<String, String> params = <String, String>{
      if (estado != null && estado.isNotEmpty) 'estado': estado,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
    };
    final String consulta = params.isEmpty
        ? ''
        : '?${params.entries.map((MapEntry<String, String> e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    final dynamic data = await _client.get('$_ruta$consulta');
    return (data as List<dynamic>)
        .map(
          (dynamic e) =>
              SuscripcionAdmin.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// El pago ya se recibio: el plan empieza a regir ahora.
  Future<void> aprobar(int id) async {
    await _client.patch('$_ruta/$id/aprobar', null);
  }

  /// [motivo] (10 a 500 caracteres) le llega a la persona.
  Future<void> rechazar(int id, String motivo) async {
    await _client.patch('$_ruta/$id/rechazar', <String, Object?>{
      'motivo': motivo,
    });
  }

  Future<void> suspender(int id) async {
    await _client.patch('$_ruta/$id/suspender', null);
  }
}
