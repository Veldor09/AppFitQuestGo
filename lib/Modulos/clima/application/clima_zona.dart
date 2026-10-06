import 'package:flutter/foundation.dart';

import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/Modulos/clima/data/alerta_clima.dart';
import 'package:fit_quest_go/Modulos/clima/data/clima_api.dart';

/// Los avisos del clima de la zona donde esta la persona: lluvia fuerte,
/// tormenta o calor extremo. Consulta al servidor con la ultima posicion del
/// GPS y recuerda cuales avisos ya cerro la persona.
///
/// El clima es un extra: si la consulta falla (sin red, proveedor caido) no se
/// molesta a nadie, se conserva lo ultimo que se supo y se reintenta en la
/// proxima vuelta.
class ClimaZona extends ChangeNotifier {
  ClimaZona({required this._api, required this._posicion});

  final ClimaApi _api;
  final PosicionGps? Function() _posicion;

  List<AlertaClima> _alertas = const <AlertaClima>[];
  String _fuente = '';
  final Set<String> _cerrados = <String>{};
  bool _consultando = false;
  bool _descartado = false;

  /// Los avisos que la persona aun no cerro: del mas grave al menos grave.
  List<AlertaClima> get visibles => <AlertaClima>[
    for (final AlertaClima a in _alertas)
      if (!_cerrados.contains(a.clave)) a,
  ];

  /// El aviso a mostrar ahora, o null si no hay mal tiempo (o ya los cerro).
  AlertaClima? get principal {
    final List<AlertaClima> lista = visibles;
    return lista.isEmpty ? null : lista.first;
  }

  /// Quien aporta los datos (se muestra como credito).
  String get fuente => _fuente;

  /// Pide los avisos de la zona actual. No hace nada sin posicion o si ya hay
  /// una consulta en vuelo.
  Future<void> actualizar() async {
    final PosicionGps? pos = _posicion();
    if (pos == null || _consultando) return;
    _consultando = true;
    try {
      final RespuestaClima respuesta = await _api.alertas(
        lat: pos.lat,
        lng: pos.lng,
      );
      if (_descartado) return;
      _alertas = respuesta.alertas;
      _fuente = respuesta.fuente;
      notifyListeners();
    } catch (_) {
      // Se conserva lo ultimo que se supo; la proxima vuelta reintenta.
    } finally {
      _consultando = false;
    }
  }

  /// La persona cerro este aviso: no se le vuelve a mostrar lo mismo (mismo tipo
  /// y mismo nivel). Si el aviso sube de nivel, vuelve a aparecer.
  void cerrar(AlertaClima alerta) {
    _cerrados.add(alerta.clave);
    notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
