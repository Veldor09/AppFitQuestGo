import 'package:fit_quest_go/Modulos/perfil/data/avisos_locales.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificacion.dart';

/// Los avisos locales en memoria (los de verdad viven en SQLite, que no existe
/// en `flutter test`). Se comporta igual: la misma clave no se repite y los ids
/// son negativos.
class AvisosLocalesFalso implements AvisosLocales {
  final List<AvisoLocal> registrados = <AvisoLocal>[];
  final List<Notificacion> _filas = <Notificacion>[];
  int _siguiente = 1;

  @override
  Future<void> registrar(AvisoLocal aviso) async {
    if (registrados.any((AvisoLocal a) => a.clave == aviso.clave)) return;
    registrados.add(aviso);
    _filas.add(
      Notificacion(
        id: -_siguiente++,
        categoria: aviso.categoria,
        titulo: aviso.titulo,
        mensaje: aviso.mensaje,
        creadaEn: aviso.creadaEn,
      ),
    );
  }

  @override
  Future<List<Notificacion>> listar() async => List<Notificacion>.of(_filas.reversed);

  @override
  Future<int> conteoNoLeidas() async =>
      _filas.where((Notificacion n) => !n.leida).length;

  @override
  Future<void> marcarLeida(int id) async {
    for (final Notificacion n in _filas) {
      if (n.id == id) n.leida = true;
    }
  }

  @override
  Future<void> marcarTodasLeidas() async {
    for (final Notificacion n in _filas) {
      n.leida = true;
    }
  }

  @override
  Future<void> eliminar(int id) async => _filas.removeWhere((Notificacion n) => n.id == id);
}
