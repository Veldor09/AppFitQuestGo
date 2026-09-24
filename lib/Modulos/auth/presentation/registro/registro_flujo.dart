import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/core/widgets/campo_texto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/pasos/paso_actividades.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/pasos/paso_intereses.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/pasos/paso_permisos.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/registro_completado.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_app_header.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_progress_steps.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/terminos_modal.dart';

/// APP-04 .. APP-08 · Asistente de registro.
///
/// La creacion real de la cuenta (`POST /auth/registro`) ocurre en el ultimo
/// paso; los pasos intermedios (actividades e intereses) son de personalizacion
/// y aun no tienen backend. El estado vive aqui y cada paso es un widget de
/// presentacion sin logica de red.
class RegistroFlujoScreen extends StatefulWidget {
  const RegistroFlujoScreen({super.key});

  @override
  State<RegistroFlujoScreen> createState() => _RegistroFlujoScreenState();
}

class _RegistroFlujoScreenState extends State<RegistroFlujoScreen> {
  static const int _totalPasos = 4;

  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _ciudad = TextEditingController();

  final Set<String> _actividades = <String>{};
  final Set<String> _intereses = <String>{};
  final Map<String, bool> _permisos = <String, bool>{
    'Ubicacion': true,
    'Notificaciones': true,
    'Actividad fisica': false,
  };

