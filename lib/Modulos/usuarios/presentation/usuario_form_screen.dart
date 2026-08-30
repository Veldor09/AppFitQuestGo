import 'package:flutter/material.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuarios_api.dart';

class UsuarioFormScreen extends StatefulWidget {
  const UsuarioFormScreen({super.key, this.usuario});

  final Usuario? usuario;

  @override
  State<UsuarioFormScreen> createState() => _UsuarioFormScreenState();
}

class _UsuarioFormScreenState extends State<UsuarioFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final UsuariosApi _api = UsuariosApi();

  late final TextEditingController _nombre;
  late final TextEditingController _email;
  final TextEditingController _password = TextEditingController();
  late int _idrol;
  bool _guardando = false;

  bool get _esEdicion => widget.usuario != null;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.usuario?.nombreUser ?? '');
    _email = TextEditingController(text: widget.usuario?.emailUser ?? '');
    _idrol = widget.usuario?.idrol ?? 1;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
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
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _fallo(e.message);
    } catch (e) {
      _fallo('$e');
    }
  }

  void _fallo(String mensaje) {
    if (!mounted) return;
    setState(() => _guardando = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar usuario' : 'Nuevo usuario'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Email inválido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              decoration: InputDecoration(
                labelText: _esEdicion
                    ? 'Contraseña (vacío = no cambiar)'
                    : 'Contraseña',
              ),
              obscureText: true,
              validator: (v) {
                if (_esEdicion && (v == null || v.isEmpty)) return null;
                if (v == null || v.length < 8) return 'Mínimo 8 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _idrol,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: rolesDisponibles.entries
                  .map(
                    (e) => DropdownMenuItem<int>(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _idrol = v ?? _idrol),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: Text(_guardando ? 'Guardando...' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
