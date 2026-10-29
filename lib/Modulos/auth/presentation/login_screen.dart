import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/biometria/biometria_servicio.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/core/widgets/campo_texto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/olvide_contrasena_screen.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_app_header.dart';

/// APP-03 · Login. Autentica contra `POST /auth/inicio-sesion` mediante
/// [AuthRepositorio]. Permite ingreso tradicional con email/contraseña
/// o ingreso rápido con huella digital si ya fue configurada.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _cargando = false;
  bool _cargandoBiometria = false;
  bool _forzarError = false;

  bool _tieneBiometria = false;
  String? _emailBio;
  String? _nombreBio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarBiometria();
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _verificarBiometria() async {
    final AuthRepositorio auth = AuthScope.read(context);
    final bool soporteBio =
        await BiometriaServicio.instancia.dispositivoSoportado;
    if (!soporteBio) return;

    final bool tieneCredencial = await auth.tieneCredencialBiometrica();
    if (!mounted) return;

    if (tieneCredencial) {
      final String? email = await auth.obtenerEmailBiometrico();
      final String? nombre = await auth.obtenerNombreBiometrico();
      if (mounted) {
        setState(() {
          _tieneBiometria = true;
          _emailBio = email;
          _nombreBio = nombre;
          if (email != null && _email.text.isEmpty) {
            _email.text = email;
          }
        });
      }
    }
  }

  Future<void> _iniciarConHuella() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final AuthRepositorio auth = AuthScope.read(context);
    final bool verificado = await BiometriaServicio.instancia.autenticar(
      motivo: 'Coloca tu huella para iniciar sesión en FitQuest Go',
    );
    if (!verificado) return;

    setState(() => _cargandoBiometria = true);
    try {
      await auth.iniciarSesionConBiometria();
      if (!mounted) return;
      notificarExito(l10n.loginExito);
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      _fallar(
        e.statusCode == 401 ? l10n.loginCredencialesIncorrectas : e.message,
      );
    } catch (_) {
      _fallar(l10n.loginErrorConexion);
    } finally {
      if (mounted) setState(() => _cargandoBiometria = false);
    }
  }

  bool _valido(AppLocalizations l10n) {
    return todoValido(<(String, List<Validador>)>[
      (_email.text, <Validador>[
        requerido(l10n.validacionCorreoObligatorio),
        formatoCorreo,
      ]),
      (_password.text, <Validador>[requerido(l10n.loginValidacionContrasena)]),
    ]);
  }

  Future<void> _iniciar() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final AuthRepositorio auth = AuthScope.read(context);
    FocusScope.of(context).unfocus();
    if (!_valido(l10n)) {
      setState(() => _forzarError = true);
      notificarError(l10n.comunRevisaCampos);
      return;
    }
    setState(() => _cargando = true);
    try {
      final String correoIngresado = _email.text.trim();
      final String contrasenaIngresada = _password.text;

      await auth.iniciarSesion(
        email: correoIngresado,
        contrasena: contrasenaIngresada,
      );

      if (!mounted) return;

      // Preguntar si desea activar inicio biométrico si el dispositivo lo soporta
      final bool soporteBio =
          await BiometriaServicio.instancia.dispositivoSoportado;
      if (mounted && soporteBio) {
        final bool yaActiva = await auth.tieneCredencialBiometrica();
        final String? emailRegistrado = await auth.obtenerEmailBiometrico();

        if (!yaActiva || emailRegistrado != correoIngresado) {
          if (!mounted) return;
          final bool? deseaActivar = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext ctx) => AlertDialog(
              backgroundColor: FqColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: <Widget>[
                  Icon(
                    Icons.fingerprint_rounded,
                    color: FqColors.night,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Ingreso con huella',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: FqColors.ink,
                    ),
                  ),
                ],
              ),
              content: const Text(
                '¿Deseas activar el ingreso con tu huella digital para que en el próximo inicio de sesión solo pongas tu huella en vez de escribir la contraseña?',
                style: TextStyle(fontSize: 14, color: FqColors.muted),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text(
                    'Ahora no',
                    style: TextStyle(color: FqColors.muted),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FqColors.night,
                    foregroundColor: FqColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Activar'),
                ),
              ],
            ),
          );

          if (deseaActivar == true && mounted) {
            final bool verificado =
                await BiometriaServicio.instancia.autenticar(
                  motivo:
                      'Verifica tu huella para habilitarla en tu cuenta',
                );
            if (verificado && mounted) {
              await auth.guardarCredencialBiometrica(
                email: correoIngresado,
                contrasena: contrasenaIngresada,
              );
              notificarExito('Inicio con huella digital configurado');
            }
          }
        }
      }

      if (!mounted) return;
      notificarExito(l10n.loginExito);
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      _fallar(
        e.statusCode == 401 ? l10n.loginCredencialesIncorrectas : e.message,
      );
    } catch (_) {
      _fallar(l10n.loginErrorConexion);
    }
  }

  void _fallar(String mensaje) {
    if (!mounted) return;
    setState(() => _cargando = false);
    notificarError(mensaje);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: FqColors.paper,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FqAppHeader(
              title: l10n.loginTitulo,
              subtitle: l10n.loginSubtitulo,
              onLeading: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    FqGap.xl,
                    24,
                    FqGap.xl,
                    FqGap.xl,
                  ),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: kAuthContentMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // Tarjeta de acceso rápido con huella si ya está guardada
                        if (_tieneBiometria) ...<Widget>[
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: FqColors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: FqColors.border),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: FqColors.night.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: FqColors.volt
                                            .withValues(alpha: 0.25),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.fingerprint_rounded,
                                        color: FqColors.night,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            _nombreBio != null
                                                ? '¡Hola, $_nombreBio!'
                                                : 'Ingreso rápido con huella',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: FqColors.ink,
                                            ),
                                          ),
                                          if (_emailBio != null)
                                            Text(
                                              _emailBio!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: FqColors.muted,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                FqButton.primary(
                                  label: 'Ingresar con huella',
                                  icon: Icons.fingerprint_rounded,
                                  loading: _cargandoBiometria,
                                  onPressed: _iniciarConHuella,
                                ),
                              ],
                            ),
                          ),
                          const Row(
                            children: <Widget>[
                              Expanded(child: Divider(color: FqColors.border)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'O con contraseña',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: FqColors.muted,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: FqColors.border)),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        CampoTexto(
                          label: l10n.comunCorreo,
                          controller: _email,
                          hintText: l10n.comunCorreoHint,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const <String>[AutofillHints.email],
                          forzarError: _forzarError,
                          reglas: <Validador>[
                            requerido(l10n.validacionCorreoObligatorio),
                            formatoCorreo,
                          ],
                        ),
                        const SizedBox(height: FqGap.sm),
                        CampoTexto(
                          label: l10n.comunContrasena,
                          controller: _password,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const <String>[
                            AutofillHints.password,
                          ],
                          forzarError: _forzarError,
                          onSubmitted: (_) => _iniciar(),
                          reglas: <Validador>[
                            requerido(l10n.loginValidacionContrasena),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => const OlvideContrasenaScreen(),
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: FqColors.river,
                            ),
                            child: Text(
                              l10n.loginOlvidasteContrasena,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: FqGap.xl),
                        FqButton.primary(
                          label: l10n.comunIniciarSesion,
                          loading: _cargando,
                          onPressed: _cargando ? null : _iniciar,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
