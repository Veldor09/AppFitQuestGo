import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Encabezado interno de pantalla (`.fq-app-header`): icono + titulo + subtitulo
/// y un boton de acciones a la derecha. Se usa en el asistente de registro.
class FqAppHeader extends StatelessWidget {
  const FqAppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.arrow_back,
    this.onLeading,
    this.onMore,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onLeading;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 47),
      decoration: const BoxDecoration(
        color: Color(0xF7FFFFFF),
        border: Border(bottom: BorderSide(color: Color(0xFFEDF0EC))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      child: Row(
        children: <Widget>[
          if (onLeading != null)
            _IconBtn(icon: icon, onTap: onLeading!)
          else
            Icon(icon, size: 18, color: FqColors.ink),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: FqColors.ink,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 9, color: FqColors.muted),
                  ),
              ],
            ),
          ),
          _IconBtn(
            icon: Icons.more_horiz,
            onTap: onMore ?? () {},
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: FqColors.ink),
      ),
    );
  }
}
