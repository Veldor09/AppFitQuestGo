import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// Variantes visuales del boton del sistema de diseno (`.fq-button--*`).
enum FqButtonVariant { primary, secondary, danger, ghost }

/// Boton unico del sistema. Replica `.fq-button` y sus modificadores.
///
/// Una sola implementacion cubre los cuatro estilos para respetar DRY y que
/// cualquier ajuste de marca ocurra en un solo sitio (SRP + OCP: se agregan
/// variantes sin tocar las pantallas que ya lo usan).
class FqButton extends StatelessWidget {
  const FqButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = FqButtonVariant.primary,
    this.icon,
    this.expand = true,
    this.loading = false,
    this.dense = false,
  });

  const FqButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
    this.dense = false,
  }) : variant = FqButtonVariant.primary;

  const FqButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
    this.dense = false,
  }) : variant = FqButtonVariant.secondary;

  const FqButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
    this.dense = false,
  }) : variant = FqButtonVariant.danger;

  const FqButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
    this.dense = false,
  }) : variant = FqButtonVariant.ghost;

  final String label;
  final VoidCallback? onPressed;
  final FqButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool loading;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final _ButtonSkin skin = _skinFor(variant);
    final bool disabled = onPressed == null || loading;

    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (loading)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: skin.fg),
          )
        else if (icon != null) ...<Widget>[
          Icon(icon, size: 15, color: skin.fg),
          const SizedBox(width: 7),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: skin.fg,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: skin.bg,
          borderRadius: FqRadius.allButton,
          border: skin.border == null
              ? null
              : Border.fromBorderSide(skin.border!),
          boxShadow: disabled ? null : skin.shadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: FqRadius.allButton,
            onTap: disabled ? null : onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 13,
                vertical: dense ? 8 : 11,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  _ButtonSkin _skinFor(FqButtonVariant v) {
    switch (v) {
      case FqButtonVariant.primary:
        return const _ButtonSkin(
          bg: FqColors.volt,
          fg: FqColors.primaryInk,
          shadow: <BoxShadow>[
            BoxShadow(
              color: Color(0x337CAA09),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        );
      case FqButtonVariant.secondary:
        return const _ButtonSkin(
          bg: FqColors.white,
          fg: FqColors.ink,
          border: BorderSide(color: Color(0xFFCFD6CD)),
        );
      case FqButtonVariant.danger:
        return const _ButtonSkin(bg: FqColors.risk, fg: FqColors.white);
      case FqButtonVariant.ghost:
        return const _ButtonSkin(bg: Colors.transparent, fg: FqColors.ink);
    }
  }
}

class _ButtonSkin {
  const _ButtonSkin({
    required this.bg,
    required this.fg,
    this.border,
    this.shadow,
  });

  final Color bg;
  final Color fg;
  final BorderSide? border;
  final List<BoxShadow>? shadow;
}
