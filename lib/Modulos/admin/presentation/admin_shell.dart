import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/admin_registro.dart';
import 'package:fit_quest_go/Modulos/admin/data/admin_seccion.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_sidebar.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_top_bar.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

/// Contenedor del panel de administracion: barra superior + sidebar con hover +
/// area de contenido conmutable.
///
/// Solo se permite el acceso a usuarios con rol Admin. `_RootGate` ya realiza
/// esa comprobacion, pero el shell la repite como defensa en profundidad.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _seleccion = 0;
  bool _sidebarFijo = false;
  bool _sidebarMovilAbierto = false;

  /// Usuario seleccionado en ADM-02 para visualizarlo en ADM-03.
  ///
  /// ValueNotifier permite actualizar el detalle incluso cuando ADM-03
  /// ya fue visitado y su widget permanece dentro de _LazyIndexedStack.
  final ValueNotifier<Usuario?> _usuarioSeleccionado = ValueNotifier<Usuario?>(
    null,
  );

  /// Indices de las secciones dentro del registro administrativo.
  static const int _indiceUsuarios = 1;
  static const int _indiceDetalleUsuario = 2;

  /// Abre ADM-03 con el usuario seleccionado.
  void _abrirDetalleUsuario(Usuario usuario) {
    if (!mounted) return;

    _usuarioSeleccionado.value = usuario;

    setState(() {
      _seleccion = _indiceDetalleUsuario;
      _sidebarMovilAbierto = false;
    });
  }

  /// Regresa a ADM-02 conservando su busqueda, filtros y paginacion.
  void _volverUsuarios() {
    if (!mounted) return;

    setState(() {
      _seleccion = _indiceUsuarios;
      _sidebarMovilAbierto = false;
    });
  }

  Future<void> _cerrarSesion() async {
    await AuthScope.read(context).cerrarSesion();
  }

  @override
  void dispose() {
    _usuarioSeleccionado.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UsuarioSesion? usuario = AuthScope.of(context).usuario;

    if (usuario == null || !usuario.esAdmin) {
      return _AccesoDenegado(onSalir: _cerrarSesion);
    }

    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final List<AdminSeccion> secciones = buildAdminSecciones(
      l10n,
      usuarioSeleccionado: _usuarioSeleccionado,
      onVerDetalle: _abrirDetalleUsuario,
      onVolverUsuarios: _volverUsuarios,
    );

    final AdminSeccion actual = secciones[_seleccion];
    final bool esMovil = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: FqColors.adminBg,
      body: Column(
        children: <Widget>[
          AdminTopBar(
            title: actual.headerTitle,
            userInitials: usuario.iniciales,
            onToggleSidebar: () {
              setState(() {
                if (esMovil) {
                  _sidebarMovilAbierto = !_sidebarMovilAbierto;
                } else {
                  _sidebarFijo = !_sidebarFijo;
                }
              });
            },
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                // En dispositivos moviles, el contenido utiliza todo el ancho.
                // En escritorio, comienza despues del riel lateral.
                //
                // RepaintBoundary aisla el contenido de los repintados
                // del sidebar al animar.
                Positioned.fill(
                  left: esMovil ? 0 : AdminSidebar.railWidth,
                  child: RepaintBoundary(
                    child: ColoredBox(
                      color: FqColors.adminBg,
                      child: _LazyIndexedStack(
                        index: _seleccion,
                        itemCount: secciones.length,
                        itemBuilder: (BuildContext context, int i) {
                          return KeyedSubtree(
                            key: ValueKey<String>(secciones[i].code),
                            child: Builder(builder: secciones[i].builder),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Fondo oscuro para cerrar el menu en dispositivos moviles.
                if (esMovil && _sidebarMovilAbierto)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _sidebarMovilAbierto = false;
                        });
                      },
                      child: Container(color: Colors.black54),
                    ),
                  ),

                // Sidebar responsive: siempre visible en escritorio
                // y desplegable en dispositivos moviles.
                if (!esMovil || _sidebarMovilAbierto)
                  Positioned(
                    top: 0,
                    left: 0,
                    bottom: 0,
                    child: AdminSidebar(
                      secciones: secciones,
                      selectedIndex: _seleccion,
                      pinned: esMovil ? true : _sidebarFijo,
                      onSelect: (int i) {
                        setState(() {
                          _seleccion = i;

                          if (esMovil) {
                            _sidebarMovilAbierto = false;
                          }
                        });
                      },
                      onLogout: _cerrarSesion,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// IndexedStack que solo construye las secciones ya visitadas y las mantiene
/// vivas despues.
///
/// Cambiar de seccion es instantaneo: la lista de Usuarios conserva sus
/// datos, filtros y paginacion.
///
/// ADM-03 escucha el ValueNotifier del usuario seleccionado, por lo que
/// puede mostrar otro usuario sin reconstruir todo el panel.
class _LazyIndexedStack extends StatefulWidget {
  const _LazyIndexedStack({
    required this.index,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int index;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  final Set<int> _visitadas = <int>{};

  @override
  void initState() {
    super.initState();
    _visitadas.add(widget.index);
  }

  @override
  void didUpdateWidget(covariant _LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visitadas.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      sizing: StackFit.expand,
      children: List<Widget>.generate(widget.itemCount, (int i) {
        if (!_visitadas.contains(i)) {
          return const SizedBox.shrink();
        }

        return widget.itemBuilder(context, i);
      }),
    );
  }
}

class _AccesoDenegado extends StatelessWidget {
  const _AccesoDenegado({required this.onSalir});

  final VoidCallback onSalir;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: FqColors.adminBg,
      body: FqEmptyState(
        icon: Icons.lock_outline,
        title: l10n.admAccesoRestringidoTitulo,
        message: l10n.admAccesoRestringidoMensaje,
        action: TextButton(
          onPressed: onSalir,
          child: Text(l10n.perfilCerrarSesion),
        ),
      ),
    );
  }
}
