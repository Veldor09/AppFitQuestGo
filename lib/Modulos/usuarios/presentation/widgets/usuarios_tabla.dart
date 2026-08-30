import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

/// Tabla de usuarios con columnas Nombre / Correo / Rol / Acciones.
///
/// Las acciones por fila son Ver, Editar y Desactivar. Gestiona sus estados de
/// carga / error / vacio. En pantallas angostas la tabla scrollea en horizontal
/// para no comprimir las columnas.
class UsuariosTabla extends StatelessWidget {
  const UsuariosTabla({
    super.key,
    required this.usuarios,
    required this.onVer,
    required this.onEditar,
    required this.onDesactivar,
    this.loading = false,
    this.error,
    this.onReintentar,
    this.mensajeVacio,
  });

  final List<Usuario> usuarios;
  final ValueChanged<Usuario> onVer;
  final ValueChanged<Usuario> onEditar;
  final ValueChanged<Usuario> onDesactivar;
  final bool loading;
  final String? error;
  final VoidCallback? onReintentar;
  final String? mensajeVacio;

  static const double _minWidth = 780;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return FqEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No se pudo cargar',
        message: error,
        action: onReintentar == null
            ? null
            : TextButton(
                onPressed: onReintentar,
                child: const Text('Reintentar'),
              ),
      );
    }
    if (usuarios.isEmpty) {
      return FqEmptyState(
        icon: Icons.group_outlined,
        title: 'Sin usuarios',
        message: mensajeVacio ??
            'Crea el primer usuario con el boton "Nuevo usuario".',
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double width = c.maxWidth < _minWidth ? _minWidth : c.maxWidth;
        final Widget tabla = SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const _EncabezadoFila(),
              for (final Usuario u in usuarios)
                _Fila(
                  usuario: u,
                  onVer: () => onVer(u),
                  onEditar: () => onEditar(u),
                  onDesactivar: () => onDesactivar(u),
                ),
            ],
          ),
        );
        if (c.maxWidth < _minWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: tabla,
          );
        }
        return tabla;
      },
    );
  }
}

const int _flexNombre = 3;
const int _flexCorreo = 4;
const int _flexRol = 2;
const double _anchoAcciones = 252;

class _EncabezadoFila extends StatelessWidget {
  const _EncabezadoFila();

  @override
  Widget build(BuildContext context) {
    const TextStyle estilo = TextStyle(
      fontSize: 8,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.7,
      color: FqColors.muted,
    );
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FqColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: const <Widget>[
          Expanded(flex: _flexNombre, child: Text('NOMBRE', style: estilo)),
          Expanded(flex: _flexCorreo, child: Text('CORREO', style: estilo)),
          Expanded(flex: _flexRol, child: Text('ROL', style: estilo)),
          SizedBox(
            width: _anchoAcciones,
            child: Text('ACCIONES', style: estilo, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _Fila extends StatefulWidget {
  const _Fila({
    required this.usuario,
    required this.onVer,
    required this.onEditar,
    required this.onDesactivar,
  });

  final Usuario usuario;
  final VoidCallback onVer;
  final VoidCallback onEditar;
  final VoidCallback onDesactivar;

  @override
  State<_Fila> createState() => _FilaState();
}

class _FilaState extends State<_Fila> {
  bool _hover = false;

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
    final Usuario u = widget.usuario;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: _hover ? FqColors.rowHover : FqColors.white,
          border: const Border(bottom: BorderSide(color: FqColors.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: _flexNombre,
              child: Text(
                u.nombreUser,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: FqColors.ink,
                ),
              ),
            ),
            Expanded(
              flex: _flexCorreo,
              child: Text(
                u.emailUser,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: FqColors.muted),
              ),
            ),
            Expanded(
              flex: _flexRol,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FqTag(u.etiquetaRol, tone: _tono(u.idrol)),
              ),
            ),
            SizedBox(
              width: _anchoAcciones,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 2,
                children: <Widget>[
                  _AccionBtn(
                    label: 'Ver',
                    color: FqColors.river,
                    onTap: widget.onVer,
                  ),
                  _AccionBtn(
                    label: 'Editar',
                    color: FqColors.ink,
                    onTap: widget.onEditar,
                  ),
                  _AccionBtn(
                    label: 'Desactivar',
                    color: FqColors.risk,
                    onTap: widget.onDesactivar,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccionBtn extends StatelessWidget {
  const _AccionBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
