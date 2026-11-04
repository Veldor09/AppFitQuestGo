import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/biometria/biometria_servicio.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_brand_mark.dart';
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
          const SizedBox(height: 28),
          const Spacer(),
          FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            ),
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
          if (_tieneBiometria) ...<Widget>[
            const SizedBox(height: 12),
            Center(
              child: Tooltip(
                message: _nombreBio == null
                    ? l10n.bioIngresar
                    : l10n.bioIngresarComo(_nombreBio!),
                child: InkWell(
                  key: const ValueKey<String>('inicio-huella'),
                  onTap: _cargandoBiometria ? null : _iniciarConHuella,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 26,
                      vertical: 5,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (_cargandoBiometria)
                          const SizedBox(
                            width: 44,
                            height: 44,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        else
                          const Icon(
                            Icons.fingerprint_rounded,
                            size: 68,
                            color: FqColors.ink,
                          ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.comunIniciarSesion,
                          style: const TextStyle(
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
            ),
          ],
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
