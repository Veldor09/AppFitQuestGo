import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_brand_mark.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/login_screen.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/registro_flujo.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro_empresa_screen.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/auth_layout.dart';

/// APP-02 · Bienvenida.
/// Punto de entrada sin sesion: elegir entre crear cuenta o iniciar sesion.
class BienvenidaScreen extends StatelessWidget {
  const BienvenidaScreen({super.key});

  void _abrirInicio(BuildContext context) {
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
  }

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
          const SizedBox(height: 28),
          const Spacer(),
          FilledButton(
            onPressed: () => _abrirInicio(context),
            style: FilledButton.styleFrom(
              backgroundColor: FqColors.volt,
              foregroundColor: FqColors.primaryInk,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(l10n.comunIniciarSesion),
                const Icon(Icons.arrow_forward_rounded, size: 19),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const RegistroFlujoScreen(),
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: FqColors.ink,
              backgroundColor: FqColors.white,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: FqColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(l10n.comunCrearCuenta),
                const Icon(Icons.add_rounded, size: 20),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'OTRAS OPCIONES',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: FqColors.muted,
              ),
            ),
          ),
          OutlinedButton(
            key: const ValueKey<String>('soy-comercio'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const RegistroEmpresaScreen(),
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: FqColors.ink,
              backgroundColor: FqColors.white,
              minimumSize: const Size.fromHeight(48),
              side: const BorderSide(color: FqColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(l10n.bienvenidaSoyComercio),
                const Icon(Icons.north_east_rounded, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: InkWell(
              key: const ValueKey<String>('inicio-huella'),
              onTap: () => _abrirInicio(context),
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 26, vertical: 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.fingerprint_rounded,
                      size: 68,
                      color: FqColors.ink,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: FqColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: FqGap.sm),
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
