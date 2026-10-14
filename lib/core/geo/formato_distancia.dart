import 'package:intl/intl.dart';

/// Una distancia para mostrarla: metros enteros por debajo del kilometro
/// ("296 m") y kilometros con un decimal desde ahi ("1,2 km"). El separador
/// decimal es el de [locale] (`es`, `en`, `pt_BR`...); "m" y "km" son iguales
/// en todos los idiomas de la app.
String formatearDistancia(double metros, {required String locale}) {
  final int redondeados = metros.round();
  if (redondeados < 1000) return '$redondeados m';
  final String km = NumberFormat.decimalPatternDigits(
    locale: locale,
    decimalDigits: 1,
  ).format(metros / 1000);
  return '$km km';
}
