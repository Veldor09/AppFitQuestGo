import 'package:fit_quest_go/core/api/api_client.dart';

/// A quien va dirigido un plan.
class AudienciaPlan {
  const AudienciaPlan._();
  static const String empresa = 'empresa';
  static const String usuario = 'usuario';
}

/// Como se paga: por ONVO (tarjeta o SINPE Movil) en Costa Rica; PayPal en el
/// resto (aun no esta configurado, asi que todavia no se puede pagar fuera de
/// Costa Rica).
class MetodoPago {
  const MetodoPago._();
  static const String onvo = 'onvo';
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
    this.metodoPago = MetodoPago.onvo,
    this.pagoDisponible = true,
  });

  factory RespuestaPlanes.fromJson(Map<String, dynamic> json) =>
      RespuestaPlanes(
        planes: ((json['planes'] as List<dynamic>?) ?? <dynamic>[])
            .map(
              (dynamic e) => PlanPatrocinio.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
        metodoPago: (json['metodoPago'] as String?) ?? MetodoPago.onvo,
        pagoDisponible: json['pagoDisponible'] != false,
      );

  final List<PlanPatrocinio> planes;
  final String metodoPago;

  /// `false` fuera de Costa Rica mientras PayPal no este configurado (o si el
  /// servidor aun no tiene las llaves de ONVO).
  final bool pagoDisponible;
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
    this.pagoEnLinea = false,
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
    pagoEnLinea: json['pagoEnLinea'] == true,
    audiencia: json['audiencia'] as String?,
  );

  final int id;
  final String estado;

  /// Activa y sin vencer: lo unico que habilita "Destacar" o las descargas extra.
  final bool vigente;
  final String planNombre;
  final DateTime? venceEn;

  /// Numero de 6 digitos que identifica la solicitud (tambien lo ve el admin).
  final String? numeroSolicitud;

  /// Lo que cuesta el plan, en [moneda].
  final num? monto;
  final String? moneda;

  /// Se pidio pagando en linea: si sigue `Solicitada`, el pago no se completo.
  /// Una solicitud sin esto es una de las de SINPE manual de antes, que el
  /// equipo revisa a mano.
  final bool pagoEnLinea;
  final String? audiencia;

  /// Dias que le quedan (0 = vence hoy), o null si no tiene fecha.
  int? diasRestantes(DateTime ahora) {
    final DateTime? fin = venceEn;
    if (fin == null) return null;
    final int dias = fin.difference(ahora).inDays;
    return dias < 0 ? 0 : dias;
  }
}

/// Lo que devuelve el servidor al empezar un pago.
class PagoIniciado {
  const PagoIniciado({
    required this.suscripcionId,
    required this.numeroSolicitud,
    required this.url,
  });

  factory PagoIniciado.fromJson(Map<String, dynamic> json) => PagoIniciado(
    suscripcionId: (json['suscripcionId'] as num).toInt(),
    numeroSolicitud: (json['numeroSolicitud'] as String?) ?? '',
    url: json['url'] as String,
  );

  final int suscripcionId;
  final String numeroSolicitud;

  /// La pantalla de pago de ONVO.
  final String url;
}

/// Planes y suscripcion (ADM-09A): la persona los consulta y paga uno; el plan
/// se activa solo al confirmarse el pago. "Gestion de suscripciones" (admin)
/// puede ademas aprobar, rechazar o suspender.
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

  /// Empieza el pago del plan [planId] y devuelve la URL de la pantalla de pago.
  /// El plan se activa solo cuando el pago se confirma. Lanza [ApiException] 409
  /// si ya tiene una solicitud pendiente o un plan activo, 400
  /// `PAGO_NO_DISPONIBLE` fuera de Costa Rica (o sin llaves de ONVO), 403
  /// `PLAN_NO_APLICA` si el plan es de otro tipo de cuenta y 503 si ONVO fallo.
  Future<PagoIniciado> iniciarPago({
    required int planId,
    required String pais,
  }) async {
    final dynamic data = await _client.post(
      '/patrocinio/suscripciones/pagar',
      <String, Object?>{'planId': planId, 'pais': pais},
    );
    return PagoIniciado.fromJson(data as Map<String, dynamic>);
  }
}
