import 'package:intl/intl.dart';

/// Factor de conversión estándar de kilómetros a millas.
const double kKmAMillas = 0.621371192237334;

/// Factor de conversión de millas a kilómetros.
const double kMillasAKm = 1.609344;

/// Convierte una distancia en kilómetros a la unidad indicada ('km' o 'mi').
double convertirDistancia(double km, String unidad) {
  if (unidad.toLowerCase() == 'mi') {
    return km * kKmAMillas;
  }
  return km;
}

/// Etiqueta en mayúsculas de la unidad ('KM' o 'MI').
String etiquetaUnidad(String unidad) {
  return unidad.toLowerCase() == 'mi' ? 'MI' : 'KM';
}

/// Una distancia para mostrarla: metros enteros por debajo del kilometro
/// ("296 m") y kilometros o millas con un decimal desde ahi ("1,2 km" / "0,7 mi").
/// El separador decimal es el de [locale] (`es`, `en`, `pt_BR`...).
String formatearDistancia(
  double metros, {
  required String locale,
  String unidad = 'km',
}) {
  final bool esMillas = unidad.toLowerCase() == 'mi';
  if (esMillas) {
    final double millas = (metros / 1000) * kKmAMillas;
    final String mi = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    ).format(millas);
    return '$mi mi';
  }

  final int redondeados = metros.round();
  if (redondeados < 1000) return '$redondeados m';
  final String km = NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: 1,
  ).format(metros / 1000);
  return '$km km';
}
