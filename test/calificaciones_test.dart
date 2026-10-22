import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/widgets/fq_icono_dificultad.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/calificaciones/presentation/pulgares.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/ficha_nodo.dart';
import 'helpers/calificacion_falsa.dart';
import 'helpers/montar.dart';

const ({double lat, double lng}) _punto = (lat: 10.0, lng: -84.0);

void main() {
  group('ResumenCalificacion.fromJson', () {
    test('lee conteos, mi voto, el motivo y el resumen de cada area', () {
      final ResumenCalificacion r = ResumenCalificacion.fromJson(
        <String, dynamic>{
          'arriba': 5,
          'abajo': 8,
          'mia': 'abajo',
          'puedeCalificar': false,
          'motivo': 'sin_recorrido',
          'areas': <Map<String, dynamic>>[
            <String, dynamic>{
              'indice': 0,
              'arriba': 1,
              'abajo': 0,
              'mia': null,
              'puedeCalificar': true,
              'motivo': null,
            },
          ],
        },
      );

      expect(r.arriba, 5);
      expect(r.abajo, 8);
      expect(r.mia, ValorCalificacion.abajo);
      expect(r.puedeCalificar, isFalse);
      expect(r.motivo, MotivoSinCalificar.sinRecorrido);
      expect(r.areas.single.arriba, 1);
      expect(r.areas.single.mia, isNull);
    });

    test('un motivo o voto desconocido se ignora sin romper', () {
      final ResumenCalificacion r = ResumenCalificacion.fromJson(
        <String, dynamic>{'mia': 'raro', 'motivo': 'otro_motivo'},
      );

      expect(r.mia, isNull);
      expect(r.motivo, isNull);
      expect(r.puedeCalificar, isTrue);
    });
  });

  group('Pulgares', () {
    testWidgets('el modo compacto muestra los dos conteos', (tester) async {
      await montarApp(
        tester,
        const Scaffold(
          body: Pulgares(
            resumen: ResumenCalificacion(arriba: 5, abajo: 8),
            compacto: true,
          ),
        ),
      );

      expect(find.byKey(const ValueKey<String>('pulgares-resumen')), findsOne);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('inhabilitado no responde a los toques', (tester) async {
      final List<ValorCalificacion> elegidos = <ValorCalificacion>[];
      await montarApp(
        tester,
        Scaffold(
          body: Pulgares(
            resumen: const ResumenCalificacion(arriba: 1),
            habilitado: false,
            onElegir: elegidos.add,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('pulgar-arriba')));
      await tester.pump();

      expect(elegidos, isEmpty);
    });
  });

  group('PulgaresObjeto', () {
    Future<CalificacionApiFalsa> abrir(
      WidgetTester tester, {
      ResumenCalificacion resumen = const ResumenCalificacion(arriba: 5, abajo: 8),
      TipoCalificable tipo = TipoCalificable.ruta,
      ({double lat, double lng})? destino,
      PosicionGps? posicion,
    }) async {
      final CalificacionApiFalsa api = CalificacionApiFalsa(respuesta: resumen);
      await montarApp(
        tester,
        Scaffold(
          body: PulgaresObjeto(
            tipo: tipo,
            id: 7,
            api: api,
            destino: destino,
            posicionActual: destino == null ? null : () => posicion,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('pide el resumen y muestra "5 arriba, 8 abajo"', (tester) async {
      final CalificacionApiFalsa api = await abrir(tester);

      expect(api.resumenesPedidos.single.tipo, TipoCalificable.ruta);
      expect(api.resumenesPedidos.single.id, 7);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('tocar el pulgar arriba califica y suma uno', (tester) async {
      final CalificacionApiFalsa api = await abrir(tester);

      await tester.tap(find.byKey(const ValueKey<String>('pulgar-arriba')));
      await tester.pumpAndSettle();

      expect(api.enviadas.single.valor, ValorCalificacion.arriba);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('¡Gracias por tu calificación!'), findsOneWidget);
    });

    testWidgets('tocar el mismo pulgar otra vez retira la calificacion', (
      tester,
    ) async {
      final CalificacionApiFalsa api = await abrir(
        tester,
        resumen: const ResumenCalificacion(
          arriba: 5,
          abajo: 8,
          mia: ValorCalificacion.arriba,
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('pulgar-arriba')));
      await tester.pumpAndSettle();

      expect(api.enviadas.single.valor, isNull);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('cambiar de pulgar pasa el voto de un lado al otro', (
      tester,
    ) async {
      final CalificacionApiFalsa api = await abrir(
        tester,
        resumen: const ResumenCalificacion(
          arriba: 5,
          abajo: 8,
          mia: ValorCalificacion.arriba,
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('pulgar-abajo')));
      await tester.pumpAndSettle();

      expect(api.enviadas.single.valor, ValorCalificacion.abajo);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('una ruta sin recorrido terminado explica por que no', (
      tester,
    ) async {
      final CalificacionApiFalsa api = await abrir(
        tester,
        resumen: const ResumenCalificacion(
          arriba: 5,
          abajo: 8,
          puedeCalificar: false,
          motivo: MotivoSinCalificar.sinRecorrido,
        ),
      );

      expect(
        find.text('Inicia y finaliza la ruta para poder calificarla.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('pulgar-arriba')));
      await tester.pump();
      expect(api.enviadas, isEmpty);
    });

    testWidgets('un punto lejos dice a cuantos metros estas y no califica', (
      tester,
    ) async {
      final CalificacionApiFalsa api = await abrir(
        tester,
        tipo: TipoCalificable.nodo,
        destino: _punto,
        posicion: (lat: 10.01, lng: -84.0),
      );

      expect(find.textContaining('Acércate a menos de 150 m'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('pulgar-abajo')));
      await tester.pump();
      expect(api.enviadas, isEmpty);
    });

    testWidgets('un punto cerca deja calificar y manda tu posicion', (
      tester,
    ) async {
      final CalificacionApiFalsa api = await abrir(
        tester,
        tipo: TipoCalificable.nodo,
        destino: _punto,
        posicion: (lat: 10.0004, lng: -84.0),
      );

      await tester.tap(find.byKey(const ValueKey<String>('pulgar-arriba')));
      await tester.pumpAndSettle();

      expect(api.enviadas.single.lat, 10.0004);
      expect(api.enviadas.single.lng, -84.0);
    });

    testWidgets('sin GPS pide activar la ubicacion', (tester) async {
      await abrir(tester, tipo: TipoCalificable.nodo, destino: _punto);

      expect(find.text('Activa tu ubicación para calificar.'), findsOneWidget);
    });

    testWidgets('un error del servidor avisa y deja el conteo como estaba', (
      tester,
    ) async {
      final CalificacionApiFalsa api = await abrir(tester);
      api.error = ApiException(500, 'boom');

      await tester.tap(find.byKey(const ValueKey<String>('pulgar-arriba')));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo guardar tu calificación.'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('si el resumen no carga no estorba (no muestra nada)', (
      tester,
    ) async {
      final CalificacionApiFalsa api = CalificacionApiFalsa()
        ..error = ApiException(500, 'boom');
      await montarApp(
        tester,
        Scaffold(
          body: PulgaresObjeto(tipo: TipoCalificable.ruta, id: 1, api: api),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('pulgar-arriba')), findsNothing);
    });
  });

  group('IconoDificultad', () {
    testWidgets('dibuja una carita distinta para cada dificultad', (
      tester,
    ) async {
      await montarApp(
        tester,
        const Scaffold(
          body: Row(
            children: <Widget>[
              IconoDificultad(dificultad: 'facil'),
              IconoDificultad(dificultad: 'moderada'),
              IconoDificultad(dificultad: 'dificil'),
            ],
          ),
        ),
      );

      for (final String d in <String>['facil', 'moderada', 'dificil']) {
        expect(find.byKey(ValueKey<String>('icono-dificultad-$d')), findsOne);
      }
    });

    test('cada dificultad tiene su color y lo desconocido cae en moderada', () {
      expect(coloresDificultad('facil'), isNot(coloresDificultad('dificil')));
      expect(coloresDificultad('rara'), coloresDificultad('moderada'));
    });
  });

  group('FichaNodo con pulgares y "Como llegar"', () {
    const Nodo nodo = Nodo(
      id: 9,
      nombre: 'Fuente del parque',
      categoria: 'agua',
      lat: 10.0,
      lng: -84.0,
      estado: 'Aprobado',
      creadoPorId: 3,
    );

    testWidgets('muestra los pulgares del servidor en la cabecera', (
      tester,
    ) async {
      await montarApp(
        tester,
        Scaffold(
          body: FichaNodo(
            nodo: nodo,
            api: NodoApi(),
            calificaciones: CalificacionApiFalsa(
              respuesta: const ResumenCalificacion(arriba: 12, abajo: 3),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('pulgares-resumen')), findsOne);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('"Como llegar" abre la ruta a pie hasta el punto', (
      tester,
    ) async {
      final List<Uri> abiertas = <Uri>[];
      await montarApp(
        tester,
        Scaffold(
          body: FichaNodo(
            nodo: nodo,
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

      expect(abiertas.single.host, 'www.google.com');
      expect(abiertas.single.queryParameters['destination'], '10.0,-84.0');
      expect(abiertas.single.queryParameters['travelmode'], 'walking');
    });

    testWidgets('ofrece calificar solo con GPS y sobre un punto ajeno', (
      tester,
    ) async {
      await montarApp(
        tester,
        Scaffold(
          body: FichaNodo(
            nodo: nodo,
            api: NodoApi(),
            usuarioId: 7,
            posicionActual: () => (lat: 10.0002, lng: -84.0),
            calificaciones: CalificacionApiFalsa(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('¿Qué te pareció?'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('pulgar-arriba')), findsOne);
    });

    testWidgets('en tu propio punto no aparece la seccion de calificar', (
      tester,
    ) async {
      await montarApp(
        tester,
        Scaffold(
          body: FichaNodo(
            nodo: nodo,
            api: NodoApi(),
            usuarioId: 3,
            posicionActual: () => (lat: 10.0002, lng: -84.0),
            calificaciones: CalificacionApiFalsa(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('¿Qué te pareció?'), findsNothing);
    });
  });
}
