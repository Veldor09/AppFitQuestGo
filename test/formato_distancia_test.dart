import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/geo/formato_distancia.dart';

void main() {
  group('formatearDistancia', () {
    test('menos de un kilometro se dice en metros enteros', () {
      expect(formatearDistancia(0, locale: 'es'), '0 m');
      expect(formatearDistancia(296.4, locale: 'es'), '296 m');
      expect(formatearDistancia(999.4, locale: 'es'), '999 m');
    });

    test('desde el kilometro se dice en km con un decimal', () {
      expect(formatearDistancia(1234, locale: 'es'), '1,2 km');
      expect(formatearDistancia(12500, locale: 'es'), '12,5 km');
    });

    test('lo que redondea a 1000 m ya es un kilometro, no "1000 m"', () {
      expect(formatearDistancia(999.6, locale: 'es'), '1,0 km');
    });

    test('el separador decimal es el del idioma', () {
      expect(formatearDistancia(1234, locale: 'en'), '1.2 km');
      expect(formatearDistancia(1234, locale: 'pt_BR'), '1,2 km');
      expect(formatearDistancia(1234, locale: 'pt'), '1,2 km');
    });
  });
}
