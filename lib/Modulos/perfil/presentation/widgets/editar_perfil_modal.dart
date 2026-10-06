import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/validaciones/validadores.dart';
import 'package:fit_quest_go/core/widgets/campo_texto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

/// Modal para editar la información personal del usuario actual (nombre, correo y contraseña).
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
      transitionDuration: const Duration(milliseconds: 190),
      pageBuilder: (_, _, _) => EditarPerfilModal(usuario: usuario, api: api),
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
        notificarError('Revisa los campos marcados en rojo');
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
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            color: FqColors.white,
            borderRadius: const BorderRadius.all(Radius.circular(22)),
            clipBehavior: Clip.antiAlias,
            elevation: 12,
            shadowColor: Colors.black45,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _encabezado(),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: FqColors.border),
                  const SizedBox(height: 16),
                  _formulario(),
                  const SizedBox(height: 20),
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
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FqColors.volt,
            borderRadius: BorderRadius.circular(16),
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
              const SizedBox(height: 3),
              Row(
                children: <Widget>[
                  FqTag(widget.usuario.etiquetaRol, tone: _tonoRol(widget.usuario.idrol)),
                  const SizedBox(width: 6),
                  Text(
                    widget.usuario.estado,
                    style: const TextStyle(fontSize: 11, color: FqColors.muted, fontWeight: FontWeight.w500),
                  ),
                ],
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

  Widget _formulario() {
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
          textInputAction: _cambiarPassword ? TextInputAction.next : TextInputAction.done,
        ),
        const SizedBox(height: FqGap.md),
        InkWell(
          onTap: () => setState(() => _cambiarPassword = !_cambiarPassword),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              children: <Widget>[
                Icon(
                  _cambiarPassword ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  size: 20,
                  color: _cambiarPassword ? FqColors.voltDark : FqColors.muted,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Cambiar contraseña',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FqColors.ink,
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
          expand: false,
          loading: _guardando,
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }

  FqTagTone _tonoRol(int idrol) {
    switch (idrol) {
      case 3:
        return FqTagTone.dark;
      case 2:
        return FqTagTone.amber;
      default:
        return FqTagTone.green;
    }
  }
}
