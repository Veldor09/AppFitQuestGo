import 'package:sqflite/sqflite.dart';

import 'package:fit_quest_go/Modulos/perfil/data/notificacion.dart';
import 'package:fit_quest_go/core/db/app_database.dart';

/// DAO para persistir y consultar las notificaciones en SQLite
/// cuando el usuario no tiene conexión a internet.
class NotificacionesCacheDao {
  NotificacionesCacheDao([AppDatabase? db]) : _db = db ?? AppDatabase.instancia;

  final AppDatabase _db;

  /// Guarda la lista completa de notificaciones en la caché local.
  Future<void> guardarTodas(List<Notificacion> notificaciones) async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return;
      final Batch batch = db.batch();
      batch.delete('notificaciones_cache');
      final String ahora = DateTime.now().toIso8601String();
      for (final Notificacion n in notificaciones) {
        batch.insert(
          'notificaciones_cache',
          <String, Object?>{
            'id_remoto': n.id,
            'categoria': n.categoria,
            'titulo': n.titulo,
            'mensaje': n.mensaje,
            'creada_en': n.creadaEn.toIso8601String(),
            'leida': n.leida ? 1 : 0,
            'referencia_tipo': n.referenciaTipo,
            'referencia_id': n.referenciaId,
            'guardado_en': ahora,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  /// Lista las notificaciones almacenadas, opcionalmente filtradas por categoría.
  Future<List<Notificacion>> listar({String? categoria}) async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return <Notificacion>[];
      final List<Map<String, Object?>> filas = await db.query(
        'notificaciones_cache',
        where: categoria != null && categoria != 'todas'
            ? 'categoria = ?'
            : null,
        whereArgs: categoria != null && categoria != 'todas'
            ? <Object?>[categoria]
            : null,
        orderBy: 'creada_en DESC',
      );
      return <Notificacion>[
        for (final Map<String, Object?> f in filas)
          Notificacion(
            id: (f['id_remoto'] as num).toInt(),
            categoria: (f['categoria'] as String?) ?? 'eventos',
            titulo: (f['titulo'] as String?) ?? '',
            mensaje: (f['mensaje'] as String?) ?? '',
            creadaEn: DateTime.tryParse((f['creada_en'] ?? '').toString())
                    ?.toLocal() ??
                DateTime.now(),
            leida: (f['leida'] as num?) == 1,
            referenciaTipo: f['referencia_tipo'] as String?,
            referenciaId: (f['referencia_id'] as num?)?.toInt(),
          ),
      ];
    } catch (_) {
      return <Notificacion>[];
    }
  }

  /// Devuelve el número de notificaciones no leídas en caché local.
  Future<int> conteoNoLeidas() async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return 0;
      final List<Map<String, Object?>> r = await db.rawQuery(
        'SELECT COUNT(*) as total FROM notificaciones_cache WHERE leida = 0',
      );
      if (r.isEmpty) return 0;
      return (r.first['total'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Marca una notificación como leída en la caché local.
  Future<void> marcarLeida(int idRemoto) async {
    try {
      final Database? db = await _db.abrir();
      await db?.update(
        'notificaciones_cache',
        <String, Object?>{'leida': 1},
        where: 'id_remoto = ?',
        whereArgs: <Object?>[idRemoto],
      );
    } catch (_) {}
  }

  /// Marca todas las notificaciones como leídas en la caché local.
  Future<void> marcarTodasLeidas() async {
    try {
      final Database? db = await _db.abrir();
      await db?.update(
        'notificaciones_cache',
        <String, Object?>{'leida': 1},
      );
    } catch (_) {}
  }

  /// Elimina una notificación de la caché local.
  Future<void> eliminar(int idRemoto) async {
    try {
      final Database? db = await _db.abrir();
      await db?.delete(
        'notificaciones_cache',
        where: 'id_remoto = ?',
        whereArgs: <Object?>[idRemoto],
      );
    } catch (_) {}
  }
}
