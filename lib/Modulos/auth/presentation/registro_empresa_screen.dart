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
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_app_header.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/terminos_checkbox.dart';

/// Limite de caracteres del nombre comercial (coincide con el backend).
const int kMaxNombreComercial = 100;

/// Telefono de contacto, opcional: de 8 a 20 caracteres entre digitos, `+`,
/// espacios y guiones (coincide con el backend).
Validador telefonoOpcional(String mensaje) {
  final RegExp re = RegExp(r'^\+?\d[\d -]{6,18}\d$');
  return (String v) {
    final String t = v.trim();
    if (t.isEmpty) return null;
    return re.hasMatch(t) ? null : mensaje;
  };
}

/// Alta de una cuenta de empresa (`POST /auth/registro-empresa`). Un comercio
/// entra con ella a su propio panel, donde publica eventos y nodos.
class RegistroEmpresaScreen extends StatefulWidget {
  const RegistroEmpresaScreen({super.key});

  @override
  State<RegistroEmpresaScreen> createState() => _RegistroEmpresaScreenState();
}

class _RegistroEmpresaScreenState extends State<RegistroEmpresaScreen> {
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _telefono = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _aceptaTerminos = false;
  bool _forzarError = false;
  bool _forzarErrorTerminos = false;
  bool _enviando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _telefono.dispose();
    _password.dispose();
    super.dispose();
  }

  List<Validador> _reglasNombre(AppLocalizations l10n) => <Validador>[
    requerido(l10n.registroEmpresaValidacionNombre),
    minCaracteres(2, l10n.registroEmpresaValidacionNombre),
    maxCaracteres(kMaxNombreComercial),
  ];

  List<Validador> _reglasTelefono(AppLocalizations l10n) => <Validador>[
    telefonoOpcional(l10n.registroEmpresaValidacionTelefono),
  ];

  List<Validador> _reglasPassword(AppLocalizations l10n) => <Validador>[
    requerido(l10n.registroValidacionContrasena),
    minCaracteres(8),
  ];

  bool _datosValidos(AppLocalizations l10n) {
    return todoValido(<(String, List<Validador>)>[
      (_nombre.text, _reglasNombre(l10n)),
      (_email.text, reglasCorreo()),
      (_telefono.text, _reglasTelefono(l10n)),
      (_password.text, _reglasPassword(l10n)),
    ]);
  }

  Future<void> _crearCuenta() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    final bool datosValidos = _datosValidos(l10n);
    if (!datosValidos || !_aceptaTerminos) {
      setState(() {
        _forzarError = !datosValidos;
        _forzarErrorTerminos = !_aceptaTerminos;
      });
      notificarError(
        !_aceptaTerminos
            ? l10n.registroAceptaTerminosError
            : l10n.comunRevisaCampos,
      );
      return;
    }
    setState(() => _enviando = true);
    try {
      await AuthScope.read(context).registrarEmpresa(
        nombreComercial: _nombre.text.trim(),
        email: _email.text.trim(),
        contrasena: _password.text,
        aceptaTerminos: _aceptaTerminos,
        telefono: _telefono.text,
      );
      if (!mounted) return;
      notificarExito(l10n.registroEmpresaExito);
      // La sesion ya cambio: la raiz de la app muestra el panel de la empresa.
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      _fallar(
        e.statusCode == 409 ? l10n.registroCorreoYaRegistrado : e.message,
      );
    } catch (_) {
      _fallar(l10n.registroErrorConexion);
    }
  }

  void _fallar(String mensaje) {
    if (!mounted) return;
    notificarError(mensaje);
    setState(() {
      _enviando = false;
      _forzarError = true;
    });
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
              title: l10n.registroEmpresaTitulo,
              subtitle: l10n.registroEmpresaSubtitulo,
              onLeading: _enviando
                  ? null
                  : () => Navigator.of(context).maybePop(),
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
                    constraints: const BoxConstraints(
                      maxWidth: kAuthContentMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        CampoTexto(
                          label: l10n.registroEmpresaNombreComercial,
                          controller: _nombre,
                          reglas: _reglasNombre(l10n),
                          maxCaracteres: kMaxNombreComercial,
                          forzarError: _forzarError,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: FqGap.sm),
                        CampoTexto(
                          label: l10n.comunCorreo,
                          controller: _email,
                          reglas: reglasCorreo(),
                          maxCaracteres: kMaxCorreoUsuario,
                          forzarError: _forzarError,
                          hintText: l10n.comunCorreoHint,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const <String>[AutofillHints.email],
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: FqGap.sm),
                        CampoTexto(
                          label: l10n.registroEmpresaTelefono,
                          controller: _telefono,
                          reglas: _reglasTelefono(l10n),
                          maxCaracteres: 20,
                          forzarError: _forzarError,
                          hintText: l10n.registroEmpresaTelefonoHint,
                          keyboardType: TextInputType.phone,
                          autofillHints: const <String>[
                            AutofillHints.telephoneNumber,
                          ],
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: FqGap.sm),
                        CampoTexto(
                          label: l10n.comunContrasena,
                          controller: _password,
                          reglas: _reglasPassword(l10n),
                          obscureText: true,
                          forzarError: _forzarError,
                          autofillHints: const <String>[
                            AutofillHints.newPassword,
                          ],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _crearCuenta(),
                        ),
                        const SizedBox(height: FqGap.md),
                        TerminosCheckbox(
                          valor: _aceptaTerminos,
                          forzarError: _forzarErrorTerminos,
                          onChanged: (bool v) => setState(() {
                            _aceptaTerminos = v;
                            if (v) _forzarErrorTerminos = false;
                          }),
                        ),
                        const SizedBox(height: FqGap.xxl),
                        FqButton.primary(
                          key: const ValueKey<String>('crear-cuenta-empresa'),
                          label: l10n.registroEmpresaBoton,
                          loading: _enviando,
                          onPressed: _enviando ? null : _crearCuenta,
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
