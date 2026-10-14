import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// El fondo casi blanco con sombra de lo que flota sobre el mapa de Home: la
/// barra de busqueda, la campana, el cuadro "Cerca de ti".
BoxDecoration decoracionFlotante({required double radius}) {
  return BoxDecoration(
    color: FqColors.white.withValues(alpha: .97),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Color(0x1F13233F), blurRadius: 18, offset: Offset(0, 5)),
    ],
  );
}
