import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// Tonos de la etiqueta `.fq-tag--*`.
enum FqTagTone { neutral, dark, lime, green, amber, red, pink }

/// Etiqueta / chip de estado del sistema de diseno (`.fq-tag`).
class FqTag extends StatelessWidget {
  const FqTag(this.label, {super.key, this.tone = FqTagTone.neutral});

  final String label;
  final FqTagTone tone;

  @override
  Widget build(BuildContext context) {
    final _TagSkin skin = _skin(tone);
    return DecoratedBox(
      decoration: const BoxDecoration(borderRadius: FqRadius.allPill),
      child: Container(
        decoration: BoxDecoration(
          color: skin.bg,
          borderRadius: FqRadius.allPill,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: skin.fg,
            fontSize: 9,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  _TagSkin _skin(FqTagTone t) {
    switch (t) {
      case FqTagTone.neutral:
        return const _TagSkin(Color(0xFFEDF0EB), Color(0xFF5B6761));
      case FqTagTone.dark:
        return const _TagSkin(FqColors.night, FqColors.white);
      case FqTagTone.lime:
        return const _TagSkin(FqColors.volt, Color(0xFF20320D));
      case FqTagTone.green:
        return const _TagSkin(Color(0xFFD9F5E8), Color(0xFF08744D));
      case FqTagTone.amber:
        return const _TagSkin(Color(0xFFFFF0C9), Color(0xFF8B5A00));
      case FqTagTone.red:
        return const _TagSkin(Color(0xFFFFE2DC), Color(0xFFB83E28));
      case FqTagTone.pink:
        return const _TagSkin(Color(0xFFF9DBEA), Color(0xFFA22662));
    }
  }
}

class _TagSkin {
  const _TagSkin(this.bg, this.fg);
  final Color bg;
  final Color fg;
}
