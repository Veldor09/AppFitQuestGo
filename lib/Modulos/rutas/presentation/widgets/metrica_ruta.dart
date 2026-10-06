import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Un dato de la grabacion (tiempo, distancia, ritmo): valor grande con su
/// unidad al lado y la etiqueta debajo.
class MetricaRuta extends StatelessWidget {
  const MetricaRuta({
    super.key,
    required this.etiqueta,
    required this.valor,
    this.unidad,
    this.compacta = false,
  });

  final String etiqueta;
  final String valor;
  final String? unidad;

  /// Tamano reducido, para el panel que se superpone al mapa mientras se graba.
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              valor,
              style: TextStyle(
                fontSize: compacta ? 19 : 26,
                fontWeight: FontWeight.w800,
                color: FqColors.ink,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            if (unidad != null) ...<Widget>[
              const SizedBox(width: 3),
              Text(
                unidad!,
                style: TextStyle(
                  fontSize: compacta ? 10 : 12,
                  fontWeight: FontWeight.w700,
                  color: FqColors.muted,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          etiqueta,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compacta ? 10 : 11,
            fontWeight: FontWeight.w700,
            color: FqColors.muted,
          ),
        ),
      ],
    );
  }
}
