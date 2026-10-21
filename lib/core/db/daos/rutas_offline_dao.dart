import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:fit_quest_go/core/db/app_database.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

/// Rutas descargadas por el usuario para consultarlas sin conexion.
class RutasOfflineDao {
  RutasOfflineDao([AppDatabase? db]) : _db = db ?? AppDatabase.instancia;

  final AppDatabase _db;

  Future<bool> guardar(Ruta ruta) async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return false;
      await db.insert('rutas_offline', <String, Object?>{
        'id_remoto': ruta.id,
        'nombre': ruta.nombre,
        'actividades_json': jsonEncode(ruta.actividades),
        'dificultad': ruta.dificultad,
        'distancia_km': ruta.distanciaKm,
        'puntos_json': jsonEncode(<Map<String, double>>[
          for (final PuntoRuta p in ruta.puntos) <String, double>{'lat': p.lat, 'lng': p.lng},
        ]),
        'estado': ruta.estado,
        'descargado_en': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Ruta>> listar() async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return <Ruta>[];
      final List<Map<String, Object?>> filas = await db.query(
        'rutas_offline',
        orderBy: 'descargado_en DESC',
      );
      return <Ruta>[
        for (final Map<String, Object?> f in filas)
          Ruta(
            id: f['id_remoto'] as int,
            nombre: f['nombre'] as String,
            actividades: (jsonDecode(f['actividades_json'] as String) as List<dynamic>)
                .map((dynamic e) => e.toString())
                .toList(),
            dificultad: (f['dificultad'] as String?) ?? 'moderada',
            distanciaKm: (f['distancia_km'] as num).toDouble(),
            puntos: (jsonDecode(f['puntos_json'] as String) as List<dynamic>)
                .map((dynamic e) => PuntoRuta.fromJson(e as Map<String, dynamic>))
                .toList(),
            estado: (f['estado'] as String?) ?? '',
          ),
      ];
    } catch (_) {
      return <Ruta>[];
    }
  }

  Future<bool> estaGuardada(int idRemoto) async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return false;
      final List<Map<String, Object?>> r = await db.query(
        'rutas_offline',
        columns: <String>['id_remoto'],
        where: 'id_remoto = ?',
        whereArgs: <Object?>[idRemoto],
      );
      return r.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> eliminar(int idRemoto) async {
    try {
      final Database? db = await _db.abrir();
      await db?.delete(
        'rutas_offline',
        where: 'id_remoto = ?',
        whereArgs: <Object?>[idRemoto],
      );
    } catch (_) {}
  }
}
