import 'package:flutter/foundation.dart';

import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion_api.dart';

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
    }
  }

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
