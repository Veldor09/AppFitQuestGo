import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_text_field.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/auth_error_banner.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_app_header.dart';

/// APP-03 · Login. Pantalla funcional: autentica contra `POST /auth/inicio-sesion`
/// mediante [AuthRepositorio]. Al terminar, `_RootGate` decide el destino segun
/// el rol, por lo que aqui solo se cierra la ruta.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await AuthScope.read(context).iniciarSesion(
        email: _email.text.trim(),
        contrasena: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      _fallar(e.statusCode == 401 ? 'Correo o contrasena incorrectos.' : e.message);
    } catch (_) {
      _fallar('No se pudo conectar con el servidor. Intenta de nuevo.');
    }
  }

  void _fallar(String mensaje) {
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = mensaje;
    });
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (_error != null) ...<Widget>[
                            AuthErrorBanner(message: _error!),
                            const SizedBox(height: FqGap.lg),
                          ],
                          FqTextField(
                            label: 'Correo',
                            controller: _email,
                            hintText: 'tucorreo@dominio.com',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const <String>[AutofillHints.email],
                            validator: (String? v) =>
                                (v == null || !v.contains('@'))
                                    ? 'Ingresa un correo valido'
                                    : null,
                          ),
                          const SizedBox(height: FqGap.md),
                          FqTextField(
                            label: 'Contrasena',
                            controller: _password,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const <String>[
                              AutofillHints.password,
                            ],
                            onFieldSubmitted: (_) => _iniciar(),
                            validator: (String? v) =>
                                (v == null || v.isEmpty)
                                    ? 'Ingresa tu contrasena'
                                    : null,
                          ),
                          const SizedBox(height: FqGap.md),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text(
                                  'Recuperacion de contrasena: pendiente de backend.',
                                ),
                              )),
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
                          const SizedBox(height: FqGap.xxl),
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
            ),
          ],
        ),
      ),
    );
  }
}
