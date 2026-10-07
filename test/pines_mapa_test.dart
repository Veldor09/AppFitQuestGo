import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/geo/centroide.dart';
import 'package:fit_quest_go/core/mapa/pin_icono.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';

PuntoGeo _p(double lat, double lng) => PuntoGeo(lat: lat, lng: lng);

/// Decodifica un PNG y devuelve sus pixeles RGBA y su tamaño.
Future<({int ancho, int alto, ByteData pixeles})> _decodificar(
  Uint8List png,
) async {
  final ui.Image imagen = await decodeImageFromList(png);
  final ByteData? datos = await imagen.toByteData();
  return (ancho: imagen.width, alto: imagen.height, pixeles: datos!);
}

/// El color (como 0xAARRGGBB) del pixel (x, y).
int _pixel(ByteData datos, int ancho, int x, int y) {
  final int i = (y * ancho + x) * 4;
  final int r = datos.getUint8(i);
  final int g = datos.getUint8(i + 1);
  final int b = datos.getUint8(i + 2);
  final int a = datos.getUint8(i + 3);
  return (a << 24) | (r << 16) | (g << 8) | b;
}

void main() {
  group('estiloPin (que icono y color lleva cada cosa)', () {
    test('cada tipo tiene su propio icono y color', () {
      final Set<String> firmas = <String>{
        for (final TipoPin t in TipoPin.values)
          '${estiloPin(t).icono.codePoint}-${estiloPin(t).fondo.toARGB32()}',
      };
      // recorridoFin y rutaFin comparten la bandera de meta pero no el color.
      expect(firmas, hasLength(TipoPin.values.length));
    });

    test('el local de una empresa es una tienda', () {
      expect(estiloPin(TipoPin.local).icono, Icons.storefront_rounded);
    });

    test(
      'el area es una bandera, el recorrido sale caminando y termina en meta',
      () {
        expect(estiloPin(TipoPin.area).icono, Icons.flag_rounded);
        expect(
          estiloPin(TipoPin.recorridoInicio).icono,
          Icons.directions_walk_rounded,
        );
        expect(
          estiloPin(TipoPin.recorridoFin).icono,
          Icons.sports_score_rounded,
        );
      },
    );

    test('la ruta sale con "play" y termina con la meta, en verde y rojo', () {
      expect(estiloPin(TipoPin.rutaInicio).icono, Icons.play_arrow_rounded);
      expect(estiloPin(TipoPin.rutaFin).icono, Icons.sports_score_rounded);
      expect(estiloPin(TipoPin.rutaInicio).fondo, FqColors.voltDark);
      expect(estiloPin(TipoPin.rutaFin).fondo, FqColors.risk);
    });

    test('lo de otras empresas va en gris pero conserva el icono', () {
      for (final TipoPin t in TipoPin.values) {
        final EstiloPin normal = estiloPin(t);
        final EstiloPin gris = estiloPin(t, secundario: true);
        expect(gris.icono, normal.icono, reason: t.name);
        expect(gris.fondo, FqColors.muted, reason: t.name);
      }
    });
  });

  group('dibujarPin / imagenPin', () {
    testWidgets('genera un PNG cuadrado del tamaño esperado', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        final Uint8List png = await imagenPin(TipoPin.local);
        // Firma de un PNG.
        expect(png.sublist(0, 8), <int>[
          0x89,
          0x50,
          0x4e,
          0x47,
          0x0d,
          0x0a,
          0x1a,
          0x0a,
        ]);
        final r = await _decodificar(png);
        expect(r.ancho, kPinPx);
        expect(r.alto, kPinPx);
      });
    });

    testWidgets(
      'las esquinas son transparentes: es un circulo, no un cuadrado',
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          final r = await _decodificar(await imagenPin(TipoPin.area));
          final int esquina = _pixel(r.pixeles, r.ancho, 1, 1);
          expect(esquina >> 24, 0, reason: 'alfa de la esquina');
        });
      },
    );

    testWidgets('el circulo lleva el color del tipo y un borde blanco', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        final r = await _decodificar(await imagenPin(TipoPin.recorridoInicio));
        final int centroY = kPinPx ~/ 2;
        // Dentro del circulo, lejos del icono: el color de fondo.
        final int relleno = _pixel(
          r.pixeles,
          r.ancho,
          (kPinPx * 0.2).round(),
          centroY,
        );
        expect(relleno, FqColors.river.toARGB32());
        // Cerca del borde: blanco.
        final int borde = _pixel(
          r.pixeles,
          r.ancho,
          (kPinPx * 0.1).round(),
          centroY,
        );
        expect(borde, 0xFFFFFFFF);
      });
    });

    testWidgets('pines de distinto color dan imagenes distintas', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        // En las pruebas la fuente de iconos no esta cargada, asi que dos pines
        // del mismo color (inicio y fin de recorrido) salen iguales; en la app
        // real sus iconos difieren. Lo que si se puede verificar aqui es el color.
        final Map<int, String> huellaPorColor = <int, String>{};
        for (final TipoPin t in TipoPin.values) {
          final Uint8List png = await imagenPin(t);
          final int color = estiloPin(t).fondo.toARGB32();
          final String huella = png.join(',');
          huellaPorColor.putIfAbsent(color, () => huella);
          expect(
            huella,
            huellaPorColor[color],
            reason: '${t.name} mismo color',
          );
        }
        expect(huellaPorColor.values.toSet(), hasLength(huellaPorColor.length));
      });
    });

    testWidgets('la version gris es distinta de la normal', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        final Uint8List normal = await imagenPin(TipoPin.area);
        final Uint8List gris = await imagenPin(TipoPin.area, secundario: true);
        expect(gris.join(','), isNot(normal.join(',')));
        final r = await _decodificar(gris);
        expect(
          _pixel(r.pixeles, r.ancho, (kPinPx * 0.2).round(), kPinPx ~/ 2),
          FqColors.muted.toARGB32(),
        );
      });
    });

    testWidgets('se dibuja una sola vez y se reutiliza', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        final Future<Uint8List> a = imagenPin(TipoPin.local);
        final Future<Uint8List> b = imagenPin(TipoPin.local);
        expect(identical(a, b), isTrue);
      });
    });

    testWidgets('dibujarPin acepta otro tamaño', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final Uint8List png = await dibujarPin(
          icono: Icons.star,
          fondo: Colors.orange,
          px: 64,
        );
        final r = await _decodificar(png);
        expect(r.ancho, 64);
        expect(r.alto, 64);
      });
    });
  });

  test(
    'la imagen se dibuja a 3x y se achica a 1/3 para medir 36 en pantalla',
    () {
      expect(kPinPx * kPinIconSize, closeTo(36, 1e-9));
    },
  );

  group('centroideDe (donde va el pin de un area)', () {
    test('un cuadrado: el centro exacto', () {
      final PuntoGeo c = centroideDe(<PuntoGeo>[
        _p(10, -84),
        _p(10, -83.8),
        _p(10.2, -83.8),
        _p(10.2, -84),
      ]);
      expect(c.lat, closeTo(10.1, 1e-9));
      expect(c.lng, closeTo(-83.9, 1e-9));
    });

    test('un triangulo: un tercio de la altura', () {
      final PuntoGeo c = centroideDe(<PuntoGeo>[_p(0, 0), _p(0, 3), _p(3, 0)]);
      expect(c.lat, closeTo(1, 1e-9));
      expect(c.lng, closeTo(1, 1e-9));
    });

    test('da lo mismo recorrerlo en un sentido o en el otro', () {
      final List<PuntoGeo> horario = <PuntoGeo>[
        _p(10, -84),
        _p(10.2, -84),
        _p(10.2, -83.8),
        _p(10, -83.8),
      ];
      final PuntoGeo a = centroideDe(horario);
      final PuntoGeo b = centroideDe(horario.reversed.toList());
      expect(a.lat, closeTo(b.lat, 1e-9));
      expect(a.lng, closeTo(b.lng, 1e-9));
    });

    test(
      'con muchos puntos de un lado cae en medio de la figura, no cargado a ese lado',
      () {
        // Un rectangulo con 50 puntos extra en su lado izquierdo.
        final List<PuntoGeo> pts = <PuntoGeo>[
          for (int i = 0; i < 50; i++) _p(10 + i * 0.004, -84),
          _p(10.2, -84),
          _p(10.2, -83.8),
          _p(10, -83.8),
        ];
        final PuntoGeo c = centroideDe(pts);
        // El promedio de vertices se iria a la izquierda (~ -83.97).
        expect(c.lng, closeTo(-83.9, 1e-6));
        expect(c.lat, closeTo(10.1, 1e-6));
      },
    );

    test(
      'una figura en L: el centro cae dentro de su masa, no en el hueco',
      () {
        final PuntoGeo c = centroideDe(<PuntoGeo>[
          _p(0, 0),
          _p(0, 2),
          _p(1, 2),
          _p(1, 1),
          _p(2, 1),
          _p(2, 0),
        ]);
        expect(c.lat, closeTo(0.8333333, 1e-6));
        expect(c.lng, closeTo(0.8333333, 1e-6));
      },
    );

    test('un trazo recto (area cero) usa el promedio de los vertices', () {
      final PuntoGeo c = centroideDe(<PuntoGeo>[
        _p(10, -84),
        _p(10.1, -84),
        _p(10.2, -84),
      ]);
      expect(c.lat, closeTo(10.1, 1e-9));
      expect(c.lng, closeTo(-84, 1e-9));
    });

    test('con uno o dos puntos usa el promedio', () {
      expect(centroideDe(<PuntoGeo>[_p(10, -84)]), _p(10, -84));
      final PuntoGeo c = centroideDe(<PuntoGeo>[_p(10, -84), _p(12, -82)]);
      expect(c.lat, closeTo(11, 1e-9));
      expect(c.lng, closeTo(-83, 1e-9));
    });

    test('sin puntos falla con un mensaje claro', () {
      expect(() => centroideDe(<PuntoGeo>[]), throwsArgumentError);
    });

    test('con coordenadas reales de Costa Rica queda dentro del area', () {
      final PuntoGeo c = centroideDe(<PuntoGeo>[
        _p(9.9281, -84.0907),
        _p(9.9281, -84.0807),
        _p(9.9381, -84.0807),
        _p(9.9381, -84.0907),
      ]);
      expect(c.lat, inInclusiveRange(9.9281, 9.9381));
      expect(c.lng, inInclusiveRange(-84.0907, -84.0807));
    });
  });
}
