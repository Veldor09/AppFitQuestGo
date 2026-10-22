import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/catalogos/tipos_alerta.dart';
import 'package:fit_quest_go/core/mapa/navegacion_destino.dart';
import 'package:fit_quest_go/core/mapa/pin_icono.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/ficha_lugar.dart';
import 'package:fit_quest_go/core/widgets/visor_imagen.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/presentation/ficha_alerta.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/banner_guia.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/ficha_nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/foto_nodo.dart';
import 'helpers/calificacion_falsa.dart';
import 'helpers/montar.dart';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _NodoApiConFoto extends NodoApi {
  @override
  Future<Uint8List> foto(int id) async => _png;
}

const Nodo _nodo = Nodo(
  id: 9,
  nombre: 'Fuente del parque',
  categoria: 'agua',
  lat: 10.0,
  lng: -84.0,
  estado: 'Aprobado',
  creadoPorId: 3,
  conFoto: true,
);

Alerta _alerta({String tipo = 'perro', String gravedad = 'alta'}) => Alerta(
  id: 1,
  tipo: tipo,
  gravedad: gravedad,
  lat: 10.0,
  lng: -84.0,
  estado: 'Activa',
);

void main() {
  usarCalificacionesFalsas();

  group('NavegacionApp ("Como llegar" dentro de la app)', () {
    final NavegacionApp nav = NavegacionApp.instancia;

    setUp(() {
      nav.destino.value = null;
    });

    test('hayMapa solo es cierto mientras hay un mapa de Home abierto', () {
      expect(nav.hayMapa, isFalse);
      nav.registrarMapa();
      expect(nav.hayMapa, isTrue);
      nav.liberarMapa();
      expect(nav.hayMapa, isFalse);
      // Liberar de mas no deja el contador en negativo.
      nav.liberarMapa();
      nav.registrarMapa();
      expect(nav.hayMapa, isTrue);
      nav.liberarMapa();
    });

    testWidgets('con un mapa abierto, "Como llegar" no lanza la app de mapas: pide el camino al mapa', (
      tester,
    ) async {
      nav.registrarMapa();
      addTearDown(nav.liberarMapa);
      int peticiones = 0;
      nav.solicitudesMapa.addListener(() => peticiones++);

      await montarApp(
        tester,
        Scaffold(
          body: FichaNodo(
            nodo: _nodo.conFotoApagada(),
            api: NodoApi(),
            calificaciones: CalificacionApiFalsa(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('ficha-como-llegar')));
      await tester.pumpAndSettle();

      expect(nav.destino.value, isNotNull);
      expect(nav.destino.value!.lat, 10.0);
      expect(nav.destino.value!.lng, -84.0);
      expect(nav.destino.value!.nombre, 'Fuente del parque');
      expect(peticiones, 1);
    });

    testWidgets('al pedir el camino se cierran las fichas abiertas', (
      tester,
    ) async {
      nav.registrarMapa();
      addTearDown(nav.liberarMapa);
      await montarApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (BuildContext _) => Builder(
                  builder: (BuildContext ctx) => TextButton(
                    onPressed: () => abrirComoLlegar(
                      ctx,
                      lat: 1,
                      lng: 2,
                      nombre: 'Sitio',
                    ),
                    child: const Text('ir'),
                  ),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('ir'), findsOneWidget);

      await tester.tap(find.text('ir'));
      await tester.pumpAndSettle();

      expect(find.text('ir'), findsNothing);
      expect(nav.destino.value!.nombre, 'Sitio');
    });

    testWidgets('sin mapa abierto (cuenta de empresa) cae a la app de mapas del telefono', (
      tester,
    ) async {
      final List<Uri> abiertas = <Uri>[];
      await montarApp(
        tester,
        Scaffold(
          body: FichaNodo(
            nodo: _nodo.conFotoApagada(),
            api: NodoApi(),
            calificaciones: CalificacionApiFalsa(),
            abrirUrl: (Uri uri) async {
              abiertas.add(uri);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('ficha-como-llegar')));
      await tester.pumpAndSettle();

      expect(abiertas, hasLength(1));
      expect(nav.destino.value, isNull);
    });
  });

  group('BannerGuia', () {
    testWidgets('muestra a donde vas, la distancia y el tiempo a pie', (
      tester,
    ) async {
      await montarApp(
        tester,
        Scaffold(
          body: BannerGuia(
            guia: const GuiaActiva(
              nombre: 'Fuente del parque',
              metros: 1250,
              segundos: 1080,
            ),
            onCerrar: () {},
          ),
        ),
      );

      expect(find.text('Hacia Fuente del parque'), findsOneWidget);
      expect(find.textContaining('1,3 km'), findsOneWidget);
      expect(find.textContaining('18 min a pie'), findsOneWidget);
    });

    testWidgets('sin red solo conoce la linea recta y lo dice', (tester) async {
      await montarApp(
        tester,
        Scaffold(
          body: BannerGuia(
            guia: const GuiaActiva(
              nombre: 'Sitio',
              metros: 300,
              segundos: 0,
              lineaRecta: true,
            ),
            onCerrar: () {},
          ),
        ),
      );

      expect(find.textContaining('300 m en línea recta'), findsOneWidget);
      expect(find.textContaining('min a pie'), findsNothing);
    });

    testWidgets('la X lo cierra', (tester) async {
      int cierres = 0;
      await montarApp(
        tester,
        Scaffold(
          body: BannerGuia(
            guia: const GuiaActiva(nombre: 'X', metros: 100, segundos: 60),
            onCerrar: () => cierres++,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('cerrar-guia')));

      expect(cierres, 1);
    });
  });

  group('imagen a pantalla completa', () {
    testWidgets('tocar la foto del punto la abre grande y la X la cierra', (
      tester,
    ) async {
      await montarApp(
        tester,
        Scaffold(
          body: FotoNodo(
            api: _NodoApiConFoto(),
            nodoId: 9,
            titulo: 'Fuente del parque',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('visor-imagen')), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('foto-nodo')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('visor-imagen')), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Fuente del parque'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('cerrar-visor')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('visor-imagen')), findsNothing);
    });

    testWidgets('un doble toque acerca la imagen y otro la devuelve', (
      tester,
    ) async {
      await montarApp(
        tester,
        Builder(
          builder: (BuildContext context) => Scaffold(
            body: TextButton(
              onPressed: () => mostrarVisorImagen(context, _png),
              child: const Text('ver'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ver'));
      await tester.pumpAndSettle();

      final Finder visor = find.byType(InteractiveViewer);
      double zoom() => tester
          .widget<InteractiveViewer>(visor)
          .transformationController!
          .value
          .getMaxScaleOnAxis();
      expect(zoom(), 1);

      final Offset centro = tester.getCenter(visor);
      await tester.tapAt(centro);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(centro);
      await tester.pumpAndSettle();
      expect(zoom(), greaterThan(2));

      await tester.tapAt(centro);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(centro);
      await tester.pumpAndSettle();
      expect(zoom(), 1);
    });
  });

  group('iconos de alertas', () {
    test('cada tipo tiene su icono y los desconocidos el triangulo', () {
      expect(iconoAlerta('perro'), Icons.pets_rounded);
      expect(iconoAlerta('arbol_caido'), Icons.park_rounded);
      expect(iconoAlerta('inundacion'), Icons.flood_rounded);
      expect(iconoAlerta('otro'), Icons.warning_amber_rounded);
      expect(iconoAlerta('algo_raro'), Icons.warning_amber_rounded);
      // Los diez tipos del catalogo tienen icono propio, salvo "otro".
      final Set<IconData> iconos = <IconData>{
        for (final OpcionCatalogo o in tiposAlerta) iconoAlerta(o.clave),
      };
      expect(iconos.length, tiposAlerta.length);
    });

    test('el color sigue la gravedad: rojo alta, naranja media, ambar baja', () {
      expect(colorGravedadAlerta('alta'), FqColors.risk);
      expect(colorGravedadAlerta('baja'), FqColors.amber);
      expect(colorGravedadAlerta('media'), isNot(FqColors.risk));
      expect(colorGravedadAlerta('media'), isNot(FqColors.amber));
    });

    test('el pin de una alerta lleva el icono de su tipo y el color de su gravedad', () {
      final EstiloPin e = estiloPinAlerta('perro', 'alta');

      expect(e.icono, Icons.pets_rounded);
      expect(e.fondo, FqColors.risk);
    });

    testWidgets('la ficha de una alerta muestra su icono con el color de la gravedad', (
      tester,
    ) async {
      await montarApp(
        tester,
        Scaffold(body: FichaAlerta(alerta: _alerta(), metros: 56)),
      );

      final Container icono = tester.widget<Container>(
        find.byKey(const ValueKey<String>('ficha-alerta-icono')),
      );
      expect(
        (icono.decoration! as BoxDecoration).color,
        FqColors.risk,
      );
      expect(find.byIcon(Icons.pets_rounded), findsOneWidget);
    });

    testWidgets('la ficha de una alerta tambien tiene "Como llegar"', (
      tester,
    ) async {
      final List<Uri> abiertas = <Uri>[];
      await montarApp(
        tester,
        Scaffold(
          body: FichaAlerta(
            alerta: _alerta(),
            abrirUrl: (Uri uri) async {
              abiertas.add(uri);
              return true;
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('ficha-como-llegar')));
      await tester.pumpAndSettle();

      expect(abiertas.single.queryParameters['destination'], '10.0,-84.0');
    });
  });
}

extension on Nodo {
  /// El mismo punto sin foto (para que la ficha no pida bytes).
  Nodo conFotoApagada() => Nodo(
    id: id,
    nombre: nombre,
    categoria: categoria,
    lat: lat,
    lng: lng,
    estado: estado,
    creadoPorId: creadoPorId,
  );
}
