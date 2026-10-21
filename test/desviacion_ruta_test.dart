import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/Modulos/rutas/application/desviacion_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

void main() {
  // Trazo recto de ~1.1 km hacia el este sobre lat 10.0.
  const List<PuntoRuta> trazo = <PuntoRuta>[
    PuntoRuta(lat: 10.0, lng: -85.000),
    PuntoRuta(lat: 10.0, lng: -84.990),
  ];

  test('punto sobre el trazo esta a ~0 m', () {
    expect(distanciaATrazoM((lat: 10.0, lng: -84.995), trazo), lessThan(1));
  });

  test('punto ~111 m al norte del trazo', () {
    final double d = distanciaATrazoM((lat: 10.001, lng: -84.995), trazo);
    expect(d, closeTo(111, 3));
  });

  test('desviacion avisa una vez, recuerda tras el intervalo y detecta regreso', () {
    DateTime reloj = DateTime(2026, 1, 1);
    final DesviacionRutaDetector det =
        DesviacionRutaDetector(trazo: trazo, ahora: () => reloj);

    expect(det.evaluar((lat: 10.0, lng: -84.995)), EventoDesviacion.ninguno);
    expect(det.evaluar((lat: 10.001, lng: -84.995)), EventoDesviacion.desviado);

    reloj = reloj.add(const Duration(seconds: 10));
    expect(det.evaluar((lat: 10.001, lng: -84.995)), EventoDesviacion.ninguno);

    reloj = reloj.add(const Duration(seconds: 40));
    expect(det.evaluar((lat: 10.001, lng: -84.995)), EventoDesviacion.desviado);

    expect(det.evaluar((lat: 10.0, lng: -84.995)), EventoDesviacion.regreso);
    expect(det.desviado, isFalse);
  });

  test('puntoMasCercanoEnTrazo proyecta perpendicularmente sobre el segmento', () {
    final PosicionGps proyectado =
        puntoMasCercanoEnTrazo((lat: 10.001, lng: -84.995), trazo);
    expect(proyectado.lat, closeTo(10.0, 0.00001));
    expect(proyectado.lng, closeTo(-84.995, 0.00001));
  });

  test('puntoMasCercanoEnTrazo se acota a los extremos si queda fuera del segmento', () {
    final PosicionGps antesDelInicio =
        puntoMasCercanoEnTrazo((lat: 10.0, lng: -85.010), trazo);
    expect(antesDelInicio.lat, closeTo(10.0, 0.00001));
    expect(antesDelInicio.lng, closeTo(-85.000, 0.00001));
  });
}
