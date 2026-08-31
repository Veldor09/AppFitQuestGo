import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_panel.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuarios_api.dart';
import 'package:fit_quest_go/Modulos/usuarios/presentation/widgets/paginacion_bar.dart';
import 'package:fit_quest_go/Modulos/usuarios/presentation/widgets/usuario_modal.dart';
import 'package:fit_quest_go/Modulos/usuarios/presentation/widgets/usuarios_tabla.dart';

/// ADM-02 · Usuarios. Pantalla **funcional**: consume `GET /usuarios`
/// (protegido por JWT + rol Admin) y permite ver, crear, editar y desactivar
/// cuentas. Buscador, filtro por rol y paginacion se resuelven en el cliente
/// sobre la lista real (sin datos "quemados").
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
  final GlobalKey _filtrosKey = GlobalKey();

  late Future<List<Usuario>> _futuro;

  String _filtroTexto = '';

  /// 0 = todos · 1 = Usuario · 2 = Empresa · 3 = Admin.
  int _rolFiltro = 0;

  int _pagina = 0;
  int _filasPorPagina = 5;
  static const List<int> _opcionesFilas = <int>[5, 10, 15, 20];

  static const List<String> _etiquetasRol = <String>[
    'Todos',
    'Usuario',
    'Empresa',
    'Admin',
  ];

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
    setState(() {
      _futuro = _api.list();
      _pagina = 0;
    });
  }

  List<Usuario> _filtrar(List<Usuario> todos) {
    final String q = _filtroTexto.trim().toLowerCase();
    return todos.where((Usuario u) {
      final bool rolOk = _rolFiltro == 0 || u.idrol == _rolFiltro;
      final bool textoOk = q.isEmpty ||
          u.nombreUser.toLowerCase().contains(q) ||
          u.emailUser.toLowerCase().contains(q);
      return rolOk && textoOk;
    }).toList();
  }

  List<Usuario> _paginar(List<Usuario> filtrados) {
    final int inicio = _pagina * _filasPorPagina;
    if (inicio >= filtrados.length) return const <Usuario>[];
    return filtrados.skip(inicio).take(_filasPorPagina).toList();
  }

  Future<void> _abrirModal(ModoUsuarioModal modo, [Usuario? usuario]) async {
    final bool? cambio = await UsuarioModal.abrir(
      context,
      modo: modo,
      usuario: usuario,
      api: _api,
    );
    if (!mounted) return;
    if (cambio == true) {
      _recargar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            modo == ModoUsuarioModal.crear
                ? 'Usuario creado.'
                : 'Cambios guardados.',
          ),
        ),
      );
    }
  }

  Future<void> _desactivar(Usuario u) async {
    final bool? confirmar = await _confirmarDesactivar(u);
    if (confirmar != true || !mounted) return;
    try {
      await _api.remove(u.id);
      if (!mounted) return;
      _recargar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${u.nombreUser} fue dado de baja.')),
      );
    } on ApiException catch (e) {
      _avisar(e.message);
    } catch (_) {
      _avisar('No se pudo completar la accion.');
    }
  }

  Future<bool?> _confirmarDesactivar(Usuario u) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 170),
      pageBuilder: (_, _, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            color: FqColors.white,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Desactivar usuario',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: FqColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Se dara de baja la cuenta de ${u.nombreUser}. El backend '
                    'todavia no tiene baja logica, asi que la cuenta se '
                    'eliminara de forma permanente.',
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: FqColors.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      FqButton.ghost(
                        label: 'Cancelar',
                        expand: false,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      const SizedBox(width: 8),
                      FqButton.danger(
                        label: 'Desactivar',
                        expand: false,
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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

  Future<void> _abrirMenuFiltros() async {
    final RenderBox boton =
        _filtrosKey.currentContext!.findRenderObject()! as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final RelativeRect pos = RelativeRect.fromRect(
      Rect.fromPoints(
        boton.localToGlobal(Offset.zero, ancestor: overlay),
        boton.localToGlobal(
          boton.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    final int? seleccion = await showMenu<int>(
      context: context,
      position: pos,
      items: <PopupMenuEntry<int>>[
        const PopupMenuItem<int>(
          enabled: false,
          height: 30,
          child: Text(
            'FILTRAR POR ROL',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: FqColors.muted,
            ),
          ),
        ),
        for (int i = 0; i < _etiquetasRol.length; i++)
          CheckedPopupMenuItem<int>(
            value: i,
            checked: _rolFiltro == i,
            child: Text(_etiquetasRol[i]),
          ),
      ],
    );
    if (seleccion != null && mounted) {
      setState(() {
        _rolFiltro = seleccion;
        _pagina = 0;
      });
    }
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Usuario>>(
      future: _futuro,
      builder: (BuildContext context, AsyncSnapshot<List<Usuario>> snap) {
        final bool cargando = snap.connectionState == ConnectionState.waiting;
        final String? error = snap.hasError ? _mensajeError(snap.error!) : null;

        final List<Usuario> filtrados =
            snap.hasData ? _filtrar(snap.data!) : const <Usuario>[];

        // Reajusta la pagina si quedo fuera de rango tras filtrar.
        final int totalPaginas = filtrados.isEmpty
            ? 1
            : ((filtrados.length - 1) ~/ _filasPorPagina) + 1;
        if (_pagina >= totalPaginas) _pagina = totalPaginas - 1;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _barraAcciones(),
              const SizedBox(height: FqGap.lg),
              FqPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_rolFiltro != 0) _chipFiltroActivo(),
                    UsuariosTabla(
                      usuarios: _paginar(filtrados),
                      loading: cargando,
                      error: error,
                      onReintentar: _recargar,
                      mensajeVacio: (snap.hasData && snap.data!.isNotEmpty)
                          ? 'Ningun usuario coincide con el filtro.'
                          : null,
                      onVer: (Usuario u) =>
                          _abrirModal(ModoUsuarioModal.ver, u),
                      onEditar: (Usuario u) =>
                          _abrirModal(ModoUsuarioModal.editar, u),
                      onDesactivar: _desactivar,
                    ),
                    if (!cargando && error == null && filtrados.isNotEmpty)
                      PaginacionBar(
                        total: filtrados.length,
                        pagina: _pagina,
                        filasPorPagina: _filasPorPagina,
                        opciones: _opcionesFilas,
                        onFilasPorPagina: (int n) => setState(() {
                          _filasPorPagina = n;
                          _pagina = 0;
                        }),
                        onPagina: (int p) => setState(() => _pagina = p),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _barraAcciones() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        FqButton.primary(
          key: _filtrosKey,
          label: _rolFiltro == 0
              ? 'Filtros'
              : 'Filtros: ${_etiquetasRol[_rolFiltro]}',
          icon: Icons.tune,
          expand: false,
          dense: true,
          onPressed: _abrirMenuFiltros,
        ),
        FqButton.primary(
          label: 'Nuevo usuario',
          icon: Icons.add,
          expand: false,
          dense: true,
          onPressed: () => _abrirModal(ModoUsuarioModal.crear),
        ),
        SizedBox(width: 260, child: _campoBusqueda()),
      ],
    );
  }

  Widget _campoBusqueda() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: FqRadius.allMd,
        border: Border.all(color: FqColors.searchBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search, size: 15, color: FqColors.muted),
          const SizedBox(width: 7),
          Expanded(
            child: TextField(
              controller: _busqueda,
              onChanged: (String v) => setState(() {
                _filtroTexto = v;
                _pagina = 0;
              }),
              style: const TextStyle(fontSize: 11, color: FqColors.ink),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                hintText: 'Buscar en usuarios',
                hintStyle: TextStyle(fontSize: 11, color: FqColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipFiltroActivo() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FqColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      child: Row(
        children: <Widget>[
          const Text(
            'Filtro:',
            style: TextStyle(fontSize: 10, color: FqColors.muted),
          ),
          const SizedBox(width: 8),
          InputChip(
            label: Text(_etiquetasRol[_rolFiltro]),
            labelStyle: const TextStyle(fontSize: 10, color: FqColors.ink),
            visualDensity: VisualDensity.compact,
            backgroundColor: FqColors.cloud,
            side: const BorderSide(color: FqColors.border),
            onDeleted: () => setState(() {
              _rolFiltro = 0;
              _pagina = 0;
            }),
          ),
        ],
      ),
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
