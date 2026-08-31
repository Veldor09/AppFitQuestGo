import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// Lienzo comun de las pantallas de autenticacion (`.fq-auth`).
///
/// Reproduce el fondo del sistema de diseno: degradado diagonal claro con un
/// halo lima en la esquina superior derecha. El contenido se limita al ancho de
/// un movil y se centra; si no cabe, hace scroll, y el patron
/// `ConstrainedBox(minHeight) + IntrinsicHeight` permite que un hijo con
/// `Spacer` reparta el espacio vertical (hero arriba, acciones abajo).
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(18, 26, 18, 18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.7, -1),
            end: Alignment(0.7, 1),
            colors: <Color>[
              Color(0xFFF9FBF5),
              Color(0xFFF9FBF5),
              Color(0xFFEEF4E6),
            ],
            stops: <double>[0.0, 0.62, 0.62],
          ),
        ),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.78, -0.66),
                    radius: 0.55,
                    colors: <Color>[Color(0x73B9F227), Color(0x00B9F227)],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: kAuthContentMaxWidth,
                          ),
                          child: IntrinsicHeight(
                            child: Padding(padding: padding, child: child),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encabezado tipo "hero" de Bienvenida/Login: etiqueta + titulo + bajada.
class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    required this.title,
    this.tagLabel,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? tagLabel;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (leading != null) ...<Widget>[
          leading!,
          const SizedBox(height: 12),
        ],
        if (tagLabel != null) ...<Widget>[
          _LimeTag(tagLabel!),
          const SizedBox(height: FqGap.md),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 29,
            height: 1.03,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
            color: FqColors.ink,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 12,
              height: 1.55,
              color: Color(0xFF5D6963),
            ),
          ),
        ],
      ],
    );
  }
}

class _LimeTag extends StatelessWidget {
  const _LimeTag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: FqColors.volt,
        borderRadius: FqRadius.allPill,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: Color(0xFF20320D),
        ),
      ),
    );
  }
}
