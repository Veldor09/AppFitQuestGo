import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:fit_quest_go/core/db/app_database.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

/// Ruta terminada sin conexion, a la espera de subirse al backend.
class RutaPendiente {
  const RutaPendiente({
    required this.idLocal,
    required this.nombre,
    required this.actividades,
    required this.dificultad,
    required this.distanciaKm,
    required this.puntos,
    required this.visibilidad,
  });

  final int idLocal;
  final String nombre;
  final List<String> actividades;
  final String? dificultad;
  final double distanciaKm;
  final List<PuntoRuta> puntos;
  final String visibilidad;
}

/// Cola outbox de rutas por sincronizar.
class SyncRutasDao {
  SyncRutasDao([AppDatabase? db]) : _db = db ?? AppDatabase.instancia;

  final AppDatabase _db;

  /// Devuelve el id local, o null si no se pudo guardar.
  Future<int?> encolar({
    required String nombre,
    required List<String> actividades,
    required String? dificultad,
    required double distanciaKm,
    required List<PuntoRuta> puntos,
    required String visibilidad,
  }) async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return null;
      return await db.insert('rutas_pendientes_sync', <String, Object?>{
        'nombre': nombre,
        'actividades_json': jsonEncode(actividades),
        'dificultad': dificultad,
        'distancia_km': distanciaKm,
        'puntos_json': jsonEncode(<Map<String, double>>[
          for (final PuntoRuta p in puntos) <String, double>{'lat': p.lat, 'lng': p.lng},
        ]),
        'visibilidad': visibilidad,
        'creado_en': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      return null;
    }
  }

  Future<List<RutaPendiente>> pendientes() async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return <RutaPendiente>[];
      final List<Map<String, Object?>> filas = await db.query(
        'rutas_pendientes_sync',
        orderBy: 'id_local ASC',
      );
      return <RutaPendiente>[
        for (final Map<String, Object?> f in filas)
          RutaPendiente(
            idLocal: f['id_local'] as int,
            nombre: f['nombre'] as String,
            actividades: (jsonDecode(f['actividades_json'] as String) as List<dynamic>)
                .map((dynamic e) => e.toString())
                .toList(),
            dificultad: f['dificultad'] as String?,
            distanciaKm: (f['distancia_km'] as num).toDouble(),
            puntos: (jsonDecode(f['puntos_json'] as String) as List<dynamic>)
                .map((dynamic e) => PuntoRuta.fromJson(e as Map<String, dynamic>))
                .toList(),
            visibilidad: f['visibilidad'] as String,
          ),
      ];
    } catch (_) {
      return <RutaPendiente>[];
    }
  }

  Future<int> conteo() async => (await pendientes()).length;

  Future<void> eliminar(int idLocal) async {
    try {
      final Database? db = await _db.abrir();
      await db?.delete(
        'rutas_pendientes_sync',
        where: 'id_local = ?',
        whereArgs: <Object?>[idLocal],
      );
    } catch (_) {}
  }

  Future<void> registrarError(int idLocal, String error) async {
    try {
      final Database? db = await _db.abrir();
      await db?.rawUpdate(
        "UPDATE rutas_pendientes_sync SET intentos = intentos + 1, "
        "estado_sync = 'error', ultimo_error = ? WHERE id_local = ?",
        <Object?>[error, idLocal],
      );
    } catch (_) {}
  }
}
