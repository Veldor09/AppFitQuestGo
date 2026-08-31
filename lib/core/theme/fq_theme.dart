import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// Tema global de la aplicacion.
///
/// El sistema de diseno usa la familia tipografica *Inter*. No se empaqueta el
/// archivo de fuente para no inflar el bundle; se declara como preferida con
/// respaldos del sistema, de modo que si Inter esta disponible (habitual en
/// navegadores) se usa, y si no, se degrada con naturalidad.
ThemeData buildFqTheme() {
  const List<String> fontFallback = <String>[
    'Inter',
    'Segoe UI',
    'Roboto',
    'system-ui',
  ];

  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: FqColors.voltDark,
    primary: FqColors.volt,
    onPrimary: FqColors.primaryInk,
    secondary: FqColors.river,
    surface: FqColors.paper,
    onSurface: FqColors.ink,
    error: FqColors.risk,
    brightness: Brightness.light,
  );

  final TextTheme text = Typography.blackMountainView.apply(
    fontFamily: 'Inter',
    fontFamilyFallback: fontFallback,
    bodyColor: FqColors.ink,
    displayColor: FqColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: FqColors.paper,
    fontFamily: 'Inter',
    fontFamilyFallback: fontFallback,
    textTheme: text,
    dividerColor: FqColors.border,
    splashFactory: InkSparkle.splashFactory,
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: FqColors.night,
      contentTextStyle: TextStyle(color: FqColors.white, fontSize: 12),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: FqColors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: FqRadius.allMd,
        borderSide: BorderSide(color: FqColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: FqRadius.allMd,
        borderSide: BorderSide(color: FqColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: FqRadius.allMd,
        borderSide: BorderSide(color: FqColors.voltDark, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: FqRadius.allMd,
        borderSide: BorderSide(color: FqColors.risk),
      ),
    ),
  );
}
