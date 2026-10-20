import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// La marca "Destacado": es publicidad pagada y siempre se ve como tal.
class EtiquetaDestacado extends StatelessWidget {
  const EtiquetaDestacado({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      key: const ValueKey<String>('etiqueta-destacado'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: FqColors.amber,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.star_rounded, size: 13, color: FqColors.night),
          const SizedBox(width: 3),
          Text(
            l10n.patrocinioDestacado,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: FqColors.night,
            ),
          ),
        ],
      ),
    );
  }
}
