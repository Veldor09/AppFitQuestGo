import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Los pines con icono que se dibujan en los mapas, uno por cosa que se puede
/// ver: el local de una empresa, una zona de evento, el inicio y el final de
/// un recorrido y de una ruta.
enum TipoPin {
  /// Un nodo de abastecimiento (el local de una empresa).
  local,

  /// Una zona (area) de un evento: el pin va en el centro.
  area,

  /// Donde sale y donde termina el recorrido de un evento.
  recorridoInicio,
  recorridoFin,

  /// Donde sale y donde termina una ruta de un deportista.
  rutaInicio,
  rutaFin,
}

/// Como se ve un pin: el icono, su color y el color del circulo.
class EstiloPin {
  const EstiloPin({
    required this.icono,
    required this.fondo,
    this.colorIcono = Colors.white,
  });

  final IconData icono;
  final Color fondo;
  final Color colorIcono;
}

/// El estilo de cada pin. Con [secundario] el circulo va en gris: son pines de
/// cosas de otras empresas, que no deben confundirse con las propias.
EstiloPin estiloPin(TipoPin tipo, {bool secundario = false}) {
  final EstiloPin base = switch (tipo) {
    TipoPin.local => const EstiloPin(
      icono: Icons.storefront_rounded,
      fondo: FqColors.volt,
      colorIcono: FqColors.night,
    ),
    TipoPin.area => const EstiloPin(
      icono: Icons.flag_rounded,
      fondo: FqColors.purple,
    ),
    TipoPin.recorridoInicio => const EstiloPin(
      icono: Icons.directions_walk_rounded,
      fondo: FqColors.river,
    ),
    TipoPin.recorridoFin => const EstiloPin(
      icono: Icons.sports_score_rounded,
      fondo: FqColors.river,
    ),
    TipoPin.rutaInicio => const EstiloPin(
      icono: Icons.play_arrow_rounded,
      fondo: FqColors.voltDark,
    ),
    TipoPin.rutaFin => const EstiloPin(
      icono: Icons.sports_score_rounded,
      fondo: FqColors.risk,
    ),
  };
  if (!secundario) return base;
  return EstiloPin(icono: base.icono, fondo: FqColors.muted);
}

/// Alto y ancho, en pixeles, de la imagen de un pin. Se dibuja a 3x de su
/// tamaño en pantalla (36) para que se vea nitido en celulares de alta densidad.
const int kPinPx = 108;

/// Cuanto hay que achicar la imagen en el mapa para que el pin mida 36 en
/// pantalla: la inversa del 3x con el que se dibuja.
const double kPinIconSize = 1 / 3;

final Map<String, Future<Uint8List>> _cache = <String, Future<Uint8List>>{};

/// La imagen PNG del pin [tipo]. Se dibuja una vez y se reutiliza.
Future<Uint8List> imagenPin(TipoPin tipo, {bool secundario = false}) {
  return _cache.putIfAbsent('${tipo.name}-$secundario', () {
    final EstiloPin e = estiloPin(tipo, secundario: secundario);
    return dibujarPin(icono: e.icono, fondo: e.fondo, colorIcono: e.colorIcono);
  });
}

/// Dibuja un pin: un circulo de color con borde blanco y sombra suave, y el
/// [icono] en el centro. Devuelve una imagen PNG cuadrada de [px] pixeles.
///
/// Los iconos son los de Material (vienen con Flutter): sin descargas, sin
/// licencias que atribuir y nitidos a cualquier tamaño.
Future<Uint8List> dibujarPin({
  required IconData icono,
  required Color fondo,
  Color colorIcono = Colors.white,
  int px = kPinPx,
}) async {
  final double lado = px.toDouble();
  final ui.PictureRecorder grabadora = ui.PictureRecorder();
  final Canvas lienzo = Canvas(grabadora, Rect.fromLTWH(0, 0, lado, lado));
  final Offset centro = Offset(lado / 2, lado / 2);
  final double radio = lado / 2 - lado * 0.07;

  // Sombra, borde blanco y relleno de color.
  lienzo.drawCircle(
    centro.translate(0, lado * 0.025),
    radio,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, lado * 0.03),
  );
  lienzo.drawCircle(centro, radio, Paint()..color = Colors.white);
  lienzo.drawCircle(centro, radio - lado * 0.06, Paint()..color = fondo);

  // El icono es una letra de la fuente de iconos.
  final TextPainter pintor = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icono.codePoint),
      style: TextStyle(
        fontSize: lado * 0.5,
        fontFamily: icono.fontFamily,
        package: icono.fontPackage,
        color: colorIcono,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  pintor.paint(lienzo, centro - Offset(pintor.width / 2, pintor.height / 2));

  final ui.Image imagen = await grabadora.endRecording().toImage(px, px);
  final ByteData? datos = await imagen.toByteData(
    format: ui.ImageByteFormat.png,
  );
  return datos!.buffer.asUint8List();
}
