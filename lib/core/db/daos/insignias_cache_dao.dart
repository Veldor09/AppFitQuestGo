import 'package:sqflite/sqflite.dart';

import 'package:fit_quest_go/Modulos/perfil/data/insignia.dart';
import 'package:fit_quest_go/core/db/app_database.dart';

/// DAO para almacenar y recuperar en SQLite las insignias del usuario autenticado
/// para soporte offline cuando no hay conexión a internet.
class InsigniasCacheDao {
  InsigniasCacheDao([AppDatabase? db]) : _db = db ?? AppDatabase.instancia;

  final AppDatabase _db;

  /// Guarda la lista completa de insignias en la caché local.
  Future<void> guardarTodas(List<Insignia> insignias) async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return;
      final Batch batch = db.batch();
      batch.delete('insignias_cache');
      final String ahora = DateTime.now().toIso8601String();
      for (final Insignia i in insignias) {
        batch.insert(
          'insignias_cache',
          <String, Object?>{
            'codigo': i.codigo,
            'nombre': i.nombre,
            'descripcion': i.descripcion,
            'emoji': i.emoji,
            'desbloqueada': i.desbloqueada ? 1 : 0,
            'fecha_obtenida': i.fechaObtenida?.toIso8601String(),
            'progreso': i.progreso,
            'meta': i.meta,
            'guardado_en': ahora,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  /// Recupera todas las insignias almacenadas en SQLite.
  Future<List<Insignia>> listar() async {
    try {
      final Database? db = await _db.abrir();
      if (db == null) return <Insignia>[];
      final List<Map<String, Object?>> filas = await db.query(
        'insignias_cache',
        orderBy: 'desbloqueada DESC, codigo ASC',
      );
      return <Insignia>[
        for (final Map<String, Object?> f in filas)
          Insignia(
            codigo: (f['codigo'] as String?) ?? '',
            nombre: (f['nombre'] as String?) ?? '',
            descripcion: (f['descripcion'] as String?) ?? '',
            emoji: (f['emoji'] as String?) ?? '🏅',
            desbloqueada: (f['desbloqueada'] as num?) == 1,
            fechaObtenida: DateTime.tryParse(
              (f['fecha_obtenida'] ?? '').toString(),
            )?.toLocal(),
            progreso: (f['progreso'] as num?)?.toDouble(),
            meta: (f['meta'] as num?)?.toDouble(),
          ),
      ];
    } catch (_) {
      return <Insignia>[];
    }
  }

  /// Limpia las insignias en caché.
  Future<void> limpiar() async {
    try {
      final Database? db = await _db.abrir();
      await db?.delete('insignias_cache');
    } catch (_) {}
  }
}
