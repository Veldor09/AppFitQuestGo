import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';

/// Tipo (y color) de una notificacion.
enum TipoNotificacion { exito, error, info }

/// Muestra una notificacion de exito ("Inicio de sesion exitoso", ...).
void notificarExito(String mensaje) =>
    NotificacionesHost.mostrar(mensaje, TipoNotificacion.exito);

/// Muestra una notificacion de error (fallo de guardado, credenciales, ...).
void notificarError(String mensaje) =>
    NotificacionesHost.mostrar(mensaje, TipoNotificacion.error);

/// Muestra una notificacion informativa ("Correo enviado", ...).
void notificarInfo(String mensaje) =>
    NotificacionesHost.mostrar(mensaje, TipoNotificacion.info);

/// Contenedor global de notificaciones. Se monta una sola vez, por encima del
/// `Navigator`, via `MaterialApp.builder`, de modo que las notificaciones
/// aparecen sobre cualquier pantalla o modal y se pueden disparar desde
/// cualquier parte sin `BuildContext`.
class NotificacionesHost extends StatefulWidget {
  const NotificacionesHost({super.key, required this.child});

  final Widget child;

  static _NotificacionesHostState? _estado;

  static void mostrar(String mensaje, TipoNotificacion tipo) {
    _estado?._agregar(mensaje, tipo);
  }

  @override
  State<NotificacionesHost> createState() => _NotificacionesHostState();
}

class _NotificacionesHostState extends State<NotificacionesHost> {
  final List<_Aviso> _avisos = <_Aviso>[];
  int _secuencia = 0;

  @override
  void initState() {
    super.initState();
    NotificacionesHost._estado = this;
  }

  @override
  void dispose() {
    if (NotificacionesHost._estado == this) NotificacionesHost._estado = null;
    super.dispose();
  }

  void _agregar(String mensaje, TipoNotificacion tipo) {
    if (!mounted) return;
    setState(() {
      _avisos.insert(0, _Aviso(id: _secuencia++, mensaje: mensaje, tipo: tipo));
      if (_avisos.length > 5) _avisos.removeLast();
    });
  }

  void _quitar(int id) {
    if (!mounted) return;
    setState(() => _avisos.removeWhere((_Aviso a) => a.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.child,
        Positioned(
          top: 12,
          right: 12,
          left: 12,
          child: SafeArea(
            left: false,
            right: false,
            bottom: false,
            child: Align(
              alignment: Alignment.topRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    for (final _Aviso a in _avisos)
                      _Toast(
                        key: ValueKey<int>(a.id),
                        aviso: a,
                        onCerrar: () => _quitar(a.id),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Aviso {
  const _Aviso({required this.id, required this.mensaje, required this.tipo});

  final int id;
  final String mensaje;
  final TipoNotificacion tipo;
}

class _Toast extends StatefulWidget {
  const _Toast({super.key, required this.aviso, required this.onCerrar});

  final _Aviso aviso;
  final VoidCallback onCerrar;

  @override
  State<_Toast> createState() => _ToastState();
}


const List<BoxShadow> _sombraToast = <BoxShadow>[
  BoxShadow(color: Color(0x14101828), blurRadius: 3, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x1F13233F), blurRadius: 14, offset: Offset(0, 8)),
];

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final CurvedAnimation _t =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _entrada = Tween<Offset>(
    begin: const Offset(0.12, 0),
    end: Offset.zero,
  ).animate(_t);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(seconds: 4), _cerrar);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _t.dispose();
    _c.dispose();
    super.dispose();
  }

  Future<void> _cerrar() async {
    _timer?.cancel();
    if (!mounted) return;
    await _c.reverse();
    if (mounted) widget.onCerrar();
  }

  ({Color color, IconData icono}) get _estilo {
    switch (widget.aviso.tipo) {
      case TipoNotificacion.exito:
        return (color: FqColors.voltDark, icono: Icons.check_circle_rounded);
      case TipoNotificacion.error:
        return (color: FqColors.risk, icono: Icons.error_rounded);
      case TipoNotificacion.info:
        return (color: FqColors.river, icono: Icons.info_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ({Color color, IconData icono}) e = _estilo;

    return SizeTransition(
      sizeFactor: _t,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _t,
        child: SlideTransition(
          position: _entrada,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            // `Material` transparente: da el ancestro que necesita el boton de
            // cerrar sin pintar nada (el fondo lo pone el `Container`).
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                decoration: BoxDecoration(
                  color: FqColors.white,
                  borderRadius: FqRadius.allLg,
                  border: Border.all(color: FqColors.border),
                  boxShadow: _sombraToast,
                ),
                clipBehavior: Clip.antiAlias,
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Container(width: 4, color: e.color),
                      const SizedBox(width: 11),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        child: Icon(e.icono, size: 18, color: e.color),
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Text(
                            widget.aviso.mensaje,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: FqColors.ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        onPressed: _cerrar,
                        icon: const Icon(Icons.close_rounded, size: 15),
                        color: FqColors.muted,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
