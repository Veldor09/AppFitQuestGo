import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos SQLite local de la app (soporte offline). El backend sigue
/// siendo la fuente de la verdad; aqui solo viven buffers, colas y cachés.
///
/// Si SQLite no esta disponible (p. ej. en `flutter test` sin plataforma),
/// [abrir] devuelve null y los DAOs degradan sin romper la app.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instancia = AppDatabase._();

  static const String _nombre = 'fitquestgo_local.db';
  static const int _version = 2;

  Database? _db;
  Future<Database?>? _abriendo;

  /// Abre (una sola vez) la base. Null si la plataforma no soporta SQLite.
  Future<Database?> abrir() {
    if (_db != null) return Future<Database?>.value(_db);
    return _abriendo ??= _abrir();
  }

  Future<Database?> _abrir() async {
    try {
      final String ruta = p.join(await getDatabasesPath(), _nombre);
      _db = await openDatabase(
        ruta,
        version: _version,
        onCreate: (Database db, int version) async {
          for (final String sql in _ddl) {
            await db.execute(sql);
          }
        },
        onUpgrade: (Database db, int anterior, int nueva) async {
          // v2: recorridos de rutas terminados, pendientes de subir.
          if (anterior < 2) await db.execute(_ddlActividadesPendientes);
        },
      );
      return _db;
    } catch (_) {
      _abriendo = null;
      return null;
    }
  }

  /// Borra los datos del usuario (al cerrar sesion) para no filtrar cuentas.
  Future<void> limpiarDatosUsuario() async {
    final Database? db = await abrir();
    if (db == null) return;
    for (final String t in <String>[
      'puntos_tracking_temp',
      'sesion_tracking_temp',
      'rutas_pendientes_sync',
      'actividades_pendientes_sync',
      'rutas_offline',
      'perfil_cache',
    ]) {
      await db.delete(t);
    }
  }

  static const String _ddlActividadesPendientes = '''
CREATE TABLE actividades_pendientes_sync (
  id_local INTEGER PRIMARY KEY AUTOINCREMENT,
  id_ruta INTEGER NOT NULL,
  distancia_km REAL NOT NULL,
  duracion_segundos INTEGER NOT NULL,
  iniciado_en TEXT NOT NULL,
  finalizado_en TEXT NOT NULL,
  puntos_json TEXT NOT NULL,
  estado_sync TEXT NOT NULL DEFAULT 'pendiente',
  intentos INTEGER NOT NULL DEFAULT 0,
  ultimo_error TEXT
)''';

  static const List<String> _ddl = <String>[
    _ddlActividadesPendientes,
    '''
CREATE TABLE sesion_tracking_temp (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  modo TEXT NOT NULL,
  segundos_transcurridos INTEGER NOT NULL DEFAULT 0,
  distancia_km REAL NOT NULL DEFAULT 0.0,
  estado TEXT NOT NULL,
  actualizado_en TEXT NOT NULL
)''',
    '''
CREATE TABLE puntos_tracking_temp (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  orden INTEGER NOT NULL,
  registrado_en TEXT NOT NULL
)''',
    '''
CREATE TABLE rutas_pendientes_sync (
  id_local INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  actividades_json TEXT NOT NULL,
  dificultad TEXT,
  distancia_km REAL NOT NULL,
  puntos_json TEXT NOT NULL,
  visibilidad TEXT NOT NULL,
  creado_en TEXT NOT NULL,
  estado_sync TEXT NOT NULL DEFAULT 'pendiente',
  intentos INTEGER NOT NULL DEFAULT 0,
  ultimo_error TEXT
)''',
    '''
CREATE TABLE rutas_offline (
  id_remoto INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL,
  actividades_json TEXT NOT NULL,
  dificultad TEXT,
  distancia_km REAL NOT NULL,
  puntos_json TEXT NOT NULL,
  estado TEXT NOT NULL DEFAULT '',
  descargado_en TEXT NOT NULL
)''',
    '''
CREATE TABLE perfil_cache (
  id_usuario INTEGER PRIMARY KEY,
  nombre_user TEXT NOT NULL,
  email_user TEXT NOT NULL,
  km_recorridos REAL NOT NULL DEFAULT 0.0,
  rutas_completadas INTEGER NOT NULL DEFAULT 0,
  insignias INTEGER NOT NULL DEFAULT 0,
  actualizado_en TEXT NOT NULL
)''',
  ];
}
