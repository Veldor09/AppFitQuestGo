import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/core/widgets/campo_texto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

/// Modal para editar la información personal del usuario (nombre, correo y contraseña).
class EditarPerfilModal extends StatefulWidget {
  const EditarPerfilModal({
    super.key,
    required this.usuario,
    this.api,
  });

  final Usuario usuario;
  final PerfilApi? api;

  static Future<bool?> abrir(
    BuildContext context, {
    required Usuario usuario,
    PerfilApi? api,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => EditarPerfilModal(
        usuario: usuario,
        api: api,
      ),
      transitionBuilder: (_, Animation<double> anim, _, Widget child) {
        final double t = Curves.easeOutCubic.transform(anim.value);
        return FadeTransition(
          opacity: anim,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: ColoredBox(
              color: const Color(0x5A0B1220),
              child: Transform.scale(scale: 0.95 + 0.05 * t, child: child),
            ),
          ),
        );
      },
    );
  }

  @override
  State<EditarPerfilModal> createState() => _EditarPerfilModalState();
}

class _EditarPerfilModalState extends State<EditarPerfilModal> {
  late final PerfilApi _api = widget.api ?? PerfilApi();

  late final TextEditingController _nombre = TextEditingController(
    text: widget.usuario.nombreUser,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.usuario.emailUser,
  );
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  bool _guardando = false;
  bool _forzarError = false;
  bool _cambiarPassword = false;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _cerrar([bool cambio = false]) => Navigator.of(context).pop(cambio);

  bool _camposValidos() {
    final bool datosBasicos = todoValido(<(String, List<Validador>)>[
      (_nombre.text, reglasNombre()),
      (_email.text, reglasCorreo()),
    ]);

    if (!_cambiarPassword) return datosBasicos;

    final bool passwordValido = todoValido(<(String, List<Validador>)>[
      (_password.text, <Validador>[
        requerido('Ingresa la nueva contraseña'),
        minCaracteres(8),
      ]),
    ]);

    final bool coincide = _password.text == _confirmPassword.text;
    return datosBasicos && passwordValido && coincide;
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_camposValidos()) {
      setState(() => _forzarError = true);
      if (_cambiarPassword && _password.text != _confirmPassword.text) {
        notificarError('Las contraseñas no coinciden');
      } else {
        notificarError('Revisa los campos de información personal');
      }
      return;
    }

    setState(() => _guardando = true);
    try {
      await _api.actualizarPerfil(
        id: widget.usuario.id,
        nombreUser: _nombre.text.trim(),
        emailUser: _email.text.trim(),
        nuevaContrasena: _cambiarPassword ? _password.text : null,
      );

      if (!mounted) return;
      notificarExito('Perfil actualizado correctamente');
      _cerrar(true);
    } on ApiException catch (e) {
      _fallar(e.message);
    } catch (_) {
      _fallar('No se pudo actualizar el perfil. Revisa tu conexión.');
    }
  }

  void _fallar(String mensaje) {
    if (!mounted) return;
    setState(() => _guardando = false);
    notificarError(mensaje);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Material(
            color: FqColors.white,
            borderRadius: const BorderRadius.all(Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            elevation: 14,
            shadowColor: Colors.black45,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _encabezado(),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: FqColors.border),
                  const SizedBox(height: 16),
                  _campos(),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: FqColors.border),
                  const SizedBox(height: 14),
                  _acciones(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _encabezado() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FqColors.volt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            widget.usuario.iniciales,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: FqColors.night,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Editar mi perfil',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: FqColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.usuario.emailUser,
                style: const TextStyle(
                  fontSize: 12,
                  color: FqColors.muted,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _cerrar(),
          icon: const Icon(Icons.close, size: 20),
          color: FqColors.muted,
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
      ],
    );
  }

  Widget _campos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CampoTexto(
          label: 'Nombre completo',
          controller: _nombre,
          reglas: reglasNombre(),
          maxCaracteres: kMaxNombreUsuario,
          forzarError: _forzarError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: FqGap.md),
        CampoTexto(
          label: 'Correo electrónico',
          controller: _email,
          reglas: reglasCorreo(),
          maxCaracteres: kMaxCorreoUsuario,
          forzarError: _forzarError,
          keyboardType: TextInputType.emailAddress,
          textInputAction:
              _cambiarPassword ? TextInputAction.next : TextInputAction.done,
        ),
        const SizedBox(height: FqGap.md),
        InkWell(
          onTap: () => setState(() => _cambiarPassword = !_cambiarPassword),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: _cambiarPassword
                  ? FqColors.choiceSelectedBg
                  : const Color(0xFFF6F8F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _cambiarPassword
                    ? FqColors.voltDark
                    : const Color(0xFFE2E8DE),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  _cambiarPassword
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 19,
                  color: _cambiarPassword ? FqColors.voltDark : FqColors.muted,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Cambiar contraseña de acceso',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FqColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_cambiarPassword) ...<Widget>[
          const SizedBox(height: FqGap.sm),
          CampoTexto(
            label: 'Nueva contraseña',
            controller: _password,
            reglas: <Validador>[
              requerido('Ingresa la contraseña'),
              minCaracteres(8),
            ],
            obscureText: true,
            forzarError: _forzarError,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: FqGap.sm),
          CampoTexto(
            label: 'Confirmar nueva contraseña',
            controller: _confirmPassword,
            reglas: <Validador>[
              requerido('Confirma la contraseña'),
              minCaracteres(8),
            ],
            obscureText: true,
            forzarError: _forzarError,
            textInputAction: TextInputAction.done,
          ),
        ],
      ],
    );
  }

  Widget _acciones() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        FqButton.ghost(
          label: 'Cancelar',
          expand: false,
          onPressed: _guardando ? null : () => _cerrar(),
        ),
        const SizedBox(width: 10),
        FqButton.primary(
          label: 'Guardar cambios',
          icon: Icons.check_rounded,
          expand: false,
          loading: _guardando,
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
