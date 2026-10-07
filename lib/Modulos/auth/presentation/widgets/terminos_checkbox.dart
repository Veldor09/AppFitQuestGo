import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/terminos_modal.dart';

/// Casilla de "Acepto los terminos y condiciones" con el enlace que abre el
/// modal legal. La comparten el registro de deportistas y el de empresas.
class TerminosCheckbox extends StatelessWidget {
  const TerminosCheckbox({
    super.key,
    required this.valor,
    required this.forzarError,
    required this.onChanged,
  });

  final bool valor;
  final bool forzarError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool mostrarError = forzarError && !valor;
    // El toggle y el enlace usan recognizers de texto independientes (no un
    // InkWell envolvente) para que tocar "terminos y condiciones" solo abra
    // el modal, sin alterar el estado de la casilla.
    final TapGestureRecognizer toggleRecognizer = TapGestureRecognizer()
      ..onTap = () => onChanged(!valor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: valor,
                onChanged: (bool? v) => onChanged(v ?? false),
                activeColor: FqColors.voltDark,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: mostrarError
                    ? const BorderSide(color: FqColors.risk, width: 1.4)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: FqColors.muted,
                    ),
                    children: <InlineSpan>[
                      TextSpan(
                        text: l10n.registroAceptoPrefijo,
                        recognizer: toggleRecognizer,
                      ),
                      TextSpan(
                        text: l10n.registroTerminosYCondiciones,
                        style: const TextStyle(
                          color: FqColors.river,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => TerminosModal.mostrar(context),
                      ),
                      TextSpan(
                        text: l10n.registroAceptoSufijo,
                        recognizer: toggleRecognizer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (mostrarError)
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 2),
            child: Text(
              l10n.registroTerminosErrorInline,
              style: const TextStyle(fontSize: 10, color: FqColors.risk),
            ),
          ),
      ],
    );
  }
}
