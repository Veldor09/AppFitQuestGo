import 'package:flutter/material.dart';

class DestinoNavegacion {
  const DestinoNavegacion({
    required this.lat,
    required this.lng,
    required this.nombre,
  });

  final double lat;
  final double lng;
  final String nombre;
}

class NavegacionApp {
  NavegacionApp._();

  static final NavegacionApp instancia = NavegacionApp._();

  final ValueNotifier<DestinoNavegacion?> destino =
      ValueNotifier<DestinoNavegacion?>(null);

  final ValueNotifier<int> solicitudesMapa = ValueNotifier<int>(0);

  int _mapasActivos = 0;

  bool get hayMapa => _mapasActivos > 0;

  void registrarMapa() => _mapasActivos++;
  void liberarMapa() {
    if (_mapasActivos > 0) _mapasActivos--;
  }

  void iniciar(BuildContext context, DestinoNavegacion d) {
    Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
    solicitudesMapa.value++;
    destino.value = DestinoNavegacion(lat: d.lat, lng: d.lng, nombre: d.nombre);
  }
}
