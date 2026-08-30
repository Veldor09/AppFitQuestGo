import 'package:flutter/material.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuarios_api.dart';
import 'package:fit_quest_go/Modulos/usuarios/presentation/usuario_form_screen.dart';
import 'package:fit_quest_go/Modulos/usuarios/presentation/widgets/usuario_tile.dart';

class UsuariosListScreen extends StatefulWidget {
  const UsuariosListScreen({super.key});

  @override
  State<UsuariosListScreen> createState() => _UsuariosListScreenState();
}

class _UsuariosListScreenState extends State<UsuariosListScreen> {
  final UsuariosApi _api = UsuariosApi();
  late Future<List<Usuario>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.list();
  }

  void _refresh() {
    setState(() {
      _future = _api.list();
    });
  }

  Future<void> _abrirForm([Usuario? usuario]) async {
    final bool? guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UsuarioFormScreen(usuario: usuario),
      ),
    );
    if (!mounted) return;
    if (guardado == true) _refresh();
  }

  Future<void> _borrar(Usuario usuario) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar a ${usuario.nombreUser}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _api.remove(usuario.id);
      if (!mounted) return;
      _refresh();
    } on ApiException catch (e) {
      _mostrarError(e.message);
    } catch (e) {
      _mostrarError('$e');
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirForm,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Usuario>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              mensaje: snapshot.error.toString(),
              onReintentar: _refresh,
            );
          }
          final List<Usuario> usuarios = snapshot.data ?? const <Usuario>[];
          if (usuarios.isEmpty) {
            return const Center(child: Text('Sin usuarios todavía'));
          }
          return ListView.separated(
            itemCount: usuarios.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final Usuario u = usuarios[i];
              return UsuarioTile(
                usuario: u,
                onTap: () => _abrirForm(u),
                onDelete: () => _borrar(u),
              );
            },
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
