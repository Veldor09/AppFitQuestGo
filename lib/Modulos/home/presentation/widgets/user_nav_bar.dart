import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

class UserNavBar extends StatelessWidget {
  const UserNavBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<({IconData icon, String label})> items =
        <({IconData icon, String label})>[
      (icon: Icons.map_outlined, label: l10n.navMapa),
      (icon: Icons.route_outlined, label: l10n.rutasTitulo),
      (icon: Icons.add_rounded, label: l10n.navCrear),
      (icon: Icons.auto_awesome_outlined, label: l10n.comunEventos),
      (icon: Icons.person_outline_rounded, label: l10n.navPerfil),
    ];
    return Container(
      height: 62 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: FqColors.white.withValues(alpha: .96),
        border: const Border(top: BorderSide(color: FqColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          for (int i = 0; i < items.length; i++)
            _NavItem(
              icon: items[i].icon,
              label: items[i].label,
              selected: i == currentIndex,
              onTap: () => onSelect(i),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? FqColors.voltDark : FqColors.muted;
    return InkResponse(
      onTap: onTap,
      radius: 34,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 23, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? FqColors.night : color,
                fontSize: 9,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
