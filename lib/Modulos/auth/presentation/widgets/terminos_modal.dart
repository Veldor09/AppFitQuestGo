import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// Modal de Terminos y condiciones que se muestra desde el registro.
///
/// El texto es un contenido base: debe ser revisado y reemplazado por el
/// equipo legal antes de publicar la app. Esto aplica por igual a las 3
/// traducciones (es/en/pt_BR): ninguna es definitiva.
class TerminosModal {
  const TerminosModal._();

  static Future<void> mostrar(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n.comunCerrar,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 190),
      pageBuilder: (_, _, _) => const _TerminosDialog(),
      transitionBuilder: (_, Animation<double> anim, _, Widget child) {
        final double t = Curves.easeOutCubic.transform(anim.value);
        return FadeTransition(
          opacity: anim,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: ColoredBox(
              color: const Color(0x5A0B1220),
              child: Transform.scale(scale: 0.95 + 0.05 * t, child: child),
            ),
          ),
        );
      },
    );
  }
}

class _TerminosDialog extends StatelessWidget {
  const _TerminosDialog();

  static List<(String, String)> _secciones(AppLocalizations l10n) =>
      <(String, String)>[
        (l10n.terminosSeccion1Titulo, l10n.terminosSeccion1Texto),
        (l10n.terminosSeccion2Titulo, l10n.terminosSeccion2Texto),
        (l10n.terminosSeccion3Titulo, l10n.terminosSeccion3Texto),
        (l10n.terminosSeccion4Titulo, l10n.terminosSeccion4Texto),
        (l10n.terminosSeccion5Titulo, l10n.terminosSeccion5Texto),
        (l10n.terminosSeccion6Titulo, l10n.terminosSeccion6Texto),
      ];

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
          child: Material(
            color: FqColors.white,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          l10n.terminosTitulo,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: FqColors.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, size: 18),
                        color: FqColors.muted,
                        splashRadius: 18,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: FqColors.border),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (final (String titulo, String texto)
                            in _secciones(l10n))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  titulo,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: FqColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  texto,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.5,
                                    color: FqColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: FqColors.border),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FqButton.primary(
                    label: l10n.terminosEntendido,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
