import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:fit_quest_go/Modulos/patrocinio/data/plan_api.dart';

/// Rutas que se pueden guardar para ver sin conexion sin suscripcion.
const int kLimiteRutasOfflineGratis = 3;

/// Con una suscripcion vigente.
const int kLimiteRutasOfflineSuscrito = 15;

/// Donde se recuerda hasta cuando vale el plan: la descarga offline se decide
/// sin red, asi que no puede depender de preguntarle al servidor en ese momento.
abstract class AlmacenPlanUsuario {
  Future<DateTime?> leerVigenteHasta();
  Future<void> guardarVigenteHasta(DateTime? fecha);
}

class AlmacenPlanUsuarioSeguro implements AlmacenPlanUsuario {
  const AlmacenPlanUsuarioSeguro([
    this._almacen = const FlutterSecureStorage(aOptions: AndroidOptions()),
  ]);

  final FlutterSecureStorage _almacen;
  static const String _clave = 'plan_usuario_vigente_hasta';

  @override
  Future<DateTime?> leerVigenteHasta() async {
    try {
      final String? texto = await _almacen.read(key: _clave);
      return texto == null ? null : DateTime.tryParse(texto);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> guardarVigenteHasta(DateTime? fecha) async {
    try {
      if (fecha == null) {
        await _almacen.delete(key: _clave);
      } else {
        await _almacen.write(key: _clave, value: fecha.toIso8601String());
      }
    } catch (_) {}
  }
}

/// El plan de suscripcion de quien usa la app (el de "mas descargas offline").
/// Se consulta al servidor cuando hay red y se recuerda su vencimiento para
/// seguir valiendo sin conexion.
class PlanUsuario {
  PlanUsuario({
    PlanApi? api,
    AlmacenPlanUsuario? almacen,
    DateTime Function()? ahora,
    this.espera = const Duration(seconds: 3),
  }) : _apiInyectada = api,
       _almacen = almacen ?? const AlmacenPlanUsuarioSeguro(),
       _ahora = ahora ?? DateTime.now;

  /// El de toda la app.
  static PlanUsuario instancia = PlanUsuario();

  final PlanApi? _apiInyectada;
  PlanApi? _apiCreada;
  PlanApi get _api => _apiInyectada ?? (_apiCreada ??= PlanApi());
  final AlmacenPlanUsuario _almacen;
  final DateTime Function() _ahora;

  /// Cuanto se espera al servidor antes de quedarse con lo recordado.
  final Duration espera;

  /// Lo recordado: hay plan y no ha vencido.
  Future<bool> vigenteRecordado() async {
    final DateTime? hasta = await _almacen.leerVigenteHasta();
    return hasta != null && hasta.isAfter(_ahora());
  }

  /// Pregunta al servidor y recuerda la respuesta. Sin red (o si tarda), vale lo
  /// recordado. Una suscripcion de empresa no cuenta: esto es del plan de usuario.
  Future<bool> actualizar() async {
    try {
      return await recordar(await _api.miSuscripcion().timeout(espera));
    } catch (_) {
      return vigenteRecordado();
    }
  }

  /// Recuerda lo que el servidor dijo de la suscripcion (null = no tiene).
  /// Devuelve si hay un plan de usuario vigente.
  Future<bool> recordar(MiSuscripcion? s) async {
    final bool vale =
        s != null &&
        s.vigente &&
        s.audiencia != AudienciaPlan.empresa &&
        s.venceEn != null;
    await _almacen.guardarVigenteHasta(vale ? s.venceEn : null);
    return vale;
  }

  /// Cuantas rutas puede tener guardadas para verlas sin conexion.
  Future<int> limiteRutasOffline() async {
    return await actualizar()
        ? kLimiteRutasOfflineSuscrito
        : kLimiteRutasOfflineGratis;
  }

  /// Al cerrar sesion: el plan es de la cuenta, no del telefono.
  Future<void> olvidar() => _almacen.guardarVigenteHasta(null);
}
