import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Colores de cada dificultad (`facil`, `moderada`, `dificil`): arriba y abajo
/// del degradado de la carita.
({Color arriba, Color abajo}) coloresDificultad(String dificultad) {
  switch (dificultad) {
    case 'facil':
      return (arriba: const Color(0xFF7BE495), abajo: const Color(0xFF1FA64F));
    case 'dificil':
      return (arriba: const Color(0xFFFF8A65), abajo: const Color(0xFFE0362C));
    default:
      return (arriba: const Color(0xFFFFE082), abajo: const Color(0xFFF2A516));
  }
}

/// Carita de la dificultad: sonriente y verde (facil), serena y ambar
/// (moderada), con el ceño fruncido, la boca abierta y una gota de sudor, en
/// rojo (dificil). Se dibuja con vectores, asi que se ve nitida a cualquier
/// tamaño y no depende de la fuente de emojis del telefono.
class IconoDificultad extends StatelessWidget {
  const IconoDificultad({super.key, required this.dificultad, this.size = 24});

  /// `facil`, `moderada` o `dificil`; cualquier otro valor se ve como moderada.
  final String dificultad;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: ValueKey<String>('icono-dificultad-$dificultad'),
      size: Size.square(size),
      painter: _CaraPainter(dificultad),
    );
  }
}

/// Carita y nombre de la dificultad en una pastilla.
class EtiquetaDificultad extends StatelessWidget {
  const EtiquetaDificultad({
    super.key,
    required this.dificultad,
    required this.texto,
  });

  final String dificultad;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final Color color = coloresDificultad(dificultad).abajo;
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 10, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconoDificultad(dificultad: dificultad, size: 18),
          const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color.lerp(color, FqColors.ink, 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaraPainter extends CustomPainter {
  const _CaraPainter(this.dificultad);

  final String dificultad;

  static const Color _tinta = Color(0xFF3A2A1C);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final Offset c = Offset(s / 2, s / 2);
    final double r = s / 2;
    final ({Color arriba, Color abajo}) colores = coloresDificultad(dificultad);

    // Cara: degradado vertical con un borde un poco mas oscuro.
    final Rect caja = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[colores.arriba, colores.abajo],
        ).createShader(caja),
    );
    canvas.drawCircle(
      c,
      r - s * 0.02,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.04
        ..color = Colors.black.withValues(alpha: 0.12),
    );
    // Brillo suave arriba a la izquierda.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.36, s * 0.24),
        width: s * 0.34,
        height: s * 0.14,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );

    final Paint tinta = Paint()..color = _tinta;
    final Paint trazo = Paint()
      ..color = _tinta
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.075;

    final double ojosY = s * 0.43;
    final double ojoDx = s * 0.17;
    switch (dificultad) {
      case 'facil':
        _ojos(canvas, tinta, c.dx, ojosY, ojoDx, s * 0.065);
        final Path sonrisa = Path()
          ..moveTo(s * 0.31, s * 0.60)
          ..quadraticBezierTo(s * 0.5, s * 0.82, s * 0.69, s * 0.60);
        canvas.drawPath(sonrisa, trazo);
      case 'dificil':
        _ojos(canvas, tinta, c.dx, ojosY + s * 0.03, ojoDx, s * 0.06);
        // Cejas hacia dentro: ceño fruncido.
        final Paint ceja = Paint()
          ..color = _tinta
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.07;
        canvas.drawLine(
          Offset(c.dx - ojoDx - s * 0.08, ojosY - s * 0.11),
          Offset(c.dx - ojoDx + s * 0.09, ojosY - s * 0.05),
          ceja,
        );
        canvas.drawLine(
          Offset(c.dx + ojoDx + s * 0.08, ojosY - s * 0.11),
          Offset(c.dx + ojoDx - s * 0.09, ojosY - s * 0.05),
          ceja,
        );
        // Boca abierta, como quien resopla.
        final RRect boca = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(c.dx, s * 0.69),
            width: s * 0.34,
            height: s * 0.17,
          ),
          Radius.circular(s * 0.07),
        );
        canvas.drawRRect(boca, tinta);
        canvas.drawRRect(
          boca.deflate(s * 0.03),
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9),
        );
        // Gota de sudor.
        final Path gota = Path()
          ..moveTo(s * 0.86, s * 0.20)
          ..quadraticBezierTo(s * 0.97, s * 0.36, s * 0.86, s * 0.40)
          ..quadraticBezierTo(s * 0.75, s * 0.36, s * 0.86, s * 0.20)
          ..close();
        canvas.drawPath(gota, Paint()..color = const Color(0xFF7CC8FF));
      default:
        _ojos(canvas, tinta, c.dx, ojosY, ojoDx, s * 0.065);
        // Boca recta con una leve curva: serena.
        final Path boca = Path()
          ..moveTo(s * 0.33, s * 0.66)
          ..quadraticBezierTo(s * 0.5, s * 0.70, s * 0.67, s * 0.64);
        canvas.drawPath(boca, trazo);
    }
  }

  void _ojos(
    Canvas canvas,
    Paint pintura,
    double centroX,
    double y,
    double dx,
    double radio,
  ) {
    canvas.drawCircle(Offset(centroX - dx, y), radio, pintura);
    canvas.drawCircle(Offset(centroX + dx, y), radio, pintura);
  }

  @override
  bool shouldRepaint(_CaraPainter viejo) => viejo.dificultad != dificultad;
}
