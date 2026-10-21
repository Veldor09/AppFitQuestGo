import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/geo/simplificar_trazo.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';

/// Un trazo no debe pasar de esto tras simplificarlo (el servidor admite 1000).
const int maxPuntosTrazoMano = 400;

/// Separacion minima, en pixeles, entre dos puntos del dedo que se conservan.
const double pasoMinimoPx = 5;

/// Simplifica con tolerancia creciente hasta que el trazo es liviano: un dedo
/// deja cientos de puntos por segundo y asi viajan y se guardan unos pocos, sin
/// cambiar la forma a la vista. Es el mismo criterio con el que las empresas
/// dibujan sus recorridos.
List<PuntoGeo> simplificarTrazoMano(
  List<PuntoGeo> puntos, {
  int maxPuntos = maxPuntosTrazoMano,
}) {
  double tolerancia = 3;
  List<PuntoGeo> resultado = simplificarTrazo(puntos, toleranciaM: tolerancia);
  while (resultado.length > maxPuntos && tolerancia < 500) {
    tolerancia *= 2;
    resultado = simplificarTrazo(puntos, toleranciaM: tolerancia);
  }
  return resultado;
}

/// Capa transparente sobre un mapa de Mapbox que convierte el dedo en un
/// trazo: mientras esta encima, el mapa no se mueve y cada punto del dedo se
/// convierte en una coordenada con `coordinateForPixel`. Al soltar, el trazo se
/// simplifica y llega por [alTrazo]; si es demasiado corto llega
/// [alTrazoCorto] y no se dibuja nada.
///
/// Es el mismo mecanismo con el que las empresas trazan sus recorridos y areas
/// (`MapaTrazosEvento`), sacado a un widget para que el deportista dibuje sus
/// rutas igual. La linea que sigue al dedo la pinta quien lo usa con
/// [alMover], porque es quien tiene el manejador de lineas del mapa.
class CapaDibujoMano extends StatefulWidget {
  const CapaDibujoMano({
    super.key,
    required this.mapa,
    required this.alTrazo,
    this.alTrazoCorto,
    this.alMover,
    this.alEmpezar,
    this.puntosMinimos = 2,
  });

  /// El mapa de la pantalla; null mientras todavia no existe.
  final MapboxMap? Function() mapa;

  /// Un trazo terminado: ya simplificado.
  final ValueChanged<List<PuntoGeo>> alTrazo;
  final VoidCallback? alTrazoCorto;

  /// El trazo en curso, con cada punto nuevo del dedo (sin simplificar).
  final ValueChanged<List<PuntoGeo>>? alMover;

  /// El dedo toco el mapa: empieza un trazo nuevo.
  final VoidCallback? alEmpezar;
  final int puntosMinimos;

  @override
  State<CapaDibujoMano> createState() => _CapaDibujoManoState();
}

class _CapaDibujoManoState extends State<CapaDibujoMano> {
  /// Puntos del trazo en curso, en el orden en que el dedo los dejo.
  final List<PuntoGeo> _enCurso = <PuntoGeo>[];
  Offset? _ultimoPixel;

  /// Las conversiones pixel -> coordenada son asincronas: se encadenan para
  /// que los puntos queden en el orden del dedo aunque lleguen mezclados.
  Future<void> _cola = Future<void>.value();

  void _alEmpezar(DragStartDetails d) {
    _enCurso.clear();
    _ultimoPixel = null;
    widget.alEmpezar?.call();
    _agregarPixel(d.localPosition);
  }

  void _alMover(DragUpdateDetails d) => _agregarPixel(d.localPosition);

  void _agregarPixel(Offset pixel) {
    final Offset? anterior = _ultimoPixel;
    if (anterior != null && (pixel - anterior).distance < pasoMinimoPx) return;
    _ultimoPixel = pixel;
    _cola = _cola.then((_) async {
      final MapboxMap? mapa = widget.mapa();
      if (mapa == null || !mounted) return;
      final Point punto = await mapa.coordinateForPixel(
        ScreenCoordinate(x: pixel.dx, y: pixel.dy),
      );
      _enCurso.add(
        PuntoGeo(
          lat: punto.coordinates.lat.toDouble(),
          lng: punto.coordinates.lng.toDouble(),
        ),
      );
      widget.alMover?.call(List<PuntoGeo>.unmodifiable(_enCurso));
    });
  }

  Future<void> _alSoltar(DragEndDetails _) async {
    await _cola;
    if (!mounted) return;
    final List<PuntoGeo> trazo = simplificarTrazoMano(
      List<PuntoGeo>.of(_enCurso),
    );
    _enCurso.clear();
    _ultimoPixel = null;
    if (trazo.length < widget.puntosMinimos) {
      widget.alTrazoCorto?.call();
      return;
    }
    widget.alTrazo(trazo);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey<String>('capa-dibujo'),
      behavior: HitTestBehavior.opaque,
      onPanStart: _alEmpezar,
      onPanUpdate: _alMover,
      onPanEnd: _alSoltar,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: FqColors.volt, width: 3),
        ),
      ),
    );
  }
}
