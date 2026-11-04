import 'package:flutter/material.dart';

/// Iconos Material para insignias existentes y nuevas. El campo `emoji` del
/// servidor se mantiene para compatibilidad con datos ya guardados.
class FqInsigniaIcon {
  const FqInsigniaIcon._();

  static const Map<String, IconData> options = <String, IconData>{
    'medal': Icons.military_tech_rounded,
    'hiking': Icons.hiking_rounded,
    'route': Icons.route_rounded,
    'place': Icons.place_rounded,
    'explore': Icons.explore_rounded,
    'warning': Icons.warning_amber_rounded,
    'shield': Icons.shield_outlined,
    'trophy': Icons.emoji_events_rounded,
    'star': Icons.star_rounded,
    'nature': Icons.eco_rounded,
    'bike': Icons.directions_bike_rounded,
    'people': Icons.groups_rounded,
    'sun': Icons.wb_sunny_rounded,
    'night': Icons.dark_mode_rounded,
    'target': Icons.gps_fixed_rounded,
    'diamond': Icons.diamond_rounded,
  };

  static const Map<String, String> labels = <String, String>{
    'medal': 'Medalla',
    'hiking': 'Caminata',
    'route': 'Ruta',
    'place': 'Lugar',
    'explore': 'Explorar',
    'warning': 'Alerta',
    'shield': 'Escudo',
    'trophy': 'Trofeo',
    'star': 'Estrella',
    'nature': 'Naturaleza',
    'bike': 'Bicicleta',
    'people': 'Comunidad',
    'sun': 'Sol',
    'night': 'Noche',
    'target': 'Objetivo',
    'diamond': 'Diamante',
  };

  static String keyFor(String value, {String code = ''}) {
    if (options.containsKey(value)) return value;
    final normalized = code.toUpperCase();
    if (normalized.contains('ALERTA')) return 'warning';
    if (normalized.contains('NODO') || normalized.contains('PUNTO')) {
      return 'place';
    }
    if (normalized.contains('RUTA')) return 'route';
    if (normalized.contains('KM')) return 'hiking';
    return switch (value) {
      '🥾' => 'hiking',
      '⚠️' || '🚨' => 'warning',
      '📍' => 'place',
      '🧭' || '🗺️' => 'explore',
      '🌱' => 'nature',
      '🏆' || '👑' => 'trophy',
      '🚴' => 'bike',
      '🛡️' => 'shield',
      '🤝' => 'people',
      '🌅' => 'sun',
      '🌙' => 'night',
      '🎯' => 'target',
      '💎' => 'diamond',
      '🌟' => 'star',
      _ => 'medal',
    };
  }

  static IconData forValue(String value, {String code = ''}) =>
      options[keyFor(value, code: code)]!;
}
