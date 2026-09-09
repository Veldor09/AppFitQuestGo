import 'package:flutter/material.dart';

/// Paleta de la marca FitQuest Go.
///
/// Los valores replican las variables `--fq-*` del sistema de diseno original
/// (documento "FitQuest Go - UX system"). Se centralizan aqui para que ninguna
/// pantalla escriba colores "a mano" y el tema sea la unica fuente de verdad.
abstract final class FqColors {
  const FqColors._();

  // --- Base ---
  static const Color night = Color(0xFF13233F);
  static const Color night2 = Color(0xFF1D3154);
  static const Color ink = Color(0xFF17211E);
  static const Color muted = Color(0xFF67726D);

  // --- Acentos ---
  static const Color volt = Color(0xFFB9F227);
  static const Color voltDark = Color(0xFF82B407);
  static const Color river = Color(0xFF0875D1);
  static const Color trail = Color(0xFF057A71);
  static const Color risk = Color(0xFFE85D3F);
  static const Color amber = Color(0xFFDFA51C);
  static const Color pink = Color(0xFFC83279);
  static const Color purple = Color(0xFF7058D9);

  // --- Superficies ---
  static const Color cloud = Color(0xFFF4F6F2);
  static const Color paper = Color(0xFFFBFCF8);
  static const Color stone = Color(0xFFD8DED6);
  static const Color border = Color(0xFFDFE4DD);
  static const Color white = Color(0xFFFFFFFF);

  /// Fondo de las pantallas del panel de administracion.
  static const Color adminBg = Color(0xFFF2F4F0);

  // --- Campos / inputs ---
  static const Color fieldBorder = Color(0xFFDCE2DA);
  static const Color fieldLabel = Color(0xFF76817B);
  static const Color searchBg = Color(0xFFEFF2ED);
  static const Color searchBorder = Color(0xFFE2E6E0);

  // --- Estados de seleccion ---
  static const Color choiceSelectedBg = Color(0xFFF2FADF);
  static const Color chipSelectedBg = Color(0xFFEEF9D4);
  static const Color chipSelectedInk = Color(0xFF25330F);
  static const Color primaryInk = Color(0xFF18240C);

  // --- Listas del panel admin ---
  static const Color listIconBg = Color(0xFFEDF2E9);
  static const Color rowHover = Color(0xFFF8FAF6);
  static const Color queueBg = Color(0xFFFBFCF9);

  // --- Nota / evidencia ---
  static const Color evidenceBg = Color(0xFFEDF7E9);
  static const Color evidenceBorder = Color(0xFFD1E8CA);
  static const Color infoNoteBg = Color(0xFFEAF4FF);
  static const Color infoNoteInk = Color(0xFF3E5D7C);

  // --- Progreso / toggles ---
  static const Color progressTrack = Color(0xFFE0E5DE);
  static const Color toggleOff = Color(0xFFCFD6CF);

  static const List<BoxShadow> softShadow = <BoxShadow>[
    BoxShadow(color: Color(0x14101828), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x2613233F), blurRadius: 22, offset: Offset(0, 12)),
  ];

  static const List<BoxShadow> panelShadow = <BoxShadow>[
    BoxShadow(color: Color(0x0B13233F), blurRadius: 14, offset: Offset(0, 3)),
  ];
}
