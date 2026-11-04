import 'package:fit_quest_go/core/mapa/mapas_offline_servicio.dart';
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

  /// Devuelve los IDs de las rutas guardadas ordenadas desde la primera que se agregó.
  Future<List<int>> listarIdsCronologicos() async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return <int>[];
      final List<Map<String, Object?>> filas = await db.query(
        'rutas_offline',
        columns: <String>['id_remoto'],
        orderBy: 'descargado_en ASC, rowid ASC',
      );
      return <int>[
        for (final Map<String, Object?> f in filas) f['id_remoto'] as int,
      ];
    } catch (_) {
      return <int>[];
    }
  }

  /// Ajusta las rutas guardadas al límite permitido (ej. 1 al expirar/cancelar suscripción).
  /// Conserva la primera ruta que se agregó y elimina el exceso tanto de SQLite como de Mapbox.
  Future<List<int>> recortarAlLimite(
    int limite, {
    MapasOfflineServicio? mapas,
  }) async {
    try {
      final List<int> ids = await listarIdsCronologicos();
      if (ids.length <= limite) return <int>[];

      final List<int> aEliminar = ids.sublist(limite);
      final Database? db = await _db.abrir();
      final MapasOfflineServicio servicioMapas =
          mapas ?? MapasOfflineServicio.instancia;

      for (final int id in aEliminar) {
        await db?.delete(
          'rutas_offline',
          where: 'id_remoto = ?',
          whereArgs: <Object?>[id],
        );
        try {
          await servicioMapas.eliminarZonaDeRuta(id);
        } catch (_) {}
      }
      return aEliminar;
    } catch (_) {
      return <int>[];
    }
  }

  /// Devuelve los IDs de las rutas que deben mostrarse bloqueadas por no tener suscripción
  /// activa (se permite únicamente la primera ruta agregada; el resto queda con candado).
  Future<Set<int>> idsBloqueadas({bool tieneSuscripcion = false, int limiteGratis = 1}) async {
    if (tieneSuscripcion) return <int>{};
    final List<int> ids = await listarIdsCronologicos();
    if (ids.length <= limiteGratis) return <int>{};
    return ids.sublist(limiteGratis).toSet();
  }
}
