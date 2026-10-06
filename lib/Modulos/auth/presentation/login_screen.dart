import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/core/widgets/campo_texto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/olvide_contrasena_screen.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_app_header.dart';

/// APP-03 · Login. Autentica contra `POST /auth/inicio-sesion` mediante
/// [AuthRepositorio]. Los errores de campo se muestran en rojo bajo cada input;
/// el resultado del intento (exito / credenciales) se comunica por notificacion.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _cargando = false;
  bool _forzarError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
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
    FocusScope.of(context).unfocus();
    if (!_valido(l10n)) {
      setState(() => _forzarError = true);
      notificarError(l10n.comunRevisaCampos);
      return;
    }
    setState(() => _cargando = true);
    try {
      await AuthScope.read(context).iniciarSesion(
        email: _email.text.trim(),
        contrasena: _password.text,
      );
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
                    32,
                    FqGap.xl,
                    FqGap.xl,
                  ),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: kAuthContentMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
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
