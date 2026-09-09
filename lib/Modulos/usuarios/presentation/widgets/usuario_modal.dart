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
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuarios_api.dart';

enum ModoUsuarioModal { ver, editar, crear }

class UsuarioModal extends StatefulWidget {
  const UsuarioModal({
    super.key,
    required this.modo,
    this.usuario,
    this.api,
    this.miId,
  });

  final ModoUsuarioModal modo;
  final Usuario? usuario;
  final UsuariosApi? api;

  /// Id del usuario en sesion: se usa para impedir que se quite su propio rol.
  final int? miId;

  static Future<bool?> abrir(
    BuildContext context, {
    required ModoUsuarioModal modo,
    Usuario? usuario,
    UsuariosApi? api,
    int? miId,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 190),
      pageBuilder: (_, _, _) =>
          UsuarioModal(modo: modo, usuario: usuario, api: api, miId: miId),
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
  State<UsuarioModal> createState() => _UsuarioModalState();
}

class _UsuarioModalState extends State<UsuarioModal> {
  late final UsuariosApi _api = widget.api ?? UsuariosApi();

  late ModoUsuarioModal _modo = widget.modo;

  late final TextEditingController _nombre = TextEditingController(
    text: widget.usuario?.nombreUser ?? '',
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.usuario?.emailUser ?? '',
  );
  final TextEditingController _password = TextEditingController();
  late int _idrol = widget.usuario?.idrol ?? 1;

  bool _guardando = false;
  bool _forzarError = false;

  bool get _esCrear => _modo == ModoUsuarioModal.crear;
  bool get _esVer => _modo == ModoUsuarioModal.ver;

  /// Al editarse a si mismo, un admin no puede cambiar su propio rol.
  bool get _rolBloqueado =>
      !_esCrear && widget.usuario != null && widget.usuario!.id == widget.miId;

  List<Validador> get _reglasPassword => _esCrear
      ? <Validador>[requerido('La contrasena es obligatoria'), minCaracteres(8)]
      : <Validador>[minCaracteresSiPresente(8)];

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _titulo {
    switch (_modo) {
      case ModoUsuarioModal.ver:
        return widget.usuario?.nombreUser ?? 'Usuario';
      case ModoUsuarioModal.editar:
        return 'Editar usuario';
      case ModoUsuarioModal.crear:
        return 'Nuevo usuario';
    }
  }

  void _cerrar([bool cambio = false]) => Navigator.of(context).pop(cambio);

  void _cancelarEdicion() {
    if (widget.modo == ModoUsuarioModal.ver) {
      setState(() {
        _forzarError = false;
        _nombre.text = widget.usuario!.nombreUser;
        _email.text = widget.usuario!.emailUser;
        _password.clear();
        _idrol = widget.usuario!.idrol;
        _modo = ModoUsuarioModal.ver;
      });
    } else {
      _cerrar();
    }
  }

  bool _camposValidos() {
    return todoValido(<(String, List<Validador>)>[
      (_nombre.text, reglasNombre()),
      (_email.text, reglasCorreo()),
      (_password.text, _reglasPassword),
    ]);
  }

