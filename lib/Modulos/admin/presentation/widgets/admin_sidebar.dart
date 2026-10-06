import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_brand_mark.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/admin_seccion.dart';

/// Sidebar del panel de administracion.
///
/// Riel oscuro (mismo azul que la barra superior) siempre visible con solo los
/// iconos. Al pasar el mouse se despliega hacia la derecha **por encima** del
/// contenido; al salir vuelve al riel. Si [pinned] es `true` queda desplegado.
///
/// Rendimiento: durante la animacion NO se reconstruye el arbol del sidebar.
/// El cuerpo ([_SidebarBody]) se construye una sola vez por cambio de estado
/// (hover / pin) y se pasa como `child` a un `AnimatedBuilder`; cada frame solo
/// se recalcula el ancho del contenedor y el recorte (`ClipRect`), que es
/// trabajo de pintura, no de layout. El cuerpo va a ancho fijo dentro de un
/// `OverflowBox`, asi que la lista de items tampoco relayoutea al animar.
class AdminSidebar extends StatefulWidget {
  const AdminSidebar({
    super.key,
    required this.secciones,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
    this.pinned = false,
  });

  final List<AdminSeccion> secciones;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final bool pinned;

  /// Ancho del riel colapsado (solo iconos). [AdminShell] reserva este espacio.
  static const double railWidth = 64;

  /// Ancho del panel desplegado.
  static const double expandedWidth = 248;

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 170),
    value: widget.pinned ? 1 : 0,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  bool _hovering = false;

  /// Las etiquetas se muestran mientras el panel esta abierto o cerrandose;
  /// solo desaparecen al terminar el colapso, para que el cierre no "salte".
  late bool _labelsVisible = widget.pinned;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(covariant AdminSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pinned != oldWidget.pinned) _sync();
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    final bool visible = status != AnimationStatus.dismissed;
    if (visible != _labelsVisible) {
      setState(() => _labelsVisible = visible);
    }
  }

  void _setHover(bool value) {
    if (_hovering == value) return;
    _hovering = value;
    _sync();
  }

  void _sync() {
    final bool open = widget.pinned || _hovering;
    if (open) {
      if (!_labelsVisible) setState(() => _labelsVisible = true);
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _t,
          builder: (BuildContext context, Widget? child) {
            final double w = AdminSidebar.railWidth +
                (AdminSidebar.expandedWidth - AdminSidebar.railWidth) * _t.value;
            return Container(
              width: w,
              decoration: BoxDecoration(
                color: FqColors.night,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color.lerp(
                      const Color(0x000B1626),
                      const Color(0x520B1626),
                      _t.value,
                    )!,
                    blurRadius: 26,
                    offset: const Offset(8, 0),
                  ),
                ],
              ),
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: AdminSidebar.expandedWidth,
                  maxWidth: AdminSidebar.expandedWidth,
                  child: SizedBox(
                    width: AdminSidebar.expandedWidth,
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: _SidebarBody(
            secciones: widget.secciones,
            selectedIndex: widget.selectedIndex,
            showLabels: _labelsVisible,
            onSelect: widget.onSelect,
            onLogout: widget.onLogout,
          ),
        ),
      ),
    );
  }
}

class _SidebarBody extends StatelessWidget {
  const _SidebarBody({
    required this.secciones,
    required this.selectedIndex,
    required this.showLabels,
    required this.onSelect,
    required this.onLogout,
  });

  final List<AdminSeccion> secciones;
  final int selectedIndex;
  final bool showLabels;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(showLabel: showLabels),
        const _HairLine(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: secciones.length,
            itemBuilder: (BuildContext context, int i) => _SidebarItem(
              icon: secciones[i].icono,
              label: secciones[i].navLabel,
              selected: i == selectedIndex,
              showLabel: showLabels,
              onTap: () => onSelect(i),
            ),
          ),
        ),
        const _HairLine(),
        _SidebarItem(
          icon: Icons.logout,
          label: l10n.perfilCerrarSesion,
          selected: false,
          showLabel: showLabels,
          danger: true,
          onTap: onLogout,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _HairLine extends StatelessWidget {
  const _HairLine();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: Color(0x1FFFFFFF));
}

class _Header extends StatelessWidget {
  const _Header({required this.showLabel});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: AdminSidebar.railWidth,
            child: Center(child: FqBrandMark(size: 28)),
          ),
          if (showLabel)
            const Expanded(
              child: Text(
                'FitQuest Go',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: FqColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.showLabel,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = widget.danger
        ? const Color(0xFFEF9A8A)
        : widget.selected
            ? FqColors.volt
            : _hover
                ? FqColors.white
                : const Color(0xFFAAB9C9);

    final Color bg = widget.selected
        ? const Color(0x1FFFFFFF)
        : _hover
            ? const Color(0x12FFFFFF)
            : Colors.transparent;

    final Widget icon = Icon(widget.icon, size: 18, color: fg);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                width: 3,
                color: widget.selected ? FqColors.volt : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: AdminSidebar.railWidth - 16,
                child: Center(
                  child: widget.showLabel
                      ? icon
                      : Tooltip(
                          message: widget.label,
                          waitDuration: const Duration(milliseconds: 300),
                          child: icon,
                        ),
                ),
              ),
              if (widget.showLabel)
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          widget.selected ? FontWeight.w800 : FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
