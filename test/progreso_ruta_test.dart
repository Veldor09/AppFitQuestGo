import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/rutas/application/progreso_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

void main() {
  // ~1.1 km hacia el este sobre lat 10.0.
  const List<PuntoRuta> trazo = <PuntoRuta>[
    PuntoRuta(lat: 10.0, lng: -85.000),
    PuntoRuta(lat: 10.0, lng: -84.995),
    PuntoRuta(lat: 10.0, lng: -84.990),
  ];

  test('en el punto medio lleva la mitad y falta la mitad', () {
    final ProgresoEnRuta p = calcularProgreso((lat: 10.0, lng: -84.995), trazo);
    expect(p.distanciaAlTrazoM, lessThan(1));
    expect(p.progresoM, closeTo(p.restanteM, 2));
  });

  test('antes del inicio: progreso 0 y falta todo', () {
    final ProgresoEnRuta p = calcularProgreso((lat: 10.0, lng: -85.01), trazo);
    expect(p.progresoM, closeTo(0, 0.5));
    expect(p.restanteM, greaterThan(1000));
  });

  test('sin trazo no hay progreso', () {
    final ProgresoEnRuta p =
        calcularProgreso((lat: 10.0, lng: -85.0), const <PuntoRuta>[]);
    expect(p.restanteM, 0);
    expect(p.distanciaAlTrazoM, double.infinity);
  });

  test('rumbo: este = 90, norte = 0', () {
    expect(rumboEntre((lat: 10, lng: -85), (lat: 10, lng: -84.99)), closeTo(90, 0.5));
    expect(rumboEntre((lat: 10, lng: -85), (lat: 10.01, lng: -85)), closeTo(0, 0.5));
  });

  test('adelgazarTrazo respeta el maximo y conserva extremos', () {
    final List<PuntoRuta> largo = <PuntoRuta>[
      for (int i = 0; i < 5000; i++) PuntoRuta(lat: 10 + i * 1e-5, lng: -85),
    ];
    final List<PuntoRuta> r = adelgazarTrazo(largo, maximo: 1500);
    expect(r.length, 1500);
    expect(r.first, same(largo.first));
    expect(r.last, same(largo.last));
    expect(adelgazarTrazo(trazo).length, 3);
  });
}
