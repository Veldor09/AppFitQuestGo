import 'package:fit_quest_go/core/api/api_client.dart';

/// Un plan de patrocinio con el precio que le toca a quien lo pide (la moneda
/// depende del pais; no hay conversion).
class PlanPatrocinio {
  const PlanPatrocinio({
    required this.id,
    required this.nombre,
    required this.duracionDias,
    required this.moneda,
    required this.importe,
  });

  factory PlanPatrocinio.fromJson(Map<String, dynamic> json) => PlanPatrocinio(
    id: (json['id'] as num).toInt(),
    nombre: json['nombre'] as String,
    duracionDias: (json['duracionDias'] as num).toInt(),
    moneda: json['moneda'] as String,
    // El servidor manda el importe como texto decimal ("10000.00").
    importe: num.parse(json['importe'].toString()),
  );

  final int id;
  final String nombre;
  final int duracionDias;
  final String moneda;
  final num importe;
}

/// Los estados de una suscripcion tal como los manda el servidor.
class EstadoSuscripcion {
  const EstadoSuscripcion._();
  static const String solicitada = 'Solicitada';
  static const String activa = 'Activa';
  static const String vencida = 'Vencida';
  static const String suspendida = 'Suspendida';
  static const String rechazada = 'Rechazada';
}

/// La suscripcion mas reciente de la persona.
class MiSuscripcion {
  const MiSuscripcion({
    required this.id,
    required this.estado,
    required this.vigente,
    required this.planNombre,
    this.venceEn,
  });

  factory MiSuscripcion.fromJson(Map<String, dynamic> json) => MiSuscripcion(
    id: (json['id'] as num).toInt(),
    estado: json['estado'] as String,
    vigente: json['vigente'] == true,
    planNombre: (json['planNombre'] as String?) ?? '',
    venceEn: json['venceEn'] == null
        ? null
        : DateTime.tryParse(json['venceEn'].toString())?.toLocal(),
  );

  final int id;
  final String estado;

  /// Activa y sin vencer: lo unico que habilita "Destacar".
  final bool vigente;
  final String planNombre;
  final DateTime? venceEn;

  /// Dias que le quedan (0 = vence hoy), o null si no tiene fecha.
  int? diasRestantes(DateTime ahora) {
    final DateTime? fin = venceEn;
    if (fin == null) return null;
    final int dias = fin.difference(ahora).inDays;
    return dias < 0 ? 0 : dias;
  }
}

/// Planes y suscripcion del patrocinio (ADM-09A): la persona los consulta y
/// pide uno; el equipo lo aprueba o rechaza desde el panel de admin.
class PlanApi {
  PlanApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Los planes que se pueden pedir desde [pais] (codigo ISO de dos letras).
  Future<List<PlanPatrocinio>> planes(String pais) async {
    final dynamic data = await _client.get('/patrocinio/planes?pais=$pais');
    return ((data as Map<String, dynamic>)['planes'] as List<dynamic>)
        .map((dynamic e) => PlanPatrocinio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// La suscripcion mas reciente, o null si nunca pidio una.
  Future<MiSuscripcion?> miSuscripcion() async {
    final dynamic data = await _client.get('/patrocinio/suscripciones/mia');
    if (data == null || data is! Map<String, dynamic>) return null;
    return MiSuscripcion.fromJson(data);
  }

  /// Pide el plan [planId]. Lanza [ApiException] 409 si ya tiene una solicitud
  /// pendiente o un plan activo.
  Future<void> solicitar({required int planId, required String pais}) async {
    await _client.post('/patrocinio/suscripciones', <String, Object?>{
      'planId': planId,
      'pais': pais,
    });
  }
}
