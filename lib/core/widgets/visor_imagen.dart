import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

Future<void> mostrarVisorImagen(
  BuildContext context,
  Uint8List bytes, {
  String? titulo,
  VoidCallback? alReportar,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (BuildContext _, Animation<double> _, Animation<double> _) =>
          VisorImagen(bytes: bytes, titulo: titulo, alReportar: alReportar),
      transitionsBuilder:
          (
            BuildContext _,
            Animation<double> animacion,
            Animation<double> _,
            Widget hijo,
          ) => FadeTransition(opacity: animacion, child: hijo),
    ),
  );
}

class VisorImagen extends StatefulWidget {
  const VisorImagen({
    super.key,
    required this.bytes,
    this.titulo,
    this.alReportar,
  });

  final Uint8List bytes;
  final String? titulo;

  final VoidCallback? alReportar;

  @override
  State<VisorImagen> createState() => _VisorImagenState();
}

class _VisorImagenState extends State<VisorImagen>
    with SingleTickerProviderStateMixin {
  static const double _zoomDobleToque = 2.5;

  final TransformationController _transformacion = TransformationController();
  Offset _ultimoToque = Offset.zero;

  @override
  void dispose() {
    _transformacion.dispose();
    super.dispose();
  }

  void _dobleToque() {
    final bool acercada = _transformacion.value.getMaxScaleOnAxis() > 1.05;
    if (acercada) {
      _transformacion.value = Matrix4.identity();
      return;
    }
    final Offset p = _ultimoToque;
    _transformacion.value = Matrix4.identity()
      ..translateByDouble(
        -p.dx * (_zoomDobleToque - 1),
        -p.dy * (_zoomDobleToque - 1),
        0,
        1,
      )
      ..scaleByDouble(_zoomDobleToque, _zoomDobleToque, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      key: const ValueKey<String>('visor-imagen'),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (TapDownDetails d) =>
                _ultimoToque = d.localPosition,
            onDoubleTap: _dobleToque,
            child: InteractiveViewer(
              transformationController: _transformacion,
              minScale: 1,
              maxScale: 6,
              child: Center(
                child: Image.memory(
                  widget.bytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: const ValueKey<String>('cerrar-visor'),
                    tooltip: l10n.fichaCerrar,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
          ),
          if (widget.alReportar != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: Colors.black54,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      key: const ValueKey<String>('reportar-foto'),
                      customBorder: const StadiumBorder(),
                      onTap: widget.alReportar,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.flag_outlined,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.reportarFotoBoton,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (widget.titulo != null)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text(
                    widget.titulo!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
