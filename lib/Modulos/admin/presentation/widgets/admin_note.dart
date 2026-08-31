import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// Nota informativa con icono (`.fq-evidence` / `.fq-inspector-note`).
class AdminNote extends StatelessWidget {
  const AdminNote({
    super.key,
    required this.title,
    this.detail,
    this.icon = Icons.verified_outlined,
    this.tone = AdminNoteTone.positive,
  });

  final String title;
  final String? detail;
  final IconData icon;
  final AdminNoteTone tone;

  @override
  Widget build(BuildContext context) {
    final bool positive = tone == AdminNoteTone.positive;
    return Container(
      decoration: BoxDecoration(
        color: positive ? FqColors.evidenceBg : FqColors.infoNoteBg,
        borderRadius: FqRadius.allMd,
        border: Border.all(
          color: positive ? FqColors.evidenceBorder : const Color(0xFFCFE1F5),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            icon,
            size: 15,
            color: positive ? FqColors.voltDark : FqColors.infoNoteInk,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: FqColors.ink,
                  ),
                ),
                if (detail != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: const TextStyle(
                      fontSize: 9,
                      height: 1.45,
                      color: FqColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum AdminNoteTone { positive, info }
