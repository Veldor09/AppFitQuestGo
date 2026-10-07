import 'package:flutter/material.dart';

/// "5 oct 2026 8:00 a. m.": fecha y hora locales en el idioma de la app, con
/// los formatos que ya trae `MaterialLocalizations` (no hace falta inicializar
/// `intl` aparte).
String fechaHoraLabel(BuildContext context, DateTime fecha) {
  final MaterialLocalizations ml = MaterialLocalizations.of(context);
  final DateTime local = fecha.toLocal();
  final String dia = ml.formatMediumDate(local);
  final String hora = ml.formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$dia $hora';
}

/// Mismo dia: "5 oct 2026 8:00 a. m. - 11:00 a. m."; si no, las dos fechas
/// completas.
String rangoFechasLabel(BuildContext context, DateTime inicio, DateTime fin) {
  final MaterialLocalizations ml = MaterialLocalizations.of(context);
  final DateTime i = inicio.toLocal();
  final DateTime f = fin.toLocal();
  final bool mismoDia =
      i.year == f.year && i.month == f.month && i.day == f.day;
  if (!mismoDia) {
    return '${fechaHoraLabel(context, i)} - ${fechaHoraLabel(context, f)}';
  }
  final String horaFin = ml.formatTimeOfDay(TimeOfDay.fromDateTime(f));
  return '${fechaHoraLabel(context, i)} - $horaFin';
}
