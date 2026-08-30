import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Barra de progreso segmentada del asistente de registro (`.fq-progress-steps`).
class FqProgressSteps extends StatelessWidget {
  const FqProgressSteps({
    super.key,
    required this.total,
    required this.completados,
  });

  final int total;
  final int completados;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: Row(
        children: List<Widget>.generate(total, (int i) {
          final bool activo = i < completados;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 5),
              height: 3,
              decoration: BoxDecoration(
                color: activo ? FqColors.voltDark : FqColors.progressTrack,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          );
        }),
      ),
    );
  }
}
