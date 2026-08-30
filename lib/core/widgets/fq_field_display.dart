import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// Version de solo lectura de `.fq-field`: etiqueta + valor.
///
/// Se emplea en las pantallas de maqueta (sin backend) y en los detalles, donde
/// el dato se muestra pero no se edita. Si [value] es `null` se pinta un guion
/// para dejar claro que el dato provendra del backend.
class FqFieldDisplay extends StatelessWidget {
  const FqFieldDisplay({
    super.key,
    required this.label,
    this.value,
    this.multiline = false,
  });

  final String label;
  final String? value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: multiline ? 66 : 46),
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: FqRadius.allMd,
        border: Border.all(color: FqColors.fieldBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: multiline
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: FqColors.fieldLabel,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value ?? '—',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: value == null ? FqColors.muted : FqColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
