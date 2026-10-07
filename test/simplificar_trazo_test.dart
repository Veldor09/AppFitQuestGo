import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/geo/simplificar_trazo.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';

PuntoGeo _p(double lat, double lng) => PuntoGeo(lat: lat, lng: lng);

void main() {
  group('simplificarTrazo', () {
    test('con 2 puntos o menos devuelve el trazo igual', () {
      expect(simplificarTrazo(<PuntoGeo>[]), isEmpty);
      expect(simplificarTrazo(<PuntoGeo>[_p(10, -84)]), hasLength(1));
      final List<PuntoGeo> dos = <PuntoGeo>[_p(10, -84), _p(10.1, -84.1)];
      expect(simplificarTrazo(dos), dos);
    });

    test('una recta con muchos puntos queda en sus dos extremos', () {
      final List<PuntoGeo> recta = <PuntoGeo>[
        for (int i = 0; i <= 100; i++) _p(10 + i * 0.0001, -84),
      ];
      final List<PuntoGeo> r = simplificarTrazo(recta);
      expect(r, <PuntoGeo>[recta.first, recta.last]);
    });

    test('conserva las esquinas (una L)', () {
      final List<PuntoGeo> ele = <PuntoGeo>[
        for (int i = 0; i <= 50; i++) _p(10, -84 + i * 0.0001),
        for (int i = 1; i <= 50; i++) _p(10 + i * 0.0001, -84 + 50 * 0.0001),
      ];
      final List<PuntoGeo> r = simplificarTrazo(ele);
      expect(r, hasLength(3));
      expect(r.first, ele.first);
      expect(r.last, ele.last);
      expect(r[1], _p(10, -84 + 50 * 0.0001));
    });

    test('siempre conserva el primer y el ultimo punto', () {
      final List<PuntoGeo> zigzag = <PuntoGeo>[
        for (int i = 0; i < 40; i++)
          _p(10 + i * 0.00005, -84 + (i.isEven ? 0 : 0.00001)),
      ];
      final List<PuntoGeo> r = simplificarTrazo(zigzag, toleranciaM: 50);
      expect(r.first, zigzag.first);
      expect(r.last, zigzag.last);
    });

    test(
      'un ruido menor que la tolerancia se descarta; uno mayor se conserva',
      () {
        // ~1 m de desvio en el punto del medio (0.00001 grados ~ 1.1 m).
        final List<PuntoGeo> ruidoso = <PuntoGeo>[
          _p(10, -84),
          _p(10.0005, -84 + 0.00001),
          _p(10.001, -84),
        ];
        expect(simplificarTrazo(ruidoso, toleranciaM: 3), hasLength(2));
        expect(simplificarTrazo(ruidoso, toleranciaM: 0.5), hasLength(3));
      },
    );

    test('un trazo a mano alzada de miles de puntos se aligera mucho', () {
      // Un circulo de ~100 m de radio dibujado con 3000 puntos.
      final List<PuntoGeo> circulo = <PuntoGeo>[
        for (int i = 0; i < 3000; i++)
          _p(
            10 + 0.0009 * math.sin(i * 2 * math.pi / 3000),
            -84 + 0.0009 * math.cos(i * 2 * math.pi / 3000),
          ),
      ];
      final List<PuntoGeo> r = simplificarTrazo(circulo, toleranciaM: 3);
      expect(r.length, lessThan(circulo.length ~/ 10));
      expect(r.length, greaterThan(8)); // sigue pareciendose a un circulo
    });

    test('no desborda la pila con un trazo muy largo', () {
      final List<PuntoGeo> largo = <PuntoGeo>[
        for (int i = 0; i < 20000; i++) _p(10 + i * 1e-6, -84 + (i % 7) * 1e-7),
      ];
      expect(() => simplificarTrazo(largo), returnsNormally);
    });

    test('no muta la lista original', () {
      final List<PuntoGeo> original = <PuntoGeo>[
        for (int i = 0; i <= 10; i++) _p(10 + i * 0.0001, -84),
      ];
      final List<PuntoGeo> copia = List<PuntoGeo>.of(original);
      simplificarTrazo(original);
      expect(original, copia);
    });

    test('puntos repetidos no rompen (division por cero)', () {
      final List<PuntoGeo> repetidos = <PuntoGeo>[
        _p(10, -84),
        _p(10, -84),
        _p(10, -84),
        _p(10, -84),
      ];
      expect(() => simplificarTrazo(repetidos), returnsNormally);
    });
  });

  group('abrirArea', () {
    test('quita el ultimo punto si repite el primero', () {
      final List<PuntoGeo> cerrada = <PuntoGeo>[
        _p(10, -84),
        _p(10, -83.9),
        _p(10.1, -83.9),
        _p(10, -84),
      ];
      expect(abrirArea(cerrada), hasLength(3));
    });

    test('deja igual un area ya abierta', () {
      final List<PuntoGeo> abierta = <PuntoGeo>[
        _p(10, -84),
        _p(10, -83.9),
        _p(10.1, -83.9),
      ];
      expect(abrirArea(abierta), abierta);
    });
  });
}
