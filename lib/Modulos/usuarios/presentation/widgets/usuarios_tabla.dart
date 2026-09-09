import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

/// Tabla de usuarios: Nombre / Correo / Rol / Estado / Acciones.
///
/// Acciones por fila: Ver, Editar y Activar/Desactivar (segun el estado). La
/// fila del propio usuario ([miId]) no ofrece el cambio de estado.
class UsuariosTabla extends StatelessWidget {
  const UsuariosTabla({
    super.key,
    required this.usuarios,
    required this.onVer,
    required this.onEditar,
    required this.onCambiarEstado,
    this.miId,
    this.loading = false,
    this.error,
    this.onReintentar,
    this.mensajeVacio,
  });

  final List<Usuario> usuarios;
  final ValueChanged<Usuario> onVer;
  final ValueChanged<Usuario> onEditar;
  final ValueChanged<Usuario> onCambiarEstado;
  final int? miId;
  final bool loading;
  final String? error;
  final VoidCallback? onReintentar;
  final String? mensajeVacio;

  static const double _minWidth = 900;

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
                  esYo: u.id == miId,
                  onVer: () => onVer(u),
                  onEditar: () => onEditar(u),
                  onCambiarEstado: () => onCambiarEstado(u),
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
const int _flexEstado = 2;
const double _anchoAcciones = 252;

FqTagTone _tonoRol(int idrol) {
  switch (idrol) {
    case 3:
      return FqTagTone.dark;
    case 2:
      return FqTagTone.amber;
    default:
      return FqTagTone.green;
  }
}

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
          Expanded(flex: _flexEstado, child: Text('ESTADO', style: estilo)),
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
    required this.esYo,
    required this.onVer,
    required this.onEditar,
    required this.onCambiarEstado,
  });

  final Usuario usuario;
  final bool esYo;
  final VoidCallback onVer;
  final VoidCallback onEditar;
  final VoidCallback onCambiarEstado;

  @override
  State<_Fila> createState() => _FilaState();
}

class _FilaState extends State<_Fila> {
  bool _hover = false;

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
                child: FqTag(u.etiquetaRol, tone: _tonoRol(u.idrol)),
              ),
            ),
            Expanded(
              flex: _flexEstado,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FqTag(
                  u.estado,
                  tone: u.activo ? FqTagTone.green : FqTagTone.neutral,
                ),
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
                  if (widget.esYo)
                    const Tooltip(
                      message: 'No puedes desactivar tu propia cuenta',
                      child: _AccionBtn(
                        label: 'Desactivar',
                        color: FqColors.stone,
                        onTap: null,
                      ),
                    )
                  else
                    _AccionBtn(
                      label: u.activo ? 'Desactivar' : 'Activar',
                      color: u.activo ? FqColors.risk : FqColors.trail,
                      onTap: widget.onCambiarEstado,
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
  final VoidCallback? onTap;

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
