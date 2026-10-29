import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/db/daos/sync_rutas_dao.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';

/// Sube al backend las rutas que se guardaron sin conexion (cola outbox).
class SyncRutasService {
  SyncRutasService({RutaApi? api, SyncRutasDao? dao})
    : _api = api ?? RutaApi(),
      _dao = dao ?? SyncRutasDao();

  /// Instancia compartida: evita que dos pantallas suban la misma ruta a la vez.
  static final SyncRutasService instancia = SyncRutasService();

  final RutaApi _api;
  final SyncRutasDao _dao;
  bool _enCurso = false;

  Future<int> pendientes() => _dao.conteo();

  /// Intenta subir todas las pendientes en orden. Devuelve cuantas se subieron.
  /// Si falla la red se detiene (las demas se reintentaran luego); si el
  /// servidor rechaza una, queda marcada con error y se sigue con la siguiente.
  Future<int> sincronizar() async {
    if (_enCurso) return 0;
    _enCurso = true;
    int subidas = 0;
    try {
      for (final RutaPendiente r in await _dao.pendientes()) {
        try {
          await _api.crear(
            nombre: r.nombre,
            actividades: r.actividades,
            dificultad: r.dificultad,
            distanciaKm: r.distanciaKm,
            puntos: r.puntos,
            visibilidad: r.visibilidad,
          );
          await _dao.eliminar(r.idLocal);
          subidas++;
        } on ApiException catch (e) {
          await _dao.registrarError(r.idLocal, e.message);
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
