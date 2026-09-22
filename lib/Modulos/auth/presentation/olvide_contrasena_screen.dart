import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/core/widgets/campo_texto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
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
    FocusScope.of(context).unfocus();
    if (!todoValido(<(String, List<Validador>)>[(_email.text, reglasCorreo())])) {
      setState(() => _forzarError = true);
      notificarError('Ingresa un correo valido');
      return;
    }
    setState(() => _cargando = true);
    try {
      await _api.olvideContrasena(email: _email.text.trim());
      if (!mounted) return;
      notificarInfo('Si el correo existe, te enviamos un codigo');
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
      notificarError('No se pudo conectar con el servidor. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FqColors.paper,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FqAppHeader(
              title: 'Recuperar acceso',
              subtitle: 'Te enviamos un codigo a tu correo',
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
                          label: 'Correo',
                          controller: _email,
                          hintText: 'tucorreo@dominio.com',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          autofillHints: const <String>[AutofillHints.email],
                          forzarError: _forzarError,
                          onSubmitted: (_) => _enviar(),
                          reglas: reglasCorreo(),
                        ),
                        const SizedBox(height: FqGap.xl),
                        FqButton.primary(
                          label: 'Enviar codigo',
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
