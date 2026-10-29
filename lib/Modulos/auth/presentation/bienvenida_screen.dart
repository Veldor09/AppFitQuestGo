import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/biometria/biometria_servicio.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_brand_mark.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/login_screen.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/registro_flujo.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro_empresa_screen.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/auth_layout.dart';

/// APP-02 · Bienvenida.
/// Punto de entrada sin sesión: permite iniciar con huella digital si ya está
/// configurada, o elegir entre crear cuenta e iniciar sesión manualmente.
class BienvenidaScreen extends StatefulWidget {
  const BienvenidaScreen({super.key});

  @override
  State<BienvenidaScreen> createState() => _BienvenidaScreenState();
}

class _BienvenidaScreenState extends State<BienvenidaScreen> {
  bool _tieneBiometria = false;
  bool _cargandoBiometria = false;
  String? _nombreBio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revisarBiometria();
    });
  }

  Future<void> _revisarBiometria() async {
    final AuthRepositorio auth = AuthScope.read(context);
    final bool soporteBio =
        await BiometriaServicio.instancia.dispositivoSoportado;
    if (!soporteBio) return;

    final bool tiene = await auth.tieneCredencialBiometrica();
    if (!mounted) return;

    if (tiene) {
      final String? nombre = await auth.obtenerNombreBiometrico();
      if (mounted) {
        setState(() {
          _tieneBiometria = true;
          _nombreBio = nombre;
        });
      }
    }
  }

  Future<void> _iniciarConHuella() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final AuthRepositorio auth = AuthScope.read(context);
    final bool verificado = await BiometriaServicio.instancia.autenticar(
      motivo: l10n.bioMotivoBienvenida,
    );
    if (!verificado) return;

    setState(() => _cargandoBiometria = true);
    try {
      await auth.iniciarSesionConBiometria();
      if (!mounted) return;
      notificarExito(l10n.loginExito);
    } on ApiException catch (e) {
      if (mounted) {
        notificarError(
          e.statusCode == 401 ? l10n.loginCredencialesIncorrectas : e.message,
        );
      }
    } catch (_) {
      if (mounted) notificarError(l10n.loginErrorConexion);
    } finally {
      if (mounted) setState(() => _cargandoBiometria = false);
    }
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
          const SizedBox(height: 40),
          const Spacer(),

          if (_tieneBiometria) ...<Widget>[
            FqButton.primary(
              label: _nombreBio != null
                  ? l10n.bioIngresarComo(_nombreBio!)
                  : l10n.bioIngresar,
              icon: Icons.fingerprint_rounded,
              loading: _cargandoBiometria,
              onPressed: _iniciarConHuella,
            ),
            const SizedBox(height: FqGap.md),
            FqButton.secondary(
              label: l10n.comunIniciarSesion,
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
              ),
            ),
            const SizedBox(height: FqGap.md),
            FqButton(
              variant: FqButtonVariant.ghost,
              label: l10n.comunCrearCuenta,
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const RegistroFlujoScreen(),
                ),
              ),
            ),
          ] else ...<Widget>[
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
          ],

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
