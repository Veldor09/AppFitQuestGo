import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/geo/simplificar_trazo.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';

const int maxPuntosTrazoMano = 400;

const double pasoMinimoPx = 5;

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

  final MapboxMap? Function() mapa;

  final ValueChanged<List<PuntoGeo>> alTrazo;
  final VoidCallback? alTrazoCorto;

  final ValueChanged<List<PuntoGeo>>? alMover;

  final VoidCallback? alEmpezar;
  final int puntosMinimos;

  @override
  State<CapaDibujoMano> createState() => _CapaDibujoManoState();
}

class _CapaDibujoManoState extends State<CapaDibujoMano> {
  final List<PuntoGeo> _enCurso = <PuntoGeo>[];
  Offset? _ultimoPixel;

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