  int _paso = 0;
  bool _enviando = false;
  bool _forzarError = false;
  bool _aceptaTerminos = false;
  bool _forzarErrorTerminos = false;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    _ciudad.dispose();
    super.dispose();
  }

  bool _datosValidos() {
    return todoValido(<(String, List<Validador>)>[
      (_nombre.text, reglasNombre()),
      (_email.text, reglasCorreo()),
      (_password.text, <Validador>[
        requerido('La contrasena es obligatoria'),
        minCaracteres(8),
      ]),
    ]);
  }

  void _atras() {
    if (_enviando) return;
    if (_paso == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _paso -= 1);
  }

  void _avanzarDesdeDatos() {
    FocusScope.of(context).unfocus();
    final bool datosValidos = _datosValidos();
    if (!datosValidos || !_aceptaTerminos) {
      setState(() {
        _forzarError = !datosValidos;
        _forzarErrorTerminos = !_aceptaTerminos;
      });
      notificarError(
        !_aceptaTerminos
            ? 'Debes aceptar los terminos y condiciones para continuar'
            : 'Revisa los campos marcados en rojo',
      );
      return;
    }
    setState(() => _paso = 1);
  }

  Future<void> _crearCuenta() async {
    setState(() => _enviando = true);
    try {
      await AuthScope.read(context).registrar(
        nombre: _nombre.text.trim(),
        email: _email.text.trim(),
        contrasena: _password.text,
        aceptaTerminos: _aceptaTerminos,
        intereses: _intereses.toList(),
        actividades: _actividades.toList(),
      );
      if (!mounted) return;

      notificarExito('Cuenta creada. Bienvenido a FitQuest Go');
      setState(() {
        _enviando = false;
        _paso = 4; // Paso de confirmacion.
      });
    } on ApiException catch (e) {
      _fallar(
        e.statusCode == 409
            ? 'Ese correo ya tiene una cuenta. Inicia sesion.'
            : e.message,
      );
    } catch (_) {
      _fallar('No se pudo crear la cuenta. Revisa tu conexion.');
    }
  }

  void _fallar(String mensaje) {
    if (!mounted) return;
    notificarError(mensaje);
    setState(() {
      _enviando = false;
      _forzarError = true;
      _paso = 0; // Vuelve a "Datos" para corregir.
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_paso == 4) {
      return RegistroCompletadoScreen(
        onContinuar: () => Navigator.of(context).pop(),
      );
    }

    final _PasoConfig cfg = _configPaso(_paso);

    return Scaffold(
      backgroundColor: FqColors.paper,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FqAppHeader(
              title: cfg.titulo,
              subtitle: 'Paso ${_paso + 1} de $_totalPasos',
              onLeading: _atras,
            ),
            FqProgressSteps(total: _totalPasos, completados: _paso + 1),
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
                        cfg.contenido,
                        const SizedBox(height: FqGap.xxl),
                        FqButton.primary(
                          label: cfg.cta,
                          loading: _enviando,
                          onPressed: _enviando ? null : cfg.onCta,
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

  _PasoConfig _configPaso(int paso) {
    switch (paso) {
      case 0:
        return _PasoConfig(
          titulo: 'Datos',
          cta: 'Continuar',
          onCta: _avanzarDesdeDatos,
          contenido: _PasoDatos(
            nombre: _nombre,
            email: _email,
            password: _password,
            ciudad: _ciudad,
            forzarError: _forzarError,
            aceptaTerminos: _aceptaTerminos,
            forzarErrorTerminos: _forzarErrorTerminos,
            onAceptaTerminosChanged: (bool v) => setState(() {
              _aceptaTerminos = v;
              if (v) _forzarErrorTerminos = false;
            }),
          ),
        );
      case 1:
        return _PasoConfig(
          titulo: 'Actividades',
          cta: 'Continuar',
          onCta: () => setState(() => _paso = 2),
          contenido: PasoActividades(
            seleccion: _actividades,
            onToggle: (String v) => setState(() => _toggle(_actividades, v)),
          ),
        );
      case 2:
        return _PasoConfig(
          titulo: 'Intereses',
          cta: 'Continuar',
          onCta: () => setState(() => _paso = 3),
          contenido: PasoIntereses(
            seleccion: _intereses,
            onToggle: (String v) => setState(() => _toggle(_intereses, v)),
          ),
        );
      default:
        return _PasoConfig(
          titulo: 'Permisos',
          cta: 'Permitir y continuar',
          onCta: _crearCuenta,
          contenido: PasoPermisos(
            valores: _permisos,
            onToggle: (String clave, bool v) =>
                setState(() => _permisos[clave] = v),
          ),
        );
    }
  }

  void _toggle(Set<String> conjunto, String valor) {
    if (!conjunto.add(valor)) conjunto.remove(valor);
  }
}

class _PasoConfig {
  _PasoConfig({
    required this.titulo,
    required this.cta,
    required this.onCta,
    required this.contenido,
  });

  final String titulo;
  final String cta;
  final VoidCallback onCta;
  final Widget contenido;
}

/// APP-04 · Datos basicos de la cuenta, con validacion en vivo por campo.
class _PasoDatos extends StatelessWidget {
  const _PasoDatos({
    required this.nombre,
    required this.email,
    required this.password,
    required this.ciudad,
    required this.forzarError,
    required this.aceptaTerminos,
    required this.forzarErrorTerminos,
    required this.onAceptaTerminosChanged,
  });

  final TextEditingController nombre;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController ciudad;
  final bool forzarError;
  final bool aceptaTerminos;
  final bool forzarErrorTerminos;
  final ValueChanged<bool> onAceptaTerminosChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CampoTexto(
          label: 'Nombre',
          controller: nombre,
          reglas: reglasNombre(),
          maxCaracteres: kMaxNombreUsuario,
          forzarError: forzarError,
          autofillHints: const <String>[AutofillHints.name],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: FqGap.sm),
        CampoTexto(
          label: 'Correo',
          controller: email,
          reglas: reglasCorreo(),
          maxCaracteres: kMaxCorreoUsuario,
          forzarError: forzarError,
          hintText: 'tucorreo@dominio.com',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const <String>[AutofillHints.email],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: FqGap.sm),
        CampoTexto(
          label: 'Contrasena',
          controller: password,
          reglas: <Validador>[
            requerido('La contrasena es obligatoria'),
            minCaracteres(8),
          ],
          obscureText: true,
          forzarError: forzarError,
          autofillHints: const <String>[AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: FqGap.sm),
        CampoTexto(
          label: 'Ciudad',
          controller: ciudad,
          reglas: <Validador>[maxCaracteres(40)],
          maxCaracteres: 40,
          textInputAction: TextInputAction.done,
          // Opcional: el backend aun no persiste la ciudad.
        ),
        const SizedBox(height: FqGap.md),
        _TerminosCheckbox(
          valor: aceptaTerminos,
          forzarError: forzarErrorTerminos,
          onChanged: onAceptaTerminosChanged,
        ),
      ],
    );
  }
}

class _TerminosCheckbox extends StatelessWidget {
  const _TerminosCheckbox({
    required this.valor,
    required this.forzarError,
    required this.onChanged,
  });

  final bool valor;
  final bool forzarError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool mostrarError = forzarError && !valor;
    // El toggle y el enlace usan recognizers de texto independientes (no un
    // InkWell envolvente) para que tocar "terminos y condiciones" solo abra
    // el modal, sin alterar el estado de la casilla.
    final TapGestureRecognizer toggleRecognizer = TapGestureRecognizer()
      ..onTap = () => onChanged(!valor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: valor,
                onChanged: (bool? v) => onChanged(v ?? false),
                activeColor: FqColors.voltDark,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: mostrarError
                    ? const BorderSide(color: FqColors.risk, width: 1.4)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: FqColors.muted,
                    ),
                    children: <InlineSpan>[
                      TextSpan(
                        text: 'Acepto los ',
                        recognizer: toggleRecognizer,
                      ),
                      TextSpan(
                        text: 'terminos y condiciones',
                        style: const TextStyle(
                          color: FqColors.river,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => TerminosModal.mostrar(context),
                      ),
                      TextSpan(
                        text: ' de FitQuest Go.',
                        recognizer: toggleRecognizer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (mostrarError)
          const Padding(
            padding: EdgeInsets.only(left: 30, top: 2),
            child: Text(
              'Debes aceptar los terminos para crear tu cuenta',
              style: TextStyle(fontSize: 10, color: FqColors.risk),
            ),
          ),
      ],
    );
  }
}
