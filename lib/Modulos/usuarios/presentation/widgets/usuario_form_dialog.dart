import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_text_field.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuarios_api.dart';

/// Dialogo de alta / edicion de usuario. Funcional: llama a
/// `POST /usuarios` o `PUT /usuarios/:id` a traves de [UsuariosApi].
///
/// Devuelve `true` si se guardo, para que la lista se refresque.
class UsuarioFormDialog extends StatefulWidget {
  const UsuarioFormDialog({super.key, this.usuario, this.api});

  final Usuario? usuario;

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final UsuariosApi? api;

  static Future<bool?> mostrar(
    BuildContext context, {
    Usuario? usuario,
    UsuariosApi? api,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UsuarioFormDialog(usuario: usuario, api: api),
    );
  }

  @override
  State<UsuarioFormDialog> createState() => _UsuarioFormDialogState();
}

class _UsuarioFormDialogState extends State<UsuarioFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final UsuariosApi _api = widget.api ?? UsuariosApi();

  late final TextEditingController _nombre =
      TextEditingController(text: widget.usuario?.nombreUser ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.usuario?.emailUser ?? '');
  final TextEditingController _password = TextEditingController();

  late int _idrol = widget.usuario?.idrol ?? 1;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.usuario != null;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      if (_esEdicion) {
        final Map<String, dynamic> cambios = <String, dynamic>{
          'nombreUser': _nombre.text.trim(),
          'emailUser': _email.text.trim(),
          'idrol': _idrol,
        };
        if (_password.text.isNotEmpty) {
          cambios['passwordUserHash'] = _password.text;
        }
        await _api.update(widget.usuario!.id, cambios);
      } else {
        await _api.create(
          nombreUser: _nombre.text.trim(),
          emailUser: _email.text.trim(),
          passwordUserHash: _password.text,
          idrol: _idrol,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _fallar(e.message);
    } catch (_) {
      _fallar('No se pudo guardar. Revisa tu conexion.');
    }
  }

  void _fallar(String mensaje) {
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _error = mensaje;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: FqColors.white,
      shape: const RoundedRectangleBorder(borderRadius: FqRadius.allXl),
      title: Text(
        _esEdicion ? 'Editar usuario' : 'Nuevo usuario',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_error != null) ...<Widget>[
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 11, color: FqColors.risk),
                ),
                const SizedBox(height: FqGap.md),
              ],
              FqTextField(
                label: 'Nombre',
                controller: _nombre,
                validator: (String? v) => (v == null || v.trim().isEmpty)
                    ? 'Requerido'
                    : null,
              ),
              const SizedBox(height: FqGap.md),
              FqTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: (String? v) =>
                    (v == null || !v.contains('@')) ? 'Email invalido' : null,
              ),
              const SizedBox(height: FqGap.md),
              FqTextField(
                label: _esEdicion
                    ? 'Contrasena (vacio = no cambiar)'
                    : 'Contrasena',
                controller: _password,
                obscureText: true,
                validator: (String? v) {
                  if (_esEdicion && (v == null || v.isEmpty)) return null;
                  if (v == null || v.length < 8) return 'Minimo 8 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: FqGap.md),
              Container(
                decoration: BoxDecoration(
                  color: FqColors.white,
                  borderRadius: FqRadius.allMd,
                  border: Border.all(color: FqColors.fieldBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: DropdownButtonFormField<int>(
                  initialValue: _idrol,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'ROL',
                    labelStyle: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: FqColors.fieldLabel,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  items: rolesDisponibles.entries
                      .map(
                        (MapEntry<int, String> e) => DropdownMenuItem<int>(
                          value: e.key,
                          child: Text(
                            e.value,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (int? v) => setState(() => _idrol = v ?? _idrol),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        FqButton.ghost(
          label: 'Cancelar',
          expand: false,
          onPressed:
              _guardando ? null : () => Navigator.of(context).pop(false),
        ),
        FqButton.primary(
          label: 'Guardar',
          expand: false,
          loading: _guardando,
          onPressed: _guardando ? null : _guardar,
        ),
      ],
    );
  }
}
