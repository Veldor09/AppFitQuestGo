import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/geo/votacion.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';

/// A cuantos metros de una alerta la app avisa por voz y pregunta si sigue ahi.
const double radioAvisoMetros = 100;

/// La alerta a la que toca avisar desde (`lat`, `lng`), o null.
///
/// Solo cuentan las activas, a `radioMetros` o menos, que no sean tuyas, que no
/// hayas votado y de las que no hayas avisado ya en esta sesion. Si hay varias,
/// la mas cercana.
Alerta? alertaParaAvisar({
  required double lat,
  required double lng,
  required Iterable<Alerta> alertas,
  required int? usuarioId,
  required Set<int> yaAvisadas,
  double radioMetros = radioAvisoMetros,
}) {
  Alerta? elegida;
  double menorDistancia = double.infinity;
  for (final Alerta alerta in alertas) {
    if (!alerta.estaActiva ||
        alerta.miVoto != null ||
        yaAvisadas.contains(alerta.id) ||
        (usuarioId != null && alerta.creadoPorId == usuarioId)) {
      continue;
    }
    final double distancia = distanciaMetros(lat, lng, alerta.lat, alerta.lng);
    if (distancia <= radioMetros && distancia < menorDistancia) {
      elegida = alerta;
      menorDistancia = distancia;
    }
  }
  return elegida;
}

/// Vigila la posicion del dispositivo contra las alertas activas y, al entrar
/// en el radio de una, la deja en [alertaCercana] y llama una sola vez a
/// `alAvisar` (el aviso por voz). Un aviso a la vez; cada alerta se avisa una
/// sola vez por sesion, la votes o la descartes.
///
/// No sabe de mapas ni de red: recibe el stream de posiciones ya armado, asi
/// que se prueba sin GPS y funciona igual aunque el mapa no se pueda crear.
class ProximidadAlertas extends ChangeNotifier {
  ProximidadAlertas({
    required this._posiciones,
    required this._usuarioId,
    required this._alAvisar,
    this._alPrimeraPosicion,
  });

  final Stream<PosicionGps> _posiciones;
  final int? Function() _usuarioId;
  final void Function(Alerta alerta, int metros) _alAvisar;

  /// Se llama una sola vez, con la primera posicion que entrega el GPS: sirve
  /// para consultas que dependen de donde estas (el clima de la zona).
  final void Function(PosicionGps posicion)? _alPrimeraPosicion;
  final Set<int> _avisadas = <int>{};

  StreamSubscription<PosicionGps>? _suscripcion;
  List<Alerta> _alertas = const <Alerta>[];
  PosicionGps? _ultimaPosicion;
  Alerta? _alertaCercana;
  final ValueNotifier<PosicionGps?> _posicion = ValueNotifier<PosicionGps?>(
    null,
  );

  /// La ultima posicion recibida, y un aviso cada vez que cambia: la pantalla
  /// la usa para lo que depende de donde estas (el cuadro "Cerca de ti"). Es
  /// aparte de este notificador, que solo avisa cuando cambia la alerta.
  ValueListenable<PosicionGps?> get posicion => _posicion;

  /// La alerta que se le esta preguntando al usuario, o null.
  Alerta? get alertaCercana => _alertaCercana;

  /// Ultima posicion recibida: es la que se envia al servidor al votar.
  PosicionGps? get ultimaPosicion => _ultimaPosicion;

  /// Distancia actual (m) a [alertaCercana], o null si no hay aviso.
  int? get metrosAlertaCercana {
    final Alerta? alerta = _alertaCercana;
    final PosicionGps? pos = _ultimaPosicion;
    if (alerta == null || pos == null) return null;
    return distanciaMetros(pos.lat, pos.lng, alerta.lat, alerta.lng).round();
  }

  void iniciar() {
    _suscripcion ??= _posiciones.listen(
      (PosicionGps pos) {
        final bool primera = _ultimaPosicion == null;
        _ultimaPosicion = pos;
        _posicion.value = pos;
        if (primera) _alPrimeraPosicion?.call(pos);
        _evaluar();
      },
      // Sin permiso o con el GPS apagado el aviso simplemente no ocurre.
      onError: (Object _) {},
    );
  }

  /// Reemplaza la lista de alertas vigentes (carga inicial, tras votar, ...).
  void actualizarAlertas(List<Alerta> alertas) {
    _alertas = alertas;
    _evaluar();
  }

  /// Cierra el aviso actual (voto hecho o "ahora no") y pasa al siguiente, si
  /// hay otra alerta dentro del radio.
  void descartar() => _evaluar(descartarActual: true);

  void _evaluar({bool descartarActual = false}) {
    final Alerta? antes = _alertaCercana;
    if (descartarActual) _alertaCercana = null;
    final Alerta? nueva = _recalcular();
    if (nueva != null || _alertaCercana != null || antes != null) {
      notifyListeners();
    }
    if (nueva != null) _alAvisar(nueva, metrosAlertaCercana ?? 0);
  }

  /// Devuelve la alerta recien elegida (a avisar) o null.
  Alerta? _recalcular() {
    final PosicionGps? pos = _ultimaPosicion;
    final Alerta? actual = _alertaCercana;
    if (actual != null) {
      final bool sigueEnLista = _alertas.any((Alerta a) => a.id == actual.id);
      final bool alAlcance =
          pos == null ||
          distanciaMetros(pos.lat, pos.lng, actual.lat, actual.lng) <=
              radioVotoMetros;
      if (sigueEnLista && alAlcance) return null;
      _alertaCercana = null;
    }
    if (pos == null) return null;
    final Alerta? siguiente = alertaParaAvisar(
      lat: pos.lat,
      lng: pos.lng,
      alertas: _alertas,
      usuarioId: _usuarioId(),
      yaAvisadas: _avisadas,
    );
    if (siguiente == null) return null;
    _avisadas.add(siguiente.id);
    _alertaCercana = siguiente;
    return siguiente;
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    _suscripcion = null;
    _posicion.dispose();
    super.dispose();
  }
}
