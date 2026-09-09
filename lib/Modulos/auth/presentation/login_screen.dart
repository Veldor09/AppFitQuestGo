import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/core/widgets/campo_texto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
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

  bool _valido() {
    return todoValido(<(String, List<Validador>)>[
      (_email.text, <Validador>[requerido('El correo es obligatorio'),
        formatoCorreo]),
      (_password.text, <Validador>[requerido('Ingresa tu contrasena')]),
    ]);
  }

  Future<void> _iniciar() async {
    FocusScope.of(context).unfocus();
    if (!_valido()) {
      setState(() => _forzarError = true);
      notificarError('Revisa los campos marcados en rojo');
      return;
    }
    setState(() => _cargando = true);
    try {
      await AuthScope.read(context).iniciarSesion(
        email: _email.text.trim(),
        contrasena: _password.text,
      );
      if (!mounted) return;
      notificarExito('Inicio de sesion exitoso');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      _fallar(
        e.statusCode == 401
            ? 'Correo o contrasena incorrectos'
            : e.message,
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
              title: 'Bienvenido de vuelta',
              subtitle: 'Continua tu recorrido',
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
                          textInputAction: TextInputAction.next,
                          autofillHints: const <String>[AutofillHints.email],
                          forzarError: _forzarError,
                          reglas: <Validador>[
                            requerido('El correo es obligatorio'),
                            formatoCorreo,
                          ],
                        ),
                        const SizedBox(height: FqGap.sm),
                        CampoTexto(
                          label: 'Contrasena',
                          controller: _password,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const <String>[
                            AutofillHints.password,
                          ],
                          forzarError: _forzarError,
                          onSubmitted: (_) => _iniciar(),
                          reglas: <Validador>[
                            requerido('Ingresa tu contrasena'),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => notificarInfo(
                              'Si el correo existe, te enviaremos instrucciones',
                            ),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: FqColors.river,
                            ),
                            child: const Text(
                              'Olvidaste tu contrasena?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: FqGap.xl),
                        FqButton.primary(
                          label: 'Iniciar sesion',
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
