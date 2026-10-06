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

  Future<void> _cerrarSesion() async {
    await AuthScope.read(context).cerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    final UsuarioSesion? usuario = AuthScope.of(context).usuario;

    if (usuario == null || !usuario.esAdmin) {
      return _AccesoDenegado(onSalir: _cerrarSesion);
    }

    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<AdminSeccion> secciones = buildAdminSecciones(l10n);
    final AdminSeccion actual = secciones[_seleccion];

    return Scaffold(
      backgroundColor: FqColors.adminBg,
      body: Column(
        children: <Widget>[
          AdminTopBar(
            title: actual.headerTitle,
            userInitials: usuario.iniciales,
            onToggleSidebar: () =>
                setState(() => _sidebarFijo = !_sidebarFijo),
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                // El contenido arranca despues del riel; el sidebar se
                // despliega por encima sin redimensionarlo. El RepaintBoundary
                // aisla el contenido de los repintados del sidebar al animar.
                Positioned.fill(
                  left: AdminSidebar.railWidth,
                  child: RepaintBoundary(
                    child: ColoredBox(
                      color: FqColors.adminBg,
                      child: _LazyIndexedStack(
                        index: _seleccion,
                        itemCount: secciones.length,
                        itemBuilder: (BuildContext context, int i) =>
                            KeyedSubtree(
                          key: ValueKey<String>(secciones[i].code),
                          child: Builder(builder: secciones[i].builder),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  bottom: 0,
                  child: AdminSidebar(
                    secciones: secciones,
                    selectedIndex: _seleccion,
                    pinned: _sidebarFijo,
                    onSelect: (int i) => setState(() => _seleccion = i),
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

/// `IndexedStack` que solo construye las secciones ya visitadas y las mantiene
/// vivas despues. Cambiar de seccion es instantaneo (no hay reconstruccion ni
/// nuevas llamadas de red: p. ej. la lista de "Usuarios" conserva sus datos).
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
        if (!_visitadas.contains(i)) return const SizedBox.shrink();
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
