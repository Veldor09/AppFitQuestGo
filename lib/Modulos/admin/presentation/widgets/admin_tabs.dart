import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Pestanas de segmento del panel (`.fq-admin-tabs`).
class AdminTabs extends StatelessWidget {
  const AdminTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FqColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: <Widget>[
          for (int i = 0; i < tabs.length; i++)
            _Tab(
              label: tabs[i],
              active: i == index,
              onTap: () => onChanged(i),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? const Color(0xFFEDF3E7) : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? FqColors.night : FqColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}
