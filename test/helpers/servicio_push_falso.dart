import 'package:fit_quest_go/core/push/servicio_push.dart';

/// El servicio de avisos fuera de la app sin Firebase: solo anota lo que le piden.
class ServicioPushFalso extends ServicioPush {
  final List<({String idioma, bool pedirPermiso})> registros =
      <({String idioma, bool pedirPermiso})>[];
  int bajas = 0;

  /// Se ejecuta al darse de baja (para mirar el estado de la app en ese momento).
  Future<void> Function()? alQuitar;

  @override
  bool get disponible => true;

  @override
  Future<void> registrar({
    required String idioma,
    bool pedirPermiso = true,
  }) async {
    registros.add((idioma: idioma, pedirPermiso: pedirPermiso));
  }

  @override
  Future<void> quitar() async {
    bajas++;
    await alQuitar?.call();
  }
}
