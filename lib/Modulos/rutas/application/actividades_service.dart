import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/db/daos/actividades_offline_dao.dart';
import 'package:fit_quest_go/core/db/daos/perfil_cache_dao.dart';
import 'package:fit_quest_go/Modulos/rutas/data/actividad_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

enum ResultadoRecorrido {
  /// Subido al servidor.
  subido,

  /// Sin conexion: guardado en el telefono, se subira solo mas tarde.
  guardadoLocal,

  /// El servidor lo rechazo (datos invalidos); no se reintenta.
  rechazado,

  /// No se pudo ni subir ni guardar localmente.
  fallo,
}

/// Registra un recorrido terminado (online u offline) y sube los pendientes.
class ActividadesService {
  ActividadesService({
    ActividadApi? api,
    ActividadesOfflineDao? dao,
    PerfilCacheDao? perfilCache,
  }) : _api = api ?? ActividadApi(),
       _dao = dao ?? ActividadesOfflineDao(),
       _perfilCache = perfilCache ?? PerfilCacheDao();

  /// Instancia compartida: evita subidas duplicadas simultaneas.
  static final ActividadesService instancia = ActividadesService();

  final ActividadApi _api;
  final ActividadesOfflineDao _dao;
  final PerfilCacheDao _perfilCache;
  bool _enCurso = false;

  Future<int> pendientes() => _dao.conteo();

  /// Intenta subir el recorrido; si no hay red lo deja en la cola local y suma
  /// los km al cache del perfil para que se vean de inmediato.
  Future<ResultadoRecorrido> registrar({
    required int idUsuario,
    required int idRuta,
    required double distanciaKm,
    required int duracionSegundos,
    required DateTime iniciadoEn,
    required DateTime finalizadoEn,
    required List<PuntoRuta> puntos,
  }) async {
    try {
      await _api.registrarRecorrido(
        idRuta: idRuta,
        distanciaKm: distanciaKm,
        duracionSegundos: duracionSegundos,
        iniciadoEn: iniciadoEn,
        finalizadoEn: finalizadoEn,
        puntos: puntos,
      );
      return ResultadoRecorrido.subido;
    } on ApiException {
      return ResultadoRecorrido.rechazado;
    } catch (_) {
      final int? id = await _dao.encolar(
        idRuta: idRuta,
        distanciaKm: distanciaKm,
        duracionSegundos: duracionSegundos,
        iniciadoEn: iniciadoEn,
        finalizadoEn: finalizadoEn,
        puntos: puntos,
      );
      if (id == null) return ResultadoRecorrido.fallo;
      await _perfilCache.sumarRecorrido(idUsuario, distanciaKm);
      return ResultadoRecorrido.guardadoLocal;
    }
  }

  /// Sube los recorridos pendientes en orden. Devuelve cuantos se subieron.
  /// Sin red se detiene; si el servidor rechaza uno, queda marcado con error.
  Future<int> sincronizar() async {
    if (_enCurso) return 0;
    _enCurso = true;
    int subidas = 0;
    try {
      for (final ActividadPendiente a in await _dao.pendientes()) {
        try {
          await _api.registrarRecorrido(
            idRuta: a.idRuta,
            distanciaKm: a.distanciaKm,
            duracionSegundos: a.duracionSegundos,
            iniciadoEn: a.iniciadoEn,
            finalizadoEn: a.finalizadoEn,
            puntos: a.puntos,
          );
          await _dao.eliminar(a.idLocal);
          subidas++;
        } on ApiException catch (e) {
          await _dao.registrarError(a.idLocal, e.message);
        } catch (_) {
          break; // sin red: reintentar mas tarde
        }
      }
    } finally {
      _enCurso = false;
    }
    return subidas;
  }
}
