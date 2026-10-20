import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/catalogos/monedas.dart';
import 'package:fit_quest_go/core/moneda/formato_moneda.dart';

void main() {
  group('formatearImporte', () {
    test('lleva el simbolo adelante y el formato del idioma', () {
      expect(formatearImporte(10000, 'CRC', locale: 'es'), '₡10.000');
      expect(formatearImporte(20, 'USD', locale: 'es'), 'US\$20,00');
      expect(formatearImporte(18, 'EUR', locale: 'pt_BR'), '€18,00');
      expect(formatearImporte(10000, 'CRC', locale: 'en'), '₡10,000');
      expect(formatearImporte(20, 'USD', locale: 'en'), 'US\$20.00');
      expect(formatearImporte(18, 'EUR', locale: 'en'), '€18.00');
    });

    test('una moneda desconocida se muestra con su codigo, sin romper', () {
      expect(formatearImporte(5, 'XYZ', locale: 'es'), '5 XYZ');
    });
  });

  group('monedaPorCodigo', () {
    test('encuentra la moneda del catalogo y devuelve null si no existe', () {
      expect(monedaPorCodigo('EUR')?.simbolo, '€');
      expect(monedaPorCodigo('XYZ'), isNull);
    });
  });
}
