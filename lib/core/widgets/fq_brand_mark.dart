import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Marca grafica de FitQuest Go: cuadrado lima ligeramente rotado con el icono
/// de brujula/actividad. Replica `.fq-brand-mark` y `.fq-center-state__icon`.
class FqBrandMark extends StatelessWidget {
  const FqBrandMark({super.key, this.size = 52, this.iconData = Icons.explore});

  final double size;
  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.0698, // ~ -4 grados
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: FqColors.volt,
          borderRadius: BorderRadius.circular(size * 0.33),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x307AA707),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Icon(iconData, size: size * 0.5, color: FqColors.night),
      ),
    );
  }
}
