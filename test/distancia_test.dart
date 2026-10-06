import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/geo/distancia.dart';

void main() {
  group('distanciaMetros', () {
    test('es 0 para el mismo punto', () {
      expect(distanciaMetros(9.9281, -84.0907, 9.9281, -84.0907), 0);
    });

    test('un grado de latitud son ~111.2 km', () {
      final double d = distanciaMetros(0, 0, 1, 0);
      expect(d, inInclusiveRange(111000, 111400));
    });

    test('0.0009 grados de latitud son ~100 m', () {
      final double d = distanciaMetros(9.9281, -84.0907, 9.9281 + 0.0009, -84.0907);
      expect(d, inInclusiveRange(95, 105));
    });

    test('es simetrica', () {
      final double ida = distanciaMetros(9.93, -84.08, 9.94, -84.09);
      final double vuelta = distanciaMetros(9.94, -84.09, 9.93, -84.08);
      expect(ida, closeTo(vuelta, 1e-6));
    });

    test('la longitud se acorta con la latitud', () {
      final double ecuador = distanciaMetros(0, 0, 0, 0.001);
      final double costaRica = distanciaMetros(10, 0, 10, 0.001);
      expect(costaRica, lessThan(ecuador));
    });
  });
}
