import 'package:sqflite/sqflite.dart';

import 'package:fit_quest_go/core/db/app_database.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

/// Sesion de grabacion GPS interrumpida, recuperada de SQLite.
class SesionTrackingGuardada {
  const SesionTrackingGuardada({
    required this.segundos,
    required this.distanciaKm,
    required this.puntos,
  });

  final int segundos;
  final double distanciaKm;
  final List<PuntoRuta> puntos;
}

/// Buffer de la grabacion GPS en curso: sobrevive a un cierre/crash de la app.
/// Todos los metodos son tolerantes a fallos: nunca deben romper la grabacion.
class TrackingDao {
  TrackingDao([AppDatabase? db]) : _db = db ?? AppDatabase.instancia;

  final AppDatabase _db;

  Future<void> iniciarSesion() async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return;
      await db.delete('puntos_tracking_temp');
      await _guardarEstado(db, 'grabando', 0, 0);
    } catch (_) {}
  }

  Future<void> agregarPunto(
    PuntoRuta punto,
    int orden, {
    required int segundos,
    required double distanciaKm,
  }) async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return;
      await db.insert('puntos_tracking_temp', <String, Object?>{
        'lat': punto.lat,
        'lng': punto.lng,
        'orden': orden,
        'registrado_en': DateTime.now().toIso8601String(),
      });
      await _guardarEstado(db, 'grabando', segundos, distanciaKm);
    } catch (_) {}
  }

  Future<void> _guardarEstado(
    Database db,
    String estado,
    int segundos,
    double distanciaKm,
  ) {
    return db.insert('sesion_tracking_temp', <String, Object?>{
      'id': 1,
      'modo': 'gps',
      'segundos_transcurridos': segundos,
      'distancia_km': distanciaKm,
      'estado': estado,
      'actualizado_en': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Sesion pendiente de resolver (null si no hay o tiene menos de 2 puntos).
  Future<SesionTrackingGuardada?> recuperar() async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return null;
      final List<Map<String, Object?>> s = await db.query('sesion_tracking_temp');
      if (s.isEmpty) return null;
      final List<Map<String, Object?>> pts = await db.query(
        'puntos_tracking_temp',
        orderBy: 'orden ASC',
      );
      if (pts.length < 2) return null;
      return SesionTrackingGuardada(
        segundos: (s.first['segundos_transcurridos'] as num).toInt(),
        distanciaKm: (s.first['distancia_km'] as num).toDouble(),
        puntos: <PuntoRuta>[
          for (final Map<String, Object?> r in pts)
            PuntoRuta(
              lat: (r['lat'] as num).toDouble(),
              lng: (r['lng'] as num).toDouble(),
            ),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> limpiar() async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return;
      await db.delete('puntos_tracking_temp');
      await db.delete('sesion_tracking_temp');
    } catch (_) {}
  }
}
