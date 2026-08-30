import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_list_scaffold.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuarios_api.dart';
import 'package:fit_quest_go/Modulos/usuarios/presentation/usuario_detalle_screen.dart';
import 'package:fit_quest_go/Modulos/usuarios/presentation/widgets/usuario_form_dialog.dart';

/// ADM-02 · Usuarios. Pantalla **funcional**: consume `GET /usuarios`
/// (protegido por JWT + rol Admin) y permite crear, editar y eliminar cuentas.
///
/// El buscador y las pestanas filtran en cliente sobre la lista real; no hay
/// datos "quemados".
class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key, this.api});

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final UsuariosApi? api;

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  late final UsuariosApi _api = widget.api ?? UsuariosApi();
  final TextEditingController _busqueda = TextEditingController();

  late Future<List<Usuario>> _futuro;
  int _tab = 0;
  String _filtro = '';

  /// Cada pestana filtra por rol (0 = todos).
  static const List<String> _tabs = <String>[
    'Todos',
    'Usuarios',
    'Empresas',
    'Admins',
  ];
  static const List<int?> _tabRol = <int?>[null, 1, 2, 3];

  @override
  void initState() {
    super.initState();
    _futuro = _api.list();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  void _recargar() {
    setState(() => _futuro = _api.list());
  }

  Future<void> _abrirForm([Usuario? usuario]) async {
    final bool? guardado =
        await UsuarioFormDialog.mostrar(context, usuario: usuario, api: _api);
    if (!mounted) return;
    if (guardado == true) {
      _recargar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario guardado.')),
      );
    }
  }

  Future<void> _abrirDetalle(Usuario usuario) async {
    final bool? cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UsuarioDetalleScreen(usuarioId: usuario.id, api: _api),
      ),
    );
    if (!mounted) return;
    if (cambio == true) _recargar();
  }

  List<Usuario> _aplicarFiltros(List<Usuario> todos) {
    final int? rol = _tabRol[_tab];
    final String q = _filtro.trim().toLowerCase();
    return todos.where((Usuario u) {
      final bool coincideRol = rol == null || u.idrol == rol;
      final bool coincideTexto = q.isEmpty ||
          u.nombreUser.toLowerCase().contains(q) ||
          u.emailUser.toLowerCase().contains(q);
      return coincideRol && coincideTexto;
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Usuario>>(
      future: _futuro,
      builder: (BuildContext context, AsyncSnapshot<List<Usuario>> snap) {
        final bool cargando =
            snap.connectionState == ConnectionState.waiting;
        final String? error = snap.hasError ? _mensajeError(snap.error!) : null;

        final List<Usuario> visibles =
            snap.hasData ? _aplicarFiltros(snap.data!) : const <Usuario>[];

        final List<AdminRow> filas = visibles
            .map(
              (Usuario u) => AdminRow(
                icon: Icons.person_outline,
                title: u.nombreUser,
                subtitle: '${u.emailUser}  ·  ID ${u.id}',
                trailing: FqTag(u.nombreRol, tone: _tono(u.idrol)),
                onTap: () => _abrirDetalle(u),
              ),
            )
            .toList();

        return AdminListScaffold(
          searchHint: 'Buscar en usuarios',
          searchController: _busqueda,
          onSearch: (String v) => setState(() => _filtro = v),
          tabs: _tabs,
          tabIndex: _tab,
          onTab: (int i) => setState(() => _tab = i),
          toolbarTrailing: FqButton.primary(
            label: 'Nuevo usuario',
            icon: Icons.add,
            expand: false,
            dense: true,
            onPressed: () => _abrirForm(),
          ),
          child: AdminDataTable(
            rows: filas,
            loading: cargando,
            error: error,
            onRetry: _recargar,
            emptyTitle: 'Sin usuarios',
            emptyMessage: snap.hasData && (snap.data!.isNotEmpty)
                ? 'Ningun usuario coincide con el filtro.'
                : 'Crea el primer usuario con el boton "Nuevo usuario".',
          ),
        );
      },
    );
  }

  String _mensajeError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'Tu sesion no tiene permiso para ver usuarios.';
      }
      return error.message;
    }
    return 'No se pudo conectar con el servidor.';
  }
}
