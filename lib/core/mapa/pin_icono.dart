import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Los pines con icono que se dibujan en los mapas, uno por cosa que se puede
/// ver: el local de una empresa, una zona de evento, el inicio y el final de
/// un recorrido y de una ruta. (Los puntos de interes tienen un pin por
/// categoria: ver [estiloPinNodo].)
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

/// Como se ve un pin: el icono, su color y el color del icono.
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

/// El estilo de cada pin. Con [secundario] la gota va en gris: son pines de
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

/// El pin de un punto de interes segun su categoria (las claves de
/// `categoriasNodo`): cada una con su icono, como en Google Maps. Una categoria
/// desconocida (y "otro") usa un pin gris generico.
///
/// Los colores siguen los de las tarjetas de nodos; ninguna usa el rojo de las
/// alertas.
EstiloPin estiloPinNodo(String categoria) {
  switch (categoria) {
    case 'agua':
      return const EstiloPin(
        icono: Icons.water_drop_rounded,
        fondo: FqColors.river,
      );
    case 'mirador':
      return const EstiloPin(
        icono: Icons.landscape_rounded,
        fondo: FqColors.amber,
      );
    case 'taller':
      return const EstiloPin(
        icono: Icons.build_rounded,
        fondo: FqColors.purple,
      );
    case 'restaurante':
      return const EstiloPin(
        icono: Icons.restaurant_rounded,
        fondo: FqColors.pink,
      );
    case 'comercio':
      return const EstiloPin(
        icono: Icons.shopping_bag_rounded,
        fondo: FqColors.pink,
      );
    case 'banos':
      return const EstiloPin(icono: Icons.wc_rounded, fondo: FqColors.trail);
    case 'parqueo':
      return const EstiloPin(
        icono: Icons.local_parking_rounded,
        fondo: FqColors.night2,
      );
    case 'primeros_auxilios':
      return const EstiloPin(
        icono: Icons.medical_services_rounded,
        fondo: FqColors.voltDark,
      );
    default:
      return const EstiloPin(icono: Icons.place_rounded, fondo: FqColors.muted);
  }
}

/// Ancho y alto, en pixeles, de la imagen de un pin: 3x de su tamaño en
/// pantalla (44 x 56) para que se vea nitido en celulares de alta densidad.
const int kPinAncho = 132;
const int kPinAlto = 168;

/// El `iconSize` con el que el mapa dibuja un pin para que mida 44 de ancho en
/// pantalla, cualquiera sea la densidad.
///
/// Mapbox trata los pixeles de la imagen como pixeles fisicos: una imagen de
/// 132 px con `iconSize` 1 mide 132 / [densidad] en pantalla. Para que mida 44
/// hay que escalarla por `densidad / 3`.
double iconSizePin(double densidad) => densidad / 3;

final Map<String, Future<Uint8List>> _cache = <String, Future<Uint8List>>{};

/// La imagen PNG del pin [tipo]. Se dibuja una vez y se reutiliza.
Future<Uint8List> imagenPin(TipoPin tipo, {bool secundario = false}) {
  return _imagenDe(estiloPin(tipo, secundario: secundario));
}

/// La imagen PNG del pin de la categoria [categoria] de un punto de interes.
Future<Uint8List> imagenPinNodo(String categoria) {
  return _imagenDe(estiloPinNodo(categoria));
}

Future<Uint8List> _imagenDe(EstiloPin e) {
  final String clave =
      '${e.icono.codePoint}-${e.fondo.toARGB32()}-${e.colorIcono.toARGB32()}';
  return _cache.putIfAbsent(
    clave,
    () => dibujarPin(icono: e.icono, fondo: e.fondo, colorIcono: e.colorIcono),
  );
}

/// Dibuja un pin con forma de gota (como los de Google Maps): una cabeza
/// redonda de color con borde blanco y sombra suave, una punta hacia abajo y el
/// [icono] en el centro de la cabeza. La punta queda en el centro del borde
/// inferior de la imagen: ahi se ancla al mapa.
///
/// Los iconos son los de Material (vienen con Flutter): sin descargas, sin
/// licencias que atribuir y nitidos a cualquier tamaño.
Future<Uint8List> dibujarPin({
  required IconData icono,
  required Color fondo,
  Color colorIcono = Colors.white,
  int ancho = kPinAncho,
  int alto = kPinAlto,
}) async {
  final double w = ancho.toDouble();
  final double h = alto.toDouble();
  final ui.PictureRecorder grabadora = ui.PictureRecorder();
  final Canvas lienzo = Canvas(grabadora, Rect.fromLTWH(0, 0, w, h));

  final double margen = w * 0.07;
  final double radio = w / 2 - margen;
  final Offset centro = Offset(w / 2, margen + radio);
  final Offset punta = Offset(w / 2, h - margen * 0.6);
  final Path gota = _trazoGota(centro, radio, punta);

  // Sombra, relleno de color y borde blanco.
  lienzo.drawPath(
    gota.shift(Offset(0, w * 0.02)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, w * 0.03),
  );
  lienzo.drawPath(gota, Paint()..color = fondo);
  lienzo.drawPath(
    gota,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeJoin = StrokeJoin.round,
  );

  // El icono es una letra de la fuente de iconos, en el centro de la cabeza.
  final TextPainter pintor = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icono.codePoint),
      style: TextStyle(
        fontSize: radio * 1.15,
        fontFamily: icono.fontFamily,
        package: icono.fontPackage,
        color: colorIcono,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  pintor.paint(lienzo, centro - Offset(pintor.width / 2, pintor.height / 2));

  final ui.Image imagen = await grabadora.endRecording().toImage(ancho, alto);
  final ByteData? datos = await imagen.toByteData(
    format: ui.ImageByteFormat.png,
  );
  return datos!.buffer.asUint8List();
}

/// El contorno de una gota: un circulo de [radio] en [centro] unido por dos
/// tangentes a una [punta] que esta debajo.
Path _trazoGota(Offset centro, double radio, Offset punta) {
  final double distancia = punta.dy - centro.dy;
  // Angulo, desde la vertical hacia abajo, del punto donde la tangente toca el circulo.
  final double phi = math.acos(radio / distancia);
  final double abajo = math.pi / 2; // en el lienzo, +y es hacia abajo
  final Offset izquierda = Offset(
    centro.dx + radio * math.cos(abajo + phi),
    centro.dy + radio * math.sin(abajo + phi),
  );
  return Path()
    ..moveTo(punta.dx, punta.dy)
    ..lineTo(izquierda.dx, izquierda.dy)
    ..arcTo(
      Rect.fromCircle(center: centro, radius: radio),
      abajo + phi,
      2 * math.pi - 2 * phi,
      false,
    )
    ..close();
}
