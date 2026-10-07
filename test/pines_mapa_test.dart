import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/catalogos/categorias_nodo.dart';
import 'package:fit_quest_go/core/geo/centroide.dart';
import 'package:fit_quest_go/core/mapa/pin_anotacion.dart';
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

// Geometria de la gota (ver `dibujarPin`): el centro de la cabeza y su radio.
const double _margen = kPinAncho * 0.07;
const double _radio = kPinAncho / 2 - _margen;
const double _cx = kPinAncho / 2;
const double _cy = _margen + _radio;

void main() {
  group('estiloPin (que icono y color lleva cada cosa)', () {
    test('cada tipo tiene su propio icono y color', () {
      final Set<String> firmas = <String>{
        for (final TipoPin t in TipoPin.values)
          '${estiloPin(t).icono.codePoint}-${estiloPin(t).fondo.toARGB32()}',
      };
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

  group('estiloPinNodo (un pin por categoria, como en Google Maps)', () {
    test('cada categoria del catalogo tiene su propio icono', () {
      final List<IconData> iconos = <IconData>[
        for (final OpcionCatalogo o in categoriasNodo)
          estiloPinNodo(o.clave).icono,
      ];
      expect(
        iconos.map((IconData i) => i.codePoint).toSet(),
        hasLength(iconos.length),
      );
    });

    test('los iconos son los que se esperan de cada categoria', () {
      expect(estiloPinNodo('agua').icono, Icons.water_drop_rounded);
      expect(estiloPinNodo('mirador').icono, Icons.landscape_rounded);
      expect(estiloPinNodo('taller').icono, Icons.build_rounded);
      expect(estiloPinNodo('restaurante').icono, Icons.restaurant_rounded);
      expect(estiloPinNodo('comercio').icono, Icons.shopping_bag_rounded);
      expect(estiloPinNodo('banos').icono, Icons.wc_rounded);
      expect(estiloPinNodo('parqueo').icono, Icons.local_parking_rounded);
      expect(
        estiloPinNodo('primeros_auxilios').icono,
        Icons.medical_services_rounded,
      );
    });

    test(
      '"otro" y una categoria desconocida usan el pin generico, en gris',
      () {
        for (final String clave in <String>[claveOtro, 'lo-que-sea', '']) {
          expect(
            estiloPinNodo(clave).icono,
            Icons.place_rounded,
            reason: clave,
          );
          expect(estiloPinNodo(clave).fondo, FqColors.muted, reason: clave);
        }
      },
    );

    test('ninguna categoria usa el rojo de las alertas', () {
      for (final OpcionCatalogo o in categoriasNodo) {
        expect(
          estiloPinNodo(o.clave).fondo,
          isNot(FqColors.risk),
          reason: o.clave,
        );
      }
    });

    test('las categorias con color propio conservan el de sus tarjetas', () {
      for (final String clave in <String>[
        'agua',
        'mirador',
        'taller',
        'restaurante',
        'comercio',
      ]) {
        expect(
          estiloPinNodo(clave).fondo,
          colorCategoriaNodo(clave),
          reason: clave,
        );
      }
    });
  });

  group('dibujarPin / imagenPin', () {
    testWidgets('genera un PNG con el tamaño de la gota', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        final Uint8List png = await imagenPin(TipoPin.local);
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
        expect(r.ancho, kPinAncho);
        expect(r.alto, kPinAlto);
        expect(r.alto, greaterThan(r.ancho)); // una gota es mas alta que ancha
      });
    });

    testWidgets('es una gota: las esquinas son transparentes', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        final r = await _decodificar(await imagenPin(TipoPin.area));
        for (final (int x, int y) in <(int, int)>[
          (1, 1),
          (kPinAncho - 2, 1),
          (1, kPinAlto - 2),
          (kPinAncho - 2, kPinAlto - 2),
        ]) {
          expect(_pixel(r.pixeles, r.ancho, x, y) >> 24, 0, reason: '($x,$y)');
        }
      });
    });

    testWidgets('la cabeza lleva el color del tipo y un borde blanco', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        final r = await _decodificar(await imagenPin(TipoPin.recorridoInicio));
        // Dentro de la cabeza, lejos del icono: el color de fondo.
        final int relleno = _pixel(
          r.pixeles,
          r.ancho,
          (_cx - _radio * 0.75).round(),
          _cy.round(),
        );
        expect(relleno, FqColors.river.toARGB32());
        // Justo en el borde de la cabeza: blanco.
        final int borde = _pixel(
          r.pixeles,
          r.ancho,
          (_cx - _radio).round(),
          _cy.round(),
        );
        expect(borde, 0xFFFFFFFF);
      });
    });

    testWidgets(
      'tiene punta: el centro, cerca del borde de abajo, es de la gota',
      (WidgetTester tester) async {
        await tester.runAsync(() async {
          final r = await _decodificar(await imagenPin(TipoPin.area));
          final int enLaPunta = _pixel(
            r.pixeles,
            r.ancho,
            _cx.round(),
            kPinAlto - 18,
          );
          expect(enLaPunta, FqColors.purple.toARGB32());
          // A los lados de la punta ya no hay gota.
          final int aLaIzquierda = _pixel(
            r.pixeles,
            r.ancho,
            _cx.round() - 25,
            kPinAlto - 18,
          );
          expect(aLaIzquierda >> 24, lessThan(0x40));
        });
      },
    );

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

    testWidgets('el pin de una categoria lleva el color de esa categoria', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        final r = await _decodificar(await imagenPinNodo('agua'));
        expect(
          _pixel(
            r.pixeles,
            r.ancho,
            (_cx - _radio * 0.75).round(),
            _cy.round(),
          ),
          FqColors.river.toARGB32(),
        );
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
          _pixel(
            r.pixeles,
            r.ancho,
            (_cx - _radio * 0.75).round(),
            _cy.round(),
          ),
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
        // Y el pin de categoria igual: misma categoria, misma imagen.
        expect(
          identical(imagenPinNodo('taller'), imagenPinNodo('taller')),
          isTrue,
        );
      });
    });

    testWidgets('dibujarPin acepta otro tamaño', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final Uint8List png = await dibujarPin(
          icono: Icons.star,
          fondo: Colors.orange,
          ancho: 66,
          alto: 84,
        );
        final r = await _decodificar(png);
        expect(r.ancho, 66);
        expect(r.alto, 84);
      });
    });
  });

  group('iconSizePin (que mida lo mismo en cualquier celular)', () {
    test('el pin mide 44 de ancho en pantalla con cualquier densidad', () {
      for (final double densidad in <double>[1, 1.5, 2, 2.625, 2.75, 3, 3.5]) {
        // Mapbox trata los pixeles de la imagen como pixeles fisicos.
        final double enPantalla = kPinAncho * iconSizePin(densidad) / densidad;
        expect(enPantalla, closeTo(44, 1e-9), reason: 'densidad $densidad');
      }
    });

    test('y 56 de alto', () {
      expect(kPinAlto * iconSizePin(3) / 3, closeTo(56, 1e-9));
    });
  });

  group('opcionesDePin (el pin y su nombre en el mapa)', () {
    final Uint8List imagen = Uint8List.fromList(<int>[1, 2, 3]);

    PointAnnotationOptions opciones({
      String? etiqueta,
      bool secundario = false,
      double densidad = 3,
    }) => opcionesDePin(
      lat: 9.93,
      lng: -84.09,
      imagen: imagen,
      densidad: densidad,
      etiqueta: etiqueta,
      secundario: secundario,
    );

    test('la punta de la gota queda en la coordenada', () {
      final PointAnnotationOptions o = opciones();
      expect(o.iconAnchor, IconAnchor.BOTTOM);
      expect(o.geometry.coordinates.lng, -84.09);
      expect(o.geometry.coordinates.lat, 9.93);
      expect(o.image, imagen);
    });

    test('el tamaño sale de la densidad de la pantalla', () {
      expect(opciones(densidad: 3).iconSize, closeTo(1, 1e-9));
      expect(opciones(densidad: 2).iconSize, closeTo(2 / 3, 1e-9));
    });

    test(
      'con etiqueta escribe el nombre a la derecha, oscuro y con halo blanco',
      () {
        final PointAnnotationOptions o = opciones(etiqueta: '  Caminata 5k  ');
        expect(o.textField, 'Caminata 5k'); // sin espacios sobrantes
        expect(o.textAnchor, TextAnchor.LEFT);
        expect(o.textOffset?.first, greaterThan(0)); // a la derecha del pin
        expect(o.textOffset?.last, lessThan(0)); // a la altura de la cabeza
        expect(o.textColor, FqColors.night.toARGB32());
        expect(o.textHaloColor, Colors.white.toARGB32());
        expect(o.textHaloWidth, greaterThan(0));
      },
    );

    test('lo de otras empresas lleva el nombre en gris', () {
      expect(
        opciones(etiqueta: 'Ajeno', secundario: true).textColor,
        FqColors.muted.toARGB32(),
      );
    });

    test('sin etiqueta, o en blanco, no escribe ningun texto', () {
      expect(opciones().textField, isNull);
      expect(opciones(etiqueta: '').textField, isNull);
      expect(opciones(etiqueta: '   ').textField, isNull);
    });
  });

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
        final List<PuntoGeo> pts = <PuntoGeo>[
          for (int i = 0; i < 50; i++) _p(10 + i * 0.004, -84),
          _p(10.2, -84),
          _p(10.2, -83.8),
          _p(10, -83.8),
        ];
        final PuntoGeo c = centroideDe(pts);
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
