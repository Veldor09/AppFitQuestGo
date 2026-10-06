import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/core/widgets/campo_texto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_api.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_app_header.dart';

/// Segundo paso de recuperacion: el usuario ya recibio el codigo por correo
/// (ver [OlvideContrasenaScreen]) y lo escribe junto con la contrasena nueva.
class RestablecerContrasenaScreen extends StatefulWidget {
  const RestablecerContrasenaScreen({super.key, required this.email, this.api});

  final String email;

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final AuthApi? api;

  @override
  State<RestablecerContrasenaScreen> createState() =>
      _RestablecerContrasenaScreenState();
}

class _RestablecerContrasenaScreenState
    extends State<RestablecerContrasenaScreen> {
  late final AuthApi _api = widget.api ?? AuthApi();

  final TextEditingController _codigo = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _cargando = false;
  bool _forzarError = false;

  @override
  void dispose() {
    _codigo.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _valido(AppLocalizations l10n) {
    return todoValido(<(String, List<Validador>)>[
      (_codigo.text, <Validador>[
        requerido(l10n.restablecerTitulo),
        (String v) =>
            v.trim().length == 6 ? null : l10n.restablecerCodigoLongitud,
      ]),
      (_password.text, <Validador>[
        requerido(l10n.restablecerValidacionContrasena),
        minCaracteres(8),
      ]),
    ]);
  }

  Future<void> _confirmar() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    if (!_valido(l10n)) {
      setState(() => _forzarError = true);
      notificarError(l10n.comunRevisaCampos);
      return;
    }
    setState(() => _cargando = true);
    try {
      await _api.restablecerContrasena(
        email: widget.email,
        codigo: _codigo.text.trim(),
        nuevaContrasena: _password.text,
      );
      if (!mounted) return;
      notificarExito(l10n.restablecerExito);
      Navigator.of(context)
        ..pop() // cierra RestablecerContrasenaScreen
        ..pop(); // cierra OlvideContrasenaScreen, vuelve a LoginScreen
    } on ApiException catch (e) {
      _fallar(
        e.statusCode == 401 ? l10n.restablecerCodigoInvalido : e.message,
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
              title: l10n.restablecerTitulo,
              subtitle: l10n.restablecerSubtitulo(widget.email),
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
                          label: l10n.restablecerCodigoLabel,
                          controller: _codigo,
                          keyboardType: TextInputType.number,
                          maxCaracteres: 6,
                          reglas: <Validador>[
                            requerido(l10n.restablecerTitulo),
                            (String v) => v.trim().length == 6
                                ? null
                                : l10n.restablecerCodigoLongitud,
                          ],
                          forzarError: _forzarError,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: FqGap.sm),
                        CampoTexto(
                          label: l10n.restablecerContrasenaNuevaLabel,
                          controller: _password,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const <String>[
                            AutofillHints.newPassword,
                          ],
                          forzarError: _forzarError,
                          onSubmitted: (_) => _confirmar(),
                          reglas: <Validador>[
                            requerido(l10n.restablecerValidacionContrasena),
                            minCaracteres(8),
                          ],
                        ),
                        const SizedBox(height: FqGap.xl),
                        FqButton.primary(
                          label: l10n.restablecerActualizarContrasena,
                          loading: _cargando,
                          onPressed: _cargando ? null : _confirmar,
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
