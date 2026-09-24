import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/mapa/ubicacion_mapa.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Mapa Mapbox real centrado en la ubicacion GPS del dispositivo, mismo
/// tamano que ocupaba la maqueta decorativa `FqMapView`. Se usa en los
/// paneles marcados "en vivo", donde el mapa tiene que mostrar la posicion
/// real y no un dibujo.
class FqLiveMapView extends StatelessWidget {
  const FqLiveMapView({super.key, this.height = 235});

  final double height;

  static const String _accessToken = String.fromEnvironment(
    'ACCESS_TOKEN',
    defaultValue: String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: _accessToken.isEmpty
          ? const _MissingTokenBackground()
          : MapWidget(
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(-84.0907, 9.9281)),
                zoom: 13.5,
              ),
              onMapCreated: centrarEnUbicacionActual,
            ),
    );
  }
}

class _MissingTokenBackground extends StatelessWidget {
  const _MissingTokenBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EEE5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: const Text(
        'Mapbox necesita ACCESS_TOKEN.\nInicia con --dart-define=ACCESS_TOKEN=pk…',
        textAlign: TextAlign.center,
        style: TextStyle(color: FqColors.muted, fontWeight: FontWeight.w600),
      ),
    );
  }
}
