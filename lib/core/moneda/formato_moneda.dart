import 'package:intl/intl.dart';

import 'package:fit_quest_go/core/catalogos/monedas.dart';

/// El [importe] con el simbolo de la moneda [codigo] adelante y el formato del
/// idioma [locale]: `₡10.000` / `US$20,00` / `€18,00` en es, pt y pt_BR, y
/// `₡10,000` / `US$20.00` / `€18.00` en en. Una moneda fuera del catalogo se
/// muestra con su codigo (`5 XYZ`) en lugar de fallar.
String formatearImporte(num importe, String codigo, {required String locale}) {
  final Moneda? moneda = monedaPorCodigo(codigo);
  if (moneda == null) return '$importe $codigo';
  final NumberFormat formato = NumberFormat.currency(
    locale: locale,
    symbol: moneda.simbolo,
    decimalDigits: moneda.decimales,
    // El simbolo siempre adelante, sin espacio, como en el diseno.
    customPattern: moneda.decimales == 0 ? '¤#,##0' : '¤#,##0.00',
  );
  return formato.format(importe);
}
