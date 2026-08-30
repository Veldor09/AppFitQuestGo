import 'package:flutter/material.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

class UsuarioTile extends StatelessWidget {
  const UsuarioTile({
    super.key,
    required this.usuario,
    required this.onTap,
    required this.onDelete,
  });

  final Usuario usuario;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final String rol = usuario.rol?.nombreRol ?? 'rol ${usuario.idrol}';
    return ListTile(
      title: Text(usuario.nombreUser),
      subtitle: Text('${usuario.emailUser}  ·  $rol'),
      onTap: onTap,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}
