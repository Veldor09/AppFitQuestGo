import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Barra superior oscura del panel (`.fq-admin-header`).
class AdminTopBar extends StatelessWidget {
  const AdminTopBar({
    super.key,
    required this.title,
    required this.userInitials,
    this.onToggleSidebar,
  });

  final String title;
  final String userInitials;
  final VoidCallback? onToggleSidebar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      color: FqColors.night,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          if (onToggleSidebar != null)
            IconButton(
              onPressed: onToggleSidebar,
              icon: const Icon(Icons.menu, size: 18),
              color: FqColors.white,
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          const SizedBox(width: 4),
          Container(
            width: 23,
            height: 23,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FqColors.volt,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Text(
              'FQ',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: FqColors.night,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: FqColors.white,
              ),
            ),
          ),
          _HeaderIcon(icon: Icons.search, onTap: () {}),
          _HeaderIcon(icon: Icons.notifications_none, onTap: () {}, dot: true),
          const SizedBox(width: 10),
          Container(
            width: 29,
            height: 29,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FqColors.volt,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              userInitials,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: FqColors.night,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap, this.dot = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 17),
          color: FqColors.white,
          splashRadius: 17,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        ),
        if (dot)
          const Positioned(
            top: 7,
            right: 6,
            child: _Dot(),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: FqColors.risk,
        shape: BoxShape.circle,
        border: Border.all(color: FqColors.white),
      ),
    );
  }
}
