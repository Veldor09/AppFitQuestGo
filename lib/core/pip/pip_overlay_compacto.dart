import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Barra superior ultracompacta para la ventana flotante (Picture-in-Picture).
/// Muestra solo el estado relevante (distancia, rumbo, icono) con máxima legibilidad.
class PipOverlayCompacto extends StatelessWidget {
  const PipOverlayCompacto({
    super.key,
    required this.texto,
    required this.icono,
    required this.color,
    this.distancia,
    this.tiempo,
  });

  final String texto;
  final IconData icono;
  final Color color;
  final String? distancia;
  final String? tiempo;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 6,
      left: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.8,
          ),
          boxShadow: FqColors.softShadow,
        ),
        child: Row(
          children: <Widget>[
            Icon(icono, size: 14, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (distancia != null) ...<Widget>[
              const SizedBox(width: 4),
              Text(
                distancia!,
                style: const TextStyle(
                  color: FqColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (tiempo != null) ...<Widget>[
              const SizedBox(width: 4),
              Text(
                '· $tiempo',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

