import 'package:flutter/widgets.dart';

/// Tokens de forma y ritmo del sistema de diseno FitQuest Go.
///
/// Mantener estos valores fuera de los widgets evita numeros magicos repartidos
/// por la UI y hace trivial ajustar el "look" en un solo lugar.
abstract final class FqRadius {
  const FqRadius._();

  static const Radius sm = Radius.circular(8);
  static const Radius md = Radius.circular(10);
  static const Radius lg = Radius.circular(12);
  static const Radius xl = Radius.circular(14);
  static const Radius button = Radius.circular(11);
  static const Radius pill = Radius.circular(999);

  static const BorderRadius allSm = BorderRadius.all(sm);
  static const BorderRadius allMd = BorderRadius.all(md);
  static const BorderRadius allLg = BorderRadius.all(lg);
  static const BorderRadius allXl = BorderRadius.all(xl);
  static const BorderRadius allButton = BorderRadius.all(button);
  static const BorderRadius allPill = BorderRadius.all(pill);
}

abstract final class FqGap {
  const FqGap._();

  static const double xs = 4;
  static const double sm = 7;
  static const double md = 9;
  static const double lg = 11;
  static const double xl = 14;
  static const double xxl = 18;
}

/// Ancho maximo del contenido en las pantallas de autenticacion (formato movil).
const double kAuthContentMaxWidth = 420;