  Future<void> _guardar() async {
    if (!_camposValidos()) {
      setState(() => _forzarError = true);
      notificarError('Revisa los campos marcados en rojo');
      return;
    }
    setState(() => _guardando = true);
    try {
      if (_esCrear) {
        await _api.create(
          nombreUser: _nombre.text.trim(),
          emailUser: _email.text.trim(),
          passwordUserHash: _password.text,
          idrol: _idrol,
        );
      } else {
        final Map<String, dynamic> cambios = <String, dynamic>{
          'nombreUser': _nombre.text.trim(),
          'emailUser': _email.text.trim(),
          if (!_rolBloqueado) 'idrol': _idrol,
        };
        if (_password.text.isNotEmpty) {
          cambios['passwordUserHash'] = _password.text;
        }
        await _api.update(widget.usuario!.id, cambios);
      }
      if (!mounted) return;
      _cerrar(true);
    } on ApiException catch (e) {
      _fallar(e.message);
    } catch (_) {
      _fallar('No se pudo guardar. Revisa tu conexion.');
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
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: FqColors.white,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _encabezado(),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: FqColors.border),
                  const SizedBox(height: 16),
                  _cuerpo(),
                  const SizedBox(height: 18),
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
    final Usuario? u = widget.usuario;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            _esCrear ? '+' : (u?.iniciales ?? '?'),
            style: const TextStyle(
              fontSize: 15,
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
              Text(
                _titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: FqColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              FqTag(rolesDisponibles[_idrol] ?? 'Usuario', tone: _tono(_idrol)),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _cerrar(),
          icon: const Icon(Icons.close, size: 18),
          color: FqColors.muted,
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _cuerpo() {
    if (_esVer) {
      final Usuario u = widget.usuario!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DatoLinea(label: 'Nombre', value: u.nombreUser),
          _DatoLinea(label: 'Correo', value: u.emailUser),
          _DatoLinea(label: 'Rol', value: u.etiquetaRol),
          _DatoLinea(label: 'Estado', value: u.estado, ultimo: true),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CampoTexto(
          label: 'Nombre',
          controller: _nombre,
          reglas: reglasNombre(),
          maxCaracteres: kMaxNombreUsuario,
          forzarError: _forzarError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: FqGap.sm),
        CampoTexto(
          label: 'Correo',
          controller: _email,
          reglas: reglasCorreo(),
          maxCaracteres: kMaxCorreoUsuario,
          forzarError: _forzarError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: FqGap.sm),
        _SelectorRol(
          valor: _idrol,
          bloqueado: _rolBloqueado,
          onChanged: (int v) => setState(() => _idrol = v),
        ),
        if (_esCrear) ...<Widget>[
          const SizedBox(height: FqGap.sm),
          CampoTexto(
            label: 'Contraseña',
            controller: _password,
            reglas: _reglasPassword,
            obscureText: true,
            forzarError: _forzarError,
          ),
        ],
      ],
    );
  }

  Widget _acciones() {
    if (_esVer) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FqButton.ghost(
            label: 'Cerrar',
            expand: false,
            onPressed: () => _cerrar(),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        FqButton.ghost(
          label: 'Cancelar',
          expand: false,
          onPressed: _guardando ? null : _cancelarEdicion,
        ),
        const SizedBox(width: 8),
        FqButton.primary(
          label: _esCrear ? 'Crear' : 'Guardar',
          expand: false,
          loading: _guardando,
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }

  FqTagTone _tono(int idrol) {
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

class _DatoLinea extends StatelessWidget {
  const _DatoLinea({
    required this.label,
    required this.value,
    this.ultimo = false,
  });

  final String label;
  final String value;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: ultimo
            ? null
            : const Border(bottom: BorderSide(color: FqColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: FqColors.fieldLabel,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: FqColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorRol extends StatelessWidget {
  const _SelectorRol({
    required this.valor,
    required this.onChanged,
    this.bloqueado = false,
  });

  final int valor;
  final ValueChanged<int> onChanged;
  final bool bloqueado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: FqColors.white,
            borderRadius: FqRadius.allMd,
            border: Border.all(color: FqColors.fieldBorder),
          ),
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'ROL',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: FqColors.fieldLabel,
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: valor,
                  isDense: true,
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: FqColors.ink,
                  ),
                  items: rolesDisponibles.entries
                      .map(
                        (MapEntry<int, String> e) => DropdownMenuItem<int>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: bloqueado
                      ? null
                      : (int? v) {
                          if (v != null) onChanged(v);
                        },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 14,
          child: bloqueado
              ? const Text(
                  'No puedes cambiar tu propio rol',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: FqColors.muted,
                  ),
                )
              : null,
        ),
      ],
    );
  }
}
