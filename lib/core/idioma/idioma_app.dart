import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Los idiomas que la app sabe hablar y que la persona puede elegir.
enum IdiomaApp {
  espanol('es', Locale('es'), 'Español'),
  ingles('en', Locale('en'), 'English'),
  portugues('pt', Locale('pt', 'BR'), 'Português');

  const IdiomaApp(this.codigo, this.locale, this.nombre);

  /// Lo que se guarda en el dispositivo.
  final String codigo;
  final Locale locale;

  /// El nombre del idioma en el propio idioma: no se traduce, para que se
  /// reconozca aunque la app este en uno que la persona no entiende.
  final String nombre;

  static IdiomaApp? desdeCodigo(String? codigo) {
    for (final IdiomaApp i in IdiomaApp.values) {
      if (i.codigo == codigo) return i;
    }
    return null;
  }
}

/// Donde se guarda el idioma elegido (solo en este dispositivo).
abstract class AlmacenIdioma {
  Future<String?> leer();
  Future<void> guardar(String? codigo);
}

class AlmacenIdiomaSeguro implements AlmacenIdioma {
  const AlmacenIdiomaSeguro([
    this._almacen = const FlutterSecureStorage(aOptions: AndroidOptions()),
  ]);

  final FlutterSecureStorage _almacen;
  static const String _clave = 'idioma_app';

  @override
  Future<String?> leer() async {
    try {
      return await _almacen.read(key: _clave);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> guardar(String? codigo) async {
    try {
      if (codigo == null) {
        await _almacen.delete(key: _clave);
      } else {
        await _almacen.write(key: _clave, value: codigo);
      }
    } catch (_) {
      // Sin almacenamiento la eleccion vale solo hasta cerrar la app.
    }
  }
}

/// El idioma de la app, aparte del idioma del telefono: quien tiene el celular
/// en ingles puede usar la app en español. [idioma] nulo = seguir al telefono.
///
/// El `MaterialApp` lo escucha y cambia de idioma al instante; no depende de la
/// sesion, asi que tambien vale en la pantalla de bienvenida.
class ControladorIdioma extends ChangeNotifier {
  ControladorIdioma([AlmacenIdioma? almacen])
    : _almacen = almacen ?? const AlmacenIdiomaSeguro();

  /// El unico de la app; las pruebas crean el suyo.
  static final ControladorIdioma instancia = ControladorIdioma();

  final AlmacenIdioma _almacen;
  IdiomaApp? _idioma;

  IdiomaApp? get idioma => _idioma;

  /// Nulo cuando se sigue al telefono: asi `MaterialApp` usa el del dispositivo.
  Locale? get locale => _idioma?.locale;

  /// Lee lo guardado. Se llama una vez al arrancar, antes de pintar.
  Future<void> cargar() async {
    final IdiomaApp? guardado = IdiomaApp.desdeCodigo(await _almacen.leer());
    if (guardado == _idioma) return;
    _idioma = guardado;
    notifyListeners();
  }

  /// Cambia el idioma ([nuevo] nulo = el del telefono) y lo recuerda.
  Future<void> elegir(IdiomaApp? nuevo) async {
    if (nuevo == _idioma) return;
    _idioma = nuevo;
    notifyListeners();
    await _almacen.guardar(nuevo?.codigo);
  }
}
