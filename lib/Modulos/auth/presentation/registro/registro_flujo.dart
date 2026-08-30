import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_text_field.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/pasos/paso_actividades.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/pasos/paso_intereses.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/pasos/paso_permisos.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/registro/registro_completado.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/auth_error_banner.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_app_header.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_progress_steps.dart';

/// APP-04 .. APP-08 · Asistente de registro.
///
/// La creacion real de la cuenta (`POST /auth/registro`) ocurre en el ultimo
/// paso de permisos; los pasos intermedios (actividades e intereses) son de
/// personalizacion y aun no tienen backend, por lo que solo capturan la
/// seleccion en memoria. El estado vive aqui (una sola responsabilidad: "el
/// flujo de alta") y cada paso es un widget de presentacion sin logica de red.
class RegistroFlujoScreen extends StatefulWidget {
  const RegistroFlujoScreen({super.key});

  @override
  State<RegistroFlujoScreen> createState() => _RegistroFlujoScreenState();
}

class _RegistroFlujoScreenState extends State<RegistroFlujoScreen> {
  static const int _totalPasos = 4;

  final GlobalKey<FormState> _datosKey = GlobalKey<FormState>();
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
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    _ciudad.dispose();
    super.dispose();
  }

  void _atras() {
    if (_enviando) return;
    if (_paso == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _error = null;
      _paso -= 1;
    });
  }

  void _avanzarDesdeDatos() {
    if (!_datosKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _paso = 1);
  }

  Future<void> _crearCuenta() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await AuthScope.read(context).registrar(
        nombre: _nombre.text.trim(),
        email: _email.text.trim(),
        contrasena: _password.text,
      );
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _paso = 4; // Paso de confirmacion (fuera del rango de progreso).
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
    setState(() {
      _enviando = false;
      _error = mensaje;
      _paso = 0; // Regresa a Datos para corregir.
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
                        if (_error != null) ...<Widget>[
                          AuthErrorBanner(message: _error!),
                          const SizedBox(height: FqGap.lg),
                        ],
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
            formKey: _datosKey,
            nombre: _nombre,
            email: _email,
            password: _password,
            ciudad: _ciudad,
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

/// APP-04 · Datos basicos de la cuenta (unico paso con validacion de formulario).
class _PasoDatos extends StatelessWidget {
  const _PasoDatos({
    required this.formKey,
    required this.nombre,
    required this.email,
    required this.password,
    required this.ciudad,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nombre;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController ciudad;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FqTextField(
            label: 'Nombre',
            controller: nombre,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.name],
            validator: (String? v) => (v == null || v.trim().isEmpty)
                ? 'Escribe tu nombre'
                : null,
          ),
          const SizedBox(height: FqGap.md),
          FqTextField(
            label: 'Correo',
            controller: email,
            hintText: 'tucorreo@dominio.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.email],
            validator: (String? v) => (v == null || !v.contains('@'))
                ? 'Ingresa un correo valido'
                : null,
          ),
          const SizedBox(height: FqGap.md),
          FqTextField(
            label: 'Contrasena',
            controller: password,
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.newPassword],
            validator: (String? v) => (v == null || v.length < 8)
                ? 'Minimo 8 caracteres'
                : null,
          ),
          const SizedBox(height: FqGap.md),
          FqTextField(
            label: 'Ciudad',
            controller: ciudad,
            textInputAction: TextInputAction.done,
            // El backend actual no persiste la ciudad; se captura para el perfil
            // cuando exista el endpoint. Campo opcional.
          ),
        ],
      ),
    );
  }
}
