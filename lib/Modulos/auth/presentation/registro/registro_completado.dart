import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_brand_mark.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';

/// APP-08 · Registro completado (`.fq-center-state`).
/// Se muestra tras crear la cuenta; el CTA cierra el asistente y deja ver la
/// experiencia principal que ya decidio `_RootGate`.
class RegistroCompletadoScreen extends StatelessWidget {
  const RegistroCompletadoScreen({super.key, required this.onContinuar});

  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.24),
            radius: 0.5,
            colors: <Color>[Color(0x2EB9F227), Color(0x00B9F227)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kAuthContentMaxWidth),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const FqBrandMark(size: 66, iconData: Icons.check),
                  const SizedBox(height: 17),
                  const Text(
                    'Todo listo!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: FqColors.ink,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Tu perfil esta preparado. Ya puedes explorar FitQuest Go.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.55,
                      color: FqColors.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 200),
                    child: FqButton.primary(
                      label: 'Explorar el mapa',
                      expand: false,
                      onPressed: onContinuar,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
