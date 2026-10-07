import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_brand_mark.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/login_screen.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/registro_flujo.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro_empresa_screen.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/auth_layout.dart';

/// APP-02 · Bienvenida.
/// Punto de entrada sin sesion: elegir entre crear cuenta o iniciar sesion.
class BienvenidaScreen extends StatelessWidget {
  const BienvenidaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return AuthLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: AuthHero(
              leading: const FqBrandMark(),
              tagLabel: l10n.bienvenidaTagline,
              title: l10n.bienvenidaTitulo,
              subtitle: l10n.bienvenidaSubtitulo,
            ),
          ),
          const SizedBox(height: 40),
          const Spacer(),
          FqButton.primary(
            label: l10n.comunCrearCuenta,
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const RegistroFlujoScreen(),
              ),
            ),
          ),
          const SizedBox(height: FqGap.md),
          FqButton.secondary(
            label: l10n.comunIniciarSesion,
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            ),
          ),
          const SizedBox(height: FqGap.xs),
          TextButton(
            key: const ValueKey<String>('soy-comercio'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const RegistroEmpresaScreen(),
              ),
            ),
            child: Text(
              l10n.bienvenidaSoyComercio,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: FqColors.river,
              ),
            ),
          ),
          const SizedBox(height: FqGap.xs),
          Center(
            child: Text(
              l10n.bienvenidaAvisoLegal,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: Color(0xFF67726D)),
            ),
          ),
        ],
      ),
    );
  }
}
