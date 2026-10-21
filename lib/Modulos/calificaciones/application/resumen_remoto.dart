import 'package:flutter/foundation.dart';

import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion_api.dart';

/// Los pulgares de un objeto, pedidos una sola vez al servidor para que una
/// pantalla los comparta entre su cabecera ("👍 5 · 👎 8") y su seccion de
/// calificar. Mientras no llegan (o si no se pudieron pedir) [resumen] es null
/// y la pantalla funciona igual, solo que sin pulgares.
class ResumenRemoto extends ChangeNotifier {
  ResumenRemoto({required this.tipo, required this.id, CalificacionApi? api})
    : _api = api ?? CalificacionApi.predeterminada();

  final TipoCalificable tipo;
  final int id;
  final CalificacionApi _api;

  ResumenCalificacion? _resumen;
  bool _cerrado = false;

  ResumenCalificacion? get resumen => _resumen;

  Future<void> cargar() async {
    try {
      final ResumenCalificacion r = await _api.resumen(tipo, id);
      actualizar(r);
    } catch (_) {
      // Sin pulgares por ahora: no es motivo para romper la pantalla.
    }
  }

  /// Cambia el resumen (por ejemplo, tras calificar) y avisa a quien lo mira.
  void actualizar(ResumenCalificacion nuevo) {
    if (_cerrado) return;
    _resumen = nuevo;
    notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
