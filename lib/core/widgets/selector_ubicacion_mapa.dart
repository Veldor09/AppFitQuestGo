import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/mapa/ubicacion_mapa.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Mapa donde se toca para marcar un lugar (la ubicacion de un comercio).
/// Muestra un solo pin; cada toque lo mueve y avisa por [onCambio].
///
/// Con [inicial] el pin ya esta puesto y la camara arranca ahi; sin ella la
/// camara va a donde esta la persona y el pin aparece al primer toque.
class SelectorUbicacionMapa extends StatefulWidget {
  const SelectorUbicacionMapa({
    super.key,
    required this.onCambio,
    this.inicial,
  });

  final void Function(double lat, double lng) onCambio;
  final ({double lat, double lng})? inicial;

  @override
  State<SelectorUbicacionMapa> createState() => _SelectorUbicacionMapaState();
}

class _SelectorUbicacionMapaState extends State<SelectorUbicacionMapa> {
  MapboxMap? _mapa;
  CircleAnnotationManager? _pin;
  ({double lat, double lng})? _actual;

  /// Misma instancia en cada `build` (ver `MapaTrazoRuta`).
  late final CameraViewportState _viewportInicial = CameraViewportState(
    center: Point(
      coordinates: Position(
        widget.inicial?.lng ?? -84.0907,
        widget.inicial?.lat ?? 9.9281,
      ),
    ),
    zoom: widget.inicial == null ? 13.5 : 16,
  );

  @override
  void initState() {
    super.initState();
    _actual = widget.inicial;
  }

  Future<void> _onMapCreated(MapboxMap mapa) async {
    _mapa = mapa;
    mapa.addInteraction(TapInteraction.onMap(_alTocar));
    _pin = await mapa.annotations.createCircleAnnotationManager();
    await _dibujarPin();
    if (widget.inicial == null) await centrarEnUbicacionActual(mapa);
  }

  Future<void> _dibujarPin() async {
    final CircleAnnotationManager? pin = _pin;
    final ({double lat, double lng})? actual = _actual;
    if (pin == null) return;
    await pin.deleteAll();
    if (actual == null) return;
    await pin.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: Position(actual.lng, actual.lat)),
        circleColor: FqColors.purple.toARGB32(),
        circleRadius: 10,
        circleStrokeColor: FqColors.white.toARGB32(),
        circleStrokeWidth: 3,
      ),
    );
  }

  void _alTocar(MapContentGestureContext contexto) {
    final Position posicion = contexto.point.coordinates;
    final double lng = posicion[0]!.toDouble();
    final double lat = posicion[1]!.toDouble();
    setState(() => _actual = (lat: lat, lng: lng));
    unawaited(_dibujarPin());
    widget.onCambio(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey<String>('selector-ubicacion-mapa'),
      viewport: _viewportInicial,
      onMapCreated: _onMapCreated,
    );
  }

  @override
  void dispose() {
    _mapa = null;
    super.dispose();
  }
}
