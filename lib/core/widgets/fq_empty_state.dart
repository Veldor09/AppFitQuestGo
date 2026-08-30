import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Estado vacio reutilizable. Las pantallas de maqueta lo muestran donde iria
/// una lista/tabla alimentada por el backend, dejando claro que no hay datos
/// "quemados" sino que el contenido llegara de la API cuando exista.
class FqEmptyState extends StatelessWidget {
  const FqEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.dense = false,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final bool dense;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(dense ? 20 : 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: FqColors.listIconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: FqColors.night, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: FqColors.ink,
              ),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.5,
                  color: FqColors.muted,
                ),
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: 14),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
