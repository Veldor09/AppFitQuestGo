import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:fit_quest_go/core/db/app_database.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

/// Ultimas metricas conocidas del perfil, para pintarlas al instante.
class MetricasCache {
  const MetricasCache({
    required this.km,
    required this.rutas,
    required this.insignias,
  });

  final double km;
  final int rutas;
  final int insignias;
}

class PerfilCacheDao {
  PerfilCacheDao([AppDatabase? db]) : _db = db ?? AppDatabase.instancia;

  final AppDatabase _db;

  /// Guarda el perfil completo en SQLite para uso offline.
  Future<void> guardarUsuario(Usuario usuario) async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return;
      final List<Map<String, Object?>> exist = await db.query(
        'perfil_cache',
        where: 'id_usuario = ?',
        whereArgs: <Object?>[usuario.id],
      );
      final String jsonStr = jsonEncode(usuario.toJson());
      if (exist.isEmpty) {
        await db.insert('perfil_cache', <String, Object?>{
          'id_usuario': usuario.id,
          'nombre_user': usuario.nombreUser,
          'email_user': usuario.emailUser,
          'km_recorridos': 0.0,
          'rutas_completadas': 0,
          'insignias': 0,
          'perfil_json': jsonStr,
          'actualizado_en': DateTime.now().toIso8601String(),
        });
      } else {
        await db.update(
          'perfil_cache',
          <String, Object?>{
            'nombre_user': usuario.nombreUser,
            'email_user': usuario.emailUser,
            'perfil_json': jsonStr,
            'actualizado_en': DateTime.now().toIso8601String(),
          },
          where: 'id_usuario = ?',
          whereArgs: <Object?>[usuario.id],
        );
      }
    } catch (_) {}
  }

  /// Recupera el usuario con el ID especificado desde SQLite.
  Future<Usuario?> leerUsuario(int idUsuario) async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return null;
      final List<Map<String, Object?>> r = await db.query(
        'perfil_cache',
        where: 'id_usuario = ?',
        whereArgs: <Object?>[idUsuario],
      );
      if (r.isEmpty) return null;
      final String? jsonStr = r.first['perfil_json'] as String?;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return Usuario.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      }
      return Usuario(
        id: (r.first['id_usuario'] as num).toInt(),
        nombreUser: (r.first['nombre_user'] as String?) ?? '',
        emailUser: (r.first['email_user'] as String?) ?? '',
        idrol: 1,
      );
    } catch (_) {
      return null;
    }
  }

  /// Recupera el último perfil almacenado en la caché local.
  Future<Usuario?> leerUltimoUsuario() async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return null;
      final List<Map<String, Object?>> r = await db.query(
        'perfil_cache',
        orderBy: 'actualizado_en DESC',
        limit: 1,
      );
      if (r.isEmpty) return null;
      final String? jsonStr = r.first['perfil_json'] as String?;
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return Usuario.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      }
      return Usuario(
        id: (r.first['id_usuario'] as num).toInt(),
        nombreUser: (r.first['nombre_user'] as String?) ?? '',
        emailUser: (r.first['email_user'] as String?) ?? '',
        idrol: 1,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> guardar({
    required int idUsuario,
    required String nombreUser,
    required String emailUser,
    required double km,
    required int rutas,
    required int insignias,
  }) async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return;
      await db.insert('perfil_cache', <String, Object?>{
        'id_usuario': idUsuario,
        'nombre_user': nombreUser,
        'email_user': emailUser,
        'km_recorridos': km,
        'rutas_completadas': rutas,
        'insignias': insignias,
        'actualizado_en': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  Future<MetricasCache?> leer(int idUsuario) async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return null;
      final List<Map<String, Object?>> r = await db.query(
        'perfil_cache',
        where: 'id_usuario = ?',
        whereArgs: <Object?>[idUsuario],
      );
      if (r.isEmpty) return null;
      return MetricasCache(
        km: (r.first['km_recorridos'] as num).toDouble(),
        rutas: (r.first['rutas_completadas'] as num).toInt(),
        insignias: (r.first['insignias'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Suma un recorrido terminado sin conexion a las metricas guardadas, para
  /// que el perfil lo refleje al instante. No hace nada si aun no hay cache.
  Future<void> sumarRecorrido(int idUsuario, double km) async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return;
      await db.rawUpdate(
        'UPDATE perfil_cache SET km_recorridos = km_recorridos + ?, '
        'rutas_completadas = rutas_completadas + 1, actualizado_en = ? '
        'WHERE id_usuario = ?',
        <Object?>[km, DateTime.now().toIso8601String(), idUsuario],
      );
    } catch (_) {}
  }
}

