import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/mapa/capa_dibujo_mano.dart';
import 'package:fit_quest_go/core/mapa/control_ubicacion.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';

const PosicionGps _yo = (lat: 9.9281, lng: -84.0907);

void main() {
  group('decidirAccionUbicacion (boton "mi ubicacion")', () {
    test('mapa en otra parte: te trae a tu posicion', () {
      expect(
        decidirAccionUbicacion(
          usuario: _yo,
          centroMapa: (lat: 9.95, lng: -84.1),
          inclinacion: 0,
        ),
        AccionUbicacion.centrar,
      );
    });

    test('ya centrado y plano: inclina el mapa', () {
      expect(
        decidirAccionUbicacion(
          usuario: _yo,
          centroMapa: (lat: 9.92812, lng: -84.09071),
          inclinacion: 0,
        ),
        AccionUbicacion.inclinar,
      );
    });

    test('centrado e inclinado: vuelve a la vista plana', () {
      expect(
        decidirAccionUbicacion(
          usuario: _yo,
          centroMapa: _yo,
          inclinacion: inclinacionNavegacion,
        ),
        AccionUbicacion.aplanar,
      );
    });

    test('inclinado pero lejos de ti: primero te trae (y lo aplana)', () {
      expect(
        decidirAccionUbicacion(
          usuario: _yo,
          centroMapa: (lat: 10.2, lng: -84.0),
          inclinacion: inclinacionNavegacion,
        ),
        AccionUbicacion.centrar,
      );
    });

    test('un poco movido (menos del radio) todavia cuenta como centrado', () {
      // ~33 m al norte.
      expect(
        decidirAccionUbicacion(
          usuario: _yo,
          centroMapa: (lat: _yo.lat + 0.0003, lng: _yo.lng),
          inclinacion: 0,
        ),
        AccionUbicacion.inclinar,
      );
    });

    test('mas lejos del radio ya no cuenta como centrado', () {
      // ~110 m al norte.
      expect(
        decidirAccionUbicacion(
          usuario: _yo,
          centroMapa: (lat: _yo.lat + 0.001, lng: _yo.lng),
          inclinacion: 0,
        ),
        AccionUbicacion.centrar,
      );
    });
  });

  group('simplificarTrazoMano (dibujo con el dedo)', () {
    test('una recta con cientos de puntos se queda en los dos extremos', () {
      final List<PuntoGeo> recta = <PuntoGeo>[
        for (int i = 0; i <= 300; i++) PuntoGeo(lat: 9.9 + i * 0.00001, lng: -84.1),
      ];

      final List<PuntoGeo> r = simplificarTrazoMano(recta);

      expect(r.length, 2);
      expect(r.first, recta.first);
      expect(r.last, recta.last);
    });

    test('una curva conserva su forma (mas de dos puntos) y el orden', () {
      final List<PuntoGeo> curva = <PuntoGeo>[
        for (int i = 0; i <= 200; i++)
          PuntoGeo(
            lat: 9.9 + i * 0.00002,
            lng: -84.1 + (i % 2 == 0 ? 0 : 0.00002) + i * 0.00003,
          ),
        for (int i = 0; i <= 200; i++)
          PuntoGeo(lat: 9.904 - i * 0.00002, lng: -84.094 + i * 0.00001),
      ];

      final List<PuntoGeo> r = simplificarTrazoMano(curva);

      expect(r.length, greaterThan(2));
      expect(r.length, lessThan(curva.length));
      expect(r.first, curva.first);
      expect(r.last, curva.last);
    });

    test('un trazo muy largo y ruidoso nunca pasa del maximo', () {
      final List<PuntoGeo> ruido = <PuntoGeo>[
        for (int i = 0; i < 3000; i++)
          PuntoGeo(
            lat: 9.9 + (i % 7) * 0.0004 + i * 0.00001,
            lng: -84.1 + (i % 11) * 0.0004 + i * 0.00001,
          ),
      ];

      expect(simplificarTrazoMano(ruido).length, lessThanOrEqualTo(maxPuntosTrazoMano));
    });

    test('con dos puntos o menos lo deja tal cual', () {
      final List<PuntoGeo> dos = <PuntoGeo>[
        const PuntoGeo(lat: 9.9, lng: -84.1),
        const PuntoGeo(lat: 9.91, lng: -84.11),
      ];

      expect(simplificarTrazoMano(dos), dos);
      expect(simplificarTrazoMano(<PuntoGeo>[]), isEmpty);
    });
  });
}
