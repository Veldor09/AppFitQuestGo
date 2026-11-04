import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

({Color arriba, Color abajo}) coloresDificultad(String dificultad) {
  switch (dificultad) {
    case 'facil':
      return (arriba: const Color(0xFF7BE495), abajo: const Color(0xFF1FA64F));
    case 'dificil':
      return (arriba: const Color(0xFFFF8A65), abajo: const Color(0xFFE0362C));
    default:
      return (arriba: const Color(0xFFFFE082), abajo: const Color(0xFFF2A516));
  }
}

class IconoDificultad extends StatelessWidget {
  const IconoDificultad({super.key, required this.dificultad, this.size = 24});

  final String dificultad;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = coloresDificultad(dificultad).abajo;
    return Icon(
      switch (dificultad) {
        'facil' => Icons.terrain_rounded,
        'dificil' => Icons.landscape_rounded,
        _ => Icons.hiking_rounded,
      },
      key: ValueKey<String>('icono-dificultad-$dificultad'),
      size: size,
      color: color,
    );
  }
}

class EtiquetaDificultad extends StatelessWidget {
  const EtiquetaDificultad({
    super.key,
    required this.dificultad,
    required this.texto,
  });

  final String dificultad;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final Color color = coloresDificultad(dificultad).abajo;
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 10, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconoDificultad(dificultad: dificultad, size: 18),
          const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color.lerp(color, FqColors.ink, 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
