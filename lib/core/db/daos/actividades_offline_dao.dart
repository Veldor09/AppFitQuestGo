import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:fit_quest_go/core/db/app_database.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

/// Recorrido de una ruta terminado, a la espera de subirse al backend.
class ActividadPendiente {
  const ActividadPendiente({
    required this.idLocal,
    required this.idRuta,
    required this.distanciaKm,
    required this.duracionSegundos,
    required this.iniciadoEn,
    required this.finalizadoEn,
    required this.puntos,
  });

  final int idLocal;
  final int idRuta;
  final double distanciaKm;
  final int duracionSegundos;
  final DateTime iniciadoEn;
  final DateTime finalizadoEn;

  /// Trazo realmente recorrido (GPS).
  final List<PuntoRuta> puntos;
}

/// Cola outbox de recorridos por sincronizar.
class ActividadesOfflineDao {
  ActividadesOfflineDao([AppDatabase? db]) : _db = db ?? AppDatabase.instancia;

  final AppDatabase _db;

  /// Devuelve el id local, o null si no se pudo guardar.
  Future<int?> encolar({
    required int idRuta,
    required double distanciaKm,
    required int duracionSegundos,
    required DateTime iniciadoEn,
    required DateTime finalizadoEn,
    required List<PuntoRuta> puntos,
  }) async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return null;
      return await db.insert('actividades_pendientes_sync', <String, Object?>{
        'id_ruta': idRuta,
        'distancia_km': distanciaKm,
        'duracion_segundos': duracionSegundos,
        'iniciado_en': iniciadoEn.toIso8601String(),
        'finalizado_en': finalizadoEn.toIso8601String(),
        'puntos_json': jsonEncode(<Map<String, double>>[
          for (final PuntoRuta p in puntos) <String, double>{'lat': p.lat, 'lng': p.lng},
        ]),
      });
    } catch (_) {
      return null;
    }
  }

  Future<List<ActividadPendiente>> pendientes() async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return <ActividadPendiente>[];
      final List<Map<String, Object?>> filas = await db.query(
        'actividades_pendientes_sync',
        orderBy: 'id_local ASC',
      );
      return <ActividadPendiente>[
        for (final Map<String, Object?> f in filas)
          ActividadPendiente(
            idLocal: f['id_local'] as int,
            idRuta: f['id_ruta'] as int,
            distanciaKm: (f['distancia_km'] as num).toDouble(),
            duracionSegundos: (f['duracion_segundos'] as num).toInt(),
            iniciadoEn: DateTime.parse(f['iniciado_en'] as String),
            finalizadoEn: DateTime.parse(f['finalizado_en'] as String),
            puntos: (jsonDecode(f['puntos_json'] as String) as List<dynamic>)
                .map((dynamic e) => PuntoRuta.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
      ];
    } catch (_) {
      return <ActividadPendiente>[];
    }
  }

  Future<int> conteo() async => (await pendientes()).length;

  Future<void> eliminar(int idLocal) async {
    try {
      final Database? db = await _db.abrir();
      await db?.delete(
        'actividades_pendientes_sync',
        where: 'id_local = ?',
        whereArgs: <Object?>[idLocal],
      );
    } catch (_) {}
  }

  Future<void> registrarError(int idLocal, String error) async {
    try {
      final Database? db = await _db.abrir();
      await db?.rawUpdate(
        "UPDATE actividades_pendientes_sync SET intentos = intentos + 1, "
        "estado_sync = 'error', ultimo_error = ? WHERE id_local = ?",
        <Object?>[error, idLocal],
      );
    } catch (_) {}
  }
}
