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
import 'package:fit_quest_go/Modulos/auth/presentation/restablecer_contrasena_screen.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_app_header.dart';

/// Primer paso de recuperacion: pedir el correo. Siempre avanza al siguiente
/// paso (exista o no la cuenta) para no revelar que correos estan registrados.
class OlvideContrasenaScreen extends StatefulWidget {
  const OlvideContrasenaScreen({super.key, this.api});

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final AuthApi? api;

  @override
  State<OlvideContrasenaScreen> createState() =>
      _OlvideContrasenaScreenState();
}

class _OlvideContrasenaScreenState extends State<OlvideContrasenaScreen> {
  late final AuthApi _api = widget.api ?? AuthApi();

  final TextEditingController _email = TextEditingController();

  bool _cargando = false;
  bool _forzarError = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    if (!todoValido(<(String, List<Validador>)>[(_email.text, reglasCorreo())])) {
      setState(() => _forzarError = true);
      notificarError(l10n.olvideCorreoInvalido);
      return;
    }
    setState(() => _cargando = true);
    try {
      await _api.olvideContrasena(email: _email.text.trim());
      if (!mounted) return;
      notificarInfo(l10n.olvideCodigoEnviado);
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => RestablecerContrasenaScreen(
            email: _email.text.trim(),
            api: widget.api,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      notificarError(e.message);
    } catch (_) {
      if (!mounted) return;
      notificarError(l10n.loginErrorConexion);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
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
              title: l10n.olvideTitulo,
              subtitle: l10n.olvideSubtitulo,
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
                          textInputAction: TextInputAction.done,
                          autofillHints: const <String>[AutofillHints.email],
                          forzarError: _forzarError,
                          onSubmitted: (_) => _enviar(),
                          reglas: reglasCorreo(),
                        ),
                        const SizedBox(height: FqGap.xl),
                        FqButton.primary(
                          label: l10n.olvideEnviarCodigo,
                          loading: _cargando,
                          onPressed: _cargando ? null : _enviar,
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
