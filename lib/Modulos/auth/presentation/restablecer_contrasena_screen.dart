import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/core/widgets/campo_texto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
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

  bool _valido() {
    return todoValido(<(String, List<Validador>)>[
      (_codigo.text, <Validador>[
        requerido('Ingresa el codigo'),
        (String v) => v.trim().length == 6 ? null : 'El codigo tiene 6 digitos',
      ]),
      (_password.text, <Validador>[
        requerido('Ingresa la nueva contrasena'),
        minCaracteres(8),
      ]),
    ]);
  }

  Future<void> _confirmar() async {
    FocusScope.of(context).unfocus();
    if (!_valido()) {
      setState(() => _forzarError = true);
      notificarError('Revisa los campos marcados en rojo');
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
      notificarExito('Contrasena actualizada. Inicia sesion con la nueva.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      _fallar(
        e.statusCode == 401 ? 'Codigo invalido o expirado' : e.message,
      );
    } catch (_) {
      _fallar('No se pudo conectar con el servidor. Intenta de nuevo.');
    }
  }

  void _fallar(String mensaje) {
    if (!mounted) return;
    setState(() => _cargando = false);
    notificarError(mensaje);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FqColors.paper,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FqAppHeader(
              title: 'Ingresa el codigo',
              subtitle: 'Lo enviamos a ${widget.email}',
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
                          label: 'Codigo de 6 digitos',
                          controller: _codigo,
                          keyboardType: TextInputType.number,
                          maxCaracteres: 6,
                          forzarError: _forzarError,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: FqGap.sm),
                        CampoTexto(
                          label: 'Contrasena nueva',
                          controller: _password,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const <String>[
                            AutofillHints.newPassword,
                          ],
                          forzarError: _forzarError,
                          onSubmitted: (_) => _confirmar(),
                          reglas: <Validador>[
                            requerido('Ingresa la nueva contrasena'),
                            minCaracteres(8),
                          ],
                        ),
                        const SizedBox(height: FqGap.xl),
                        FqButton.primary(
                          label: 'Actualizar contrasena',
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
