import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// Tarjeta contenedora del panel de administracion (`.fq-admin-panel`).
///
/// Opcionalmente pinta la cabecera con titulo y una accion a la derecha, tal
/// como el selector `.fq-admin-panel > div:first-child` del sistema original.
class FqPanel extends StatelessWidget {
  const FqPanel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = EdgeInsets.zero,
    this.clip = true,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (title != null)
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: FqColors.border)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: FqColors.ink,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        Padding(padding: padding, child: child),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: FqRadius.allXl,
        border: Border.all(color: FqColors.border),
        boxShadow: FqColors.panelShadow,
      ),
      child: clip
          ? ClipRRect(borderRadius: FqRadius.allXl, child: body)
          : body,
    );
  }
}
