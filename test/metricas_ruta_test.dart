import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/rutas/application/metricas_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

void main() {
  group('formatoDuracion', () {
    test('menos de una hora: mm:ss', () {
      expect(formatoDuracion(Duration.zero), '00:00');
      expect(formatoDuracion(const Duration(seconds: 5)), '00:05');
      expect(formatoDuracion(const Duration(seconds: 65)), '01:05');
      expect(formatoDuracion(const Duration(seconds: 3599)), '59:59');
    });

    test('desde una hora: h:mm:ss', () {
      expect(formatoDuracion(const Duration(hours: 1)), '1:00:00');
      expect(formatoDuracion(const Duration(seconds: 3725)), '1:02:05');
      expect(formatoDuracion(const Duration(hours: 12, minutes: 3)), '12:03:00');
    });
  });

  group('ritmoPorKm', () {
    test('30 minutos en 5 km son 6:00 por km', () {
      expect(
        ritmoPorKm(const Duration(minutes: 30), 5),
        const Duration(minutes: 6),
      );
    });

    test('redondea al segundo mas cercano', () {
      // 1000 s / 3.1 km = 322.58 s -> 5:23 (sube) ; 1000 s / 3.3 km = 303.03 s -> 5:03 (baja)
      expect(
        ritmoPorKm(const Duration(seconds: 1000), 3.1),
        const Duration(minutes: 5, seconds: 23),
      );
      expect(
        ritmoPorKm(const Duration(seconds: 1000), 3.3),
        const Duration(minutes: 5, seconds: 3),
      );
    });

    test('con menos de 20 m recorridos no hay ritmo confiable', () {
      expect(ritmoPorKm(const Duration(minutes: 5), 0.019), isNull);
      expect(ritmoPorKm(const Duration(minutes: 5), 0), isNull);
    });

    test('sin tiempo no hay ritmo', () {
      expect(ritmoPorKm(Duration.zero, 3), isNull);
    });
  });

  group('formatoRitmo', () {
    test('minutos:segundos', () {
      expect(formatoRitmo(const Duration(minutes: 6)), '6:00');
      expect(formatoRitmo(const Duration(minutes: 5, seconds: 7)), '5:07');
    });

    test('mas de 59 minutos por km no pasa a horas', () {
      expect(formatoRitmo(const Duration(minutes: 75, seconds: 30)), '75:30');
    });

    test('sin ritmo muestra guiones', () {
      expect(formatoRitmo(null), '--:--');
    });
  });

  group('distanciaTrazoKm', () {
    test('sin puntos o con uno solo es cero', () {
      expect(distanciaTrazoKm(const <PuntoRuta>[]), 0);
      expect(distanciaTrazoKm(const <PuntoRuta>[PuntoRuta(lat: 9.9, lng: -84.0)]), 0);
    });

    test('suma los tramos: un grado de latitud son ~111.2 km', () {
      final double km = distanciaTrazoKm(const <PuntoRuta>[
        PuntoRuta(lat: 0, lng: 0),
        PuntoRuta(lat: 0.5, lng: 0),
        PuntoRuta(lat: 1, lng: 0),
      ]);
      expect(km, inInclusiveRange(111.0, 111.4));
    });

    test('0.0009 grados de latitud son ~0.1 km', () {
      final double km = distanciaTrazoKm(const <PuntoRuta>[
        PuntoRuta(lat: 9.9281, lng: -84.0907),
        PuntoRuta(lat: 9.9290, lng: -84.0907),
      ]);
      expect(km, inInclusiveRange(0.095, 0.105));
    });
  });
}
