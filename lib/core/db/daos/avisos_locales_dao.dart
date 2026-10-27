import 'package:sqflite/sqflite.dart';

import 'package:fit_quest_go/core/db/app_database.dart';
import 'package:fit_quest_go/Modulos/perfil/data/avisos_locales.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificacion.dart';

/// Avisos locales en SQLite. Si la base no esta disponible degrada sin romper:
/// los avisos siguen saliendo en el mapa, solo que no quedan guardados.
class AvisosLocalesDao implements AvisosLocales {
  AvisosLocalesDao([AppDatabase? db]) : _db = db ?? AppDatabase.instancia;

  final AppDatabase _db;

  /// Los mas viejos se borran al pasar de aqui.
  static const int maximo = 100;

  /// Pasa del id de la fila al de la [Notificacion] y al reves: los locales son
  /// negativos para no chocar nunca con los del servidor.
  static int idNotificacion(int idLocal) => -idLocal;
  static int _idLocal(int idNotificacion) => -idNotificacion;

  @override
  Future<void> registrar(AvisoLocal aviso) async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return;
      await db.insert('avisos_locales', <String, Object?>{
        'clave': aviso.clave,
        'categoria': aviso.categoria,
        'titulo': aviso.titulo,
        'mensaje': aviso.mensaje,
        'creada_en': aviso.creadaEn.toIso8601String(),
        'leida': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.rawDelete(
        'DELETE FROM avisos_locales WHERE id_local NOT IN '
        '(SELECT id_local FROM avisos_locales ORDER BY creada_en DESC, id_local DESC LIMIT ?)',
        <Object?>[maximo],
      );
    } catch (_) {}
  }

  @override
  Future<List<Notificacion>> listar() async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return <Notificacion>[];
      final List<Map<String, Object?>> filas = await db.query(
        'avisos_locales',
        orderBy: 'creada_en DESC, id_local DESC',
      );
      return <Notificacion>[
        for (final Map<String, Object?> f in filas)
          Notificacion(
            id: idNotificacion((f['id_local'] as num).toInt()),
            categoria: (f['categoria'] as String?) ?? 'eventos',
            titulo: (f['titulo'] as String?) ?? '',
            mensaje: (f['mensaje'] as String?) ?? '',
            creadaEn:
                DateTime.tryParse((f['creada_en'] ?? '').toString()) ??
                DateTime.now(),
            leida: (f['leida'] as num?) == 1,
          ),
      ];
    } catch (_) {
      return <Notificacion>[];
    }
  }

  @override
  Future<int> conteoNoLeidas() async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return 0;
      final List<Map<String, Object?>> r = await db.rawQuery(
        'SELECT COUNT(*) AS total FROM avisos_locales WHERE leida = 0',
      );
      return r.isEmpty ? 0 : (r.first['total'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> marcarLeida(int id) async {
    try {
      final Database? db = await _db.abrir();
      await db?.update(
        'avisos_locales',
        <String, Object?>{'leida': 1},
        where: 'id_local = ?',
        whereArgs: <Object?>[_idLocal(id)],
      );
    } catch (_) {}
  }

  @override
  Future<void> marcarTodasLeidas() async {
    try {
      final Database? db = await _db.abrir();
      await db?.update('avisos_locales', <String, Object?>{'leida': 1});
    } catch (_) {}
  }

  @override
  Future<void> eliminar(int id) async {
    try {
      final Database? db = await _db.abrir();
      await db?.delete(
        'avisos_locales',
        where: 'id_local = ?',
        whereArgs: <Object?>[_idLocal(id)],
      );
    } catch (_) {}
  }
}
