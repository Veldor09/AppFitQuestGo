import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/evento_detalle_screen.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/ficha_evento.dart';
import 'helpers/calificacion_falsa.dart';
import 'helpers/montar.dart';

const List<PuntoGeo> _triangulo = <PuntoGeo>[
  PuntoGeo(lat: 10.0, lng: -84.0),
  PuntoGeo(lat: 10.0, lng: -83.9),
  PuntoGeo(lat: 10.1, lng: -84.0),
];

Evento _evento({
  List<ZonaEvento>? areas,
  List<ZonaEvento>? recorridos,
}) {
  return Evento(
    id: 5,
    nombre: 'Caminata benefica',
    categoria: 'benefico',
    fechaInicio: DateTime(2030, 5, 10, 8),
    fechaFin: DateTime(2030, 5, 10, 11),
    areas:
        areas ??
        const <ZonaEvento>[
          ZonaEvento(nombre: 'Area 1', puntos: _triangulo),
          ZonaEvento(nombre: 'Area 2', puntos: _triangulo),
        ],
    recorridos: recorridos ?? const <ZonaEvento>[],
    creadoPorNombre: 'Cafe El Roble',
  );
}

ResumenCalificacion _resumen({MotivoSinCalificar? motivo}) {
  return ResumenCalificacion(
    arriba: 2,
    abajo: 1,
    puedeCalificar: motivo == null,
    motivo: motivo,
    areas: <ResumenCalificacion>[
      ResumenCalificacion(
        arriba: 3,
        abajo: 0,
        puedeCalificar: motivo == null,
        motivo: motivo,
      ),
      ResumenCalificacion(
        arriba: 0,
        abajo: 4,
        puedeCalificar: motivo == null,
        motivo: motivo,
      ),
    ],
  );
}

Finder _enArea(int i, String llave) => find.descendant(
  of: find.byKey(ValueKey<String>('pulgares-area-$i')),
  matching: find.byKey(ValueKey<String>(llave)),
);

void _pantallaGrande(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('destinoDeEvento', () {
    test('lleva al centro de la primera area', () {
      final ({double lat, double lng})? d = destinoDeEvento(_evento());

      expect(d, isNotNull);
      expect(d!.lat, closeTo(10.033, 0.01));
      expect(d.lng, closeTo(-83.967, 0.01));
    });

    test('sin areas, al inicio del primer recorrido', () {
      final ({double lat, double lng})? d = destinoDeEvento(
        _evento(
          areas: const <ZonaEvento>[],
          recorridos: const <ZonaEvento>[
            ZonaEvento(
              nombre: 'Recorrido 1',
              puntos: <PuntoGeo>[
                PuntoGeo(lat: 9.5, lng: -84.5),
                PuntoGeo(lat: 9.6, lng: -84.6),
              ],
            ),
          ],
        ),
      );

      expect(d, (lat: 9.5, lng: -84.5));
    });

    test('un evento sin nada dibujado no tiene destino', () {
      expect(
        destinoDeEvento(
          _evento(areas: const <ZonaEvento>[], recorridos: const <ZonaEvento>[]),
        ),
        isNull,
      );
    });
  });

  group('FichaEvento con pulgares', () {
    testWidgets('muestra los pulgares del evento y los de cada area', (
      tester,
    ) async {
      _pantallaGrande(tester);
      await montarApp(
        tester,
        Scaffold(
          body: FichaEvento(
            evento: _evento(),
            calificaciones: CalificacionApiFalsa(respuesta: _resumen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('pulgares-resumen')), findsOne);
      expect(find.text('¿Qué te pareció?'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('pulgares-area-0')), findsOne);
      expect(find.byKey(const ValueKey<String>('pulgares-area-1')), findsOne);
    });

    testWidgets('calificar un area manda el indice y solo cambia esa area', (
      tester,
    ) async {
      _pantallaGrande(tester);
      final CalificacionApiFalsa api = CalificacionApiFalsa(
        respuesta: _resumen(),
      );
      await montarApp(
        tester,
        Scaffold(body: FichaEvento(evento: _evento(), calificaciones: api)),
      );
      await tester.pumpAndSettle();

      await tester.tap(_enArea(1, 'pulgar-arriba'));
      await tester.pumpAndSettle();

      expect(api.enviadas.single.area, 1);
      expect(api.enviadas.single.valor, ValorCalificacion.arriba);
      // El area 1 pasa de 0 a 1 arriba; el area 0 sigue igual.
      expect(
        find.descendant(of: _enArea(1, 'pulgar-arriba'), matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _enArea(0, 'pulgar-arriba'), matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets('en tu propio evento no ofrece calificar, solo ver los conteos', (
      tester,
    ) async {
      _pantallaGrande(tester);
      final CalificacionApiFalsa api = CalificacionApiFalsa(
        respuesta: _resumen(motivo: MotivoSinCalificar.propio),
      );
      await montarApp(
        tester,
        Scaffold(body: FichaEvento(evento: _evento(), calificaciones: api)),
      );
      await tester.pumpAndSettle();

      expect(find.text('¿Qué te pareció?'), findsNothing);
      expect(find.byKey(const ValueKey<String>('pulgares-resumen')), findsOne);
      await tester.tap(_enArea(0, 'pulgar-arriba'));
      await tester.pump();
      expect(api.enviadas, isEmpty);
    });

    testWidgets('si los pulgares no cargan, la ficha se ve igual', (
      tester,
    ) async {
      _pantallaGrande(tester);
      final CalificacionApiFalsa api = CalificacionApiFalsa()
        ..error = Exception('sin red');
      await montarApp(
        tester,
        Scaffold(body: FichaEvento(evento: _evento(), calificaciones: api)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Caminata benefica'), findsOneWidget);
      expect(find.text('Area 1'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('pulgar-arriba')), findsNothing);
    });

    testWidgets('"Como llegar" abre la ruta al centro del area', (tester) async {
      _pantallaGrande(tester);
      final List<Uri> abiertas = <Uri>[];
      await montarApp(
        tester,
        Scaffold(
          body: FichaEvento(
            evento: _evento(),
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

      expect(abiertas.single.queryParameters['travelmode'], 'walking');
      final List<String> partes = abiertas.single.queryParameters['destination']!
          .split(',');
      expect(double.parse(partes[0]), closeTo(10.033, 0.01));
    });
  });

  group('EventoDetalleScreen con pulgares', () {
    testWidgets('muestra los pulgares y deja calificar un area', (tester) async {
      _pantallaGrande(tester);
      final CalificacionApiFalsa api = CalificacionApiFalsa(
        respuesta: _resumen(),
      );
      await montarApp(
        tester,
        EventoDetalleScreen(
          evento: _evento(),
          ahora: () => DateTime(2030, 1, 1),
          mapaBuilder: (BuildContext _) => const SizedBox.shrink(),
          calificaciones: api,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('pulgares-resumen')), findsOne);

      await tester.tap(_enArea(0, 'pulgar-abajo'));
      await tester.pumpAndSettle();

      expect(api.enviadas.single.area, 0);
      expect(api.enviadas.single.valor, ValorCalificacion.abajo);
    });
  });
}
