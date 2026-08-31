import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Representacion decorativa del mapa (`.fq-map`): fondo con textura, parques,
/// agua, vias y pines. No integra ningun proveedor de mapas; es solo el
/// "espacio" visual que ocupa el mapa dentro de las maquetas del panel.
class FqMapView extends StatelessWidget {
  const FqMapView({super.key, this.height = 235, this.showRoute = false});

  final double height;
  final bool showRoute;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _MapPainter(showRoute: showRoute),
          child: Stack(
            children: <Widget>[
              const Positioned(
                right: 6,
                bottom: 5,
                child: Text(
                  'FitQuest Maps',
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    color: Color(0x8013233F),
                  ),
                ),
              ),
              Positioned(
                right: 11,
                bottom: 14,
                child: Column(
                  children: <Widget>[
                    _mapControl(Icons.add),
                    const SizedBox(height: 5),
                    _mapControl(Icons.remove),
                  ],
                ),
              ),
              const Align(
                alignment: Alignment(0, 0.08),
                child: _CurrentDot(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapControl(IconData icon) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x2613233F)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A13233F),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, size: 15, color: FqColors.night),
    );
  }
}

class _CurrentDot extends StatelessWidget {
  const _CurrentDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0x330875D1),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: FqColors.river,
          shape: BoxShape.circle,
          border: Border.all(color: FqColors.white, width: 2),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.showRoute});

  final bool showRoute;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFFE9EEE5));

    // Textura de cuadricula tenue.
    final Paint grid = Paint()
      ..color = const Color(0x1A7B887E)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 46) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Parques.
    final Paint park = Paint()..color = const Color(0xFFD3E7C4);
    canvas.drawOval(
      Rect.fromLTWH(-size.width * 0.08, size.height * 0.16, size.width * 0.37,
          size.height * 0.24),
      park,
    );
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.72, size.height * 0.55, size.width * 0.3,
          size.height * 0.28),
      park,
    );

    // Agua.
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.52, -size.height * 0.1, size.width * 0.22,
          size.height * 1.2),
      Paint()..color = const Color(0x443EA3DA),
    );

    // Vias.
    final Paint road = Paint()
      ..color = const Color(0xE6FFFFFF)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-size.width * 0.1, size.height * 0.5),
      Offset(size.width * 1.1, size.height * 0.36),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 1.1),
      Offset(size.width * 0.7, -size.height * 0.1),
      road,
    );
    canvas.drawLine(
      Offset(-size.width * 0.08, size.height * 0.85),
      Offset(size.width * 1.05, size.height * 0.15),
      road,
    );

    if (showRoute) {
      final Path p = Path()
        ..moveTo(size.width * 0.2, size.height * 0.7)
        ..cubicTo(
          size.width * 0.1,
          size.height * 0.3,
          size.width * 0.6,
          size.height * 0.2,
          size.width * 0.8,
          size.height * 0.45,
        );
      canvas.drawPath(
        p,
        Paint()
          ..color = FqColors.voltDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // Pines.
    _pin(canvas, Offset(size.width * 0.24, size.height * 0.34), FqColors.trail);
    _pin(canvas, Offset(size.width * 0.7, size.height * 0.44), FqColors.risk);
    _pin(canvas, Offset(size.width * 0.44, size.height * 0.74), FqColors.trail);
  }

  void _pin(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center,
      9,
      Paint()..color = FqColors.white,
    );
    canvas.drawCircle(center, 6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.showRoute != showRoute;
}
