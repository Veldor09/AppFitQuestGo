import 'package:fit_quest_go/core/api/api_client.dart';

/// A quien va dirigido un plan.
class AudienciaPlan {
  const AudienciaPlan._();
  static const String empresa = 'empresa';
  static const String usuario = 'usuario';
}

/// Como se paga: SINPE Movil en Costa Rica; PayPal en el resto (aun no esta
/// configurado, asi que todavia no se puede solicitar fuera de Costa Rica).
class MetodoPago {
  const MetodoPago._();
  static const String sinpe = 'sinpe';
  static const String paypal = 'paypal';
}

/// Un plan con el precio que le toca a quien lo pide (la moneda depende del
/// pais; no hay conversion).
class PlanPatrocinio {
  const PlanPatrocinio({
    required this.id,
    required this.nombre,
    required this.duracionDias,
    required this.moneda,
    required this.importe,
    this.audiencia = AudienciaPlan.empresa,
  });

  factory PlanPatrocinio.fromJson(Map<String, dynamic> json) => PlanPatrocinio(
    id: (json['id'] as num).toInt(),
    nombre: json['nombre'] as String,
    duracionDias: (json['duracionDias'] as num).toInt(),
    moneda: json['moneda'] as String,
    // El servidor manda el importe como texto decimal ("10000.00").
    importe: num.parse(json['importe'].toString()),
    audiencia: (json['audiencia'] as String?) ?? AudienciaPlan.empresa,
  );

  final int id;
  final String nombre;
  final int duracionDias;
  final String moneda;
  final num importe;
  final String audiencia;
}

/// Los planes que se pueden pedir desde un pais y como se paga ahi.
class RespuestaPlanes {
  const RespuestaPlanes({
    required this.planes,
    this.metodoPago = MetodoPago.sinpe,
    this.pagoDisponible = true,
    this.sinpeNumero,
  });

  factory RespuestaPlanes.fromJson(Map<String, dynamic> json) =>
      RespuestaPlanes(
        planes: ((json['planes'] as List<dynamic>?) ?? <dynamic>[])
            .map(
              (dynamic e) => PlanPatrocinio.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        metodoPago: (json['metodoPago'] as String?) ?? MetodoPago.sinpe,
        pagoDisponible: json['pagoDisponible'] != false,
        sinpeNumero: json['sinpeNumero'] as String?,
      );

  final List<PlanPatrocinio> planes;
  final String metodoPago;

  /// `false` fuera de Costa Rica mientras PayPal no este configurado.
  final bool pagoDisponible;

  /// Numero que recibe el SINPE Movil y los comprobantes.
  final String? sinpeNumero;
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
    this.numeroSolicitud,
    this.monto,
    this.moneda,
    this.metodoPago,
    this.sinpeNumero,
    this.audiencia,
  });

  factory MiSuscripcion.fromJson(Map<String, dynamic> json) => MiSuscripcion(
    id: (json['id'] as num).toInt(),
    estado: json['estado'] as String,
    vigente: json['vigente'] == true,
    planNombre: (json['planNombre'] as String?) ?? '',
    venceEn: json['venceEn'] == null
        ? null
        : DateTime.tryParse(json['venceEn'].toString())?.toLocal(),
    numeroSolicitud: json['numeroSolicitud'] as String?,
    monto: json['monto'] == null ? null : num.tryParse('${json['monto']}'),
    moneda: json['moneda'] as String?,
    metodoPago: json['metodoPago'] as String?,
    sinpeNumero: json['sinpeNumero'] as String?,
    audiencia: json['audiencia'] as String?,
  );

  final int id;
  final String estado;

  /// Activa y sin vencer: lo unico que habilita "Destacar" o las descargas extra.
  final bool vigente;
  final String planNombre;
  final DateTime? venceEn;

  /// Numero de 6 digitos que va en el detalle del SINPE Movil.
  final String? numeroSolicitud;

  /// Lo que hay que transferir, en [moneda].
  final num? monto;
  final String? moneda;
  final String? metodoPago;
  final String? sinpeNumero;
  final String? audiencia;

  /// Dias que le quedan (0 = vence hoy), o null si no tiene fecha.
  int? diasRestantes(DateTime ahora) {
    final DateTime? fin = venceEn;
    if (fin == null) return null;
    final int dias = fin.difference(ahora).inDays;
    return dias < 0 ? 0 : dias;
  }
}

/// Lo que devuelve el servidor al pedir un plan.
class SolicitudCreada {
  const SolicitudCreada({
    required this.numeroSolicitud,
    required this.monto,
    required this.moneda,
    required this.sinpeNumero,
  });

  factory SolicitudCreada.fromJson(Map<String, dynamic> json) =>
      SolicitudCreada(
        numeroSolicitud: (json['numeroSolicitud'] as String?) ?? '',
        monto: num.tryParse('${json['monto']}') ?? 0,
        moneda: (json['moneda'] as String?) ?? 'CRC',
        sinpeNumero: (json['sinpeNumero'] as String?) ?? '',
      );

  final String numeroSolicitud;
  final num monto;
  final String moneda;
  final String sinpeNumero;
}

/// Planes y suscripcion (ADM-09A): la persona los consulta y pide uno; el
/// equipo lo activa o rechaza desde "Gestion de suscripciones".
class PlanApi {
  PlanApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Los planes de su tipo de cuenta que se pueden pedir desde [pais]
  /// (codigo ISO de dos letras).
  Future<RespuestaPlanes> planes(String pais) async {
    final dynamic data = await _client.get('/patrocinio/planes?pais=$pais');
    return RespuestaPlanes.fromJson(data as Map<String, dynamic>);
  }

  /// La suscripcion mas reciente, o null si nunca pidio una.
  Future<MiSuscripcion?> miSuscripcion() async {
    final dynamic data = await _client.get('/patrocinio/suscripciones/mia');
    if (data == null || data is! Map<String, dynamic>) return null;
    return MiSuscripcion.fromJson(data);
  }

  /// Pide el plan [planId]. Lanza [ApiException] 409 si ya tiene una solicitud
  /// pendiente o un plan activo, 400 `PAGO_NO_DISPONIBLE` fuera de Costa Rica
  /// y 403 `PLAN_NO_APLICA` si el plan es de otro tipo de cuenta.
  Future<SolicitudCreada> solicitar({
    required int planId,
    required String pais,
  }) async {
    final dynamic data = await _client.post(
      '/patrocinio/suscripciones',
      <String, Object?>{'planId': planId, 'pais': pais},
    );
    return SolicitudCreada.fromJson(data as Map<String, dynamic>);
  }
}
