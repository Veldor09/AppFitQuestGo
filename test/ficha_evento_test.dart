import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/ficha_evento.dart';

import 'helpers/montar.dart';

final DateTime _ahora = DateTime(2030, 5, 1, 12);

const List<PuntoGeo> _triangulo = <PuntoGeo>[
  PuntoGeo(lat: 10, lng: -84),
  PuntoGeo(lat: 10.001, lng: -84),
  PuntoGeo(lat: 10.001, lng: -84.001),
];
const List<PuntoGeo> _linea = <PuntoGeo>[
  PuntoGeo(lat: 10, lng: -84),
  PuntoGeo(lat: 10.002, lng: -84.002),
];

Evento _evento({
  String nombre = 'Caminata benefica',
  String categoria = 'benefico',
  String? descripcion = 'Por la escuela del pueblo',
  String? empresa = 'Cafe El Roble',
  DateTime? inicio,
  DateTime? fin,
  int areas = 1,
  int recorridos = 1,
}) => Evento(
  id: 4,
  nombre: nombre,
  descripcion: descripcion,
  categoria: categoria,
  fechaInicio: inicio ?? DateTime(2030, 5, 10, 8),
  fechaFin: fin ?? DateTime(2030, 5, 10, 11),
  areas: <ZonaEvento>[
    for (int i = 0; i < areas; i++)
      ZonaEvento(nombre: 'Area ${i + 1}', puntos: _triangulo),
  ],
  recorridos: <ZonaEvento>[
    for (int i = 0; i < recorridos; i++)
      ZonaEvento(nombre: 'Recorrido ${i + 1}', puntos: _linea),
  ],
  creadoPorNombre: empresa,
);

Future<void> _abrir(WidgetTester tester, Evento evento) async {
  await montarApp(
    tester,
    Builder(
      builder: (BuildContext context) => TextButton(
        onPressed: () =>
            mostrarFichaEvento(context, evento, ahora: () => _ahora),
        child: const Text('abrir'),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('FichaEvento (al tocar un area o un recorrido en el mapa)', () {
    testWidgets('muestra el nombre, la categoria y quien lo organiza', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _evento());

      expect(find.text('Caminata benefica'), findsOneWidget);
      expect(find.text('Benefico'), findsOneWidget);
      expect(find.text('Organiza Cafe El Roble'), findsOneWidget);
    });

    testWidgets('muestra la descripcion', (WidgetTester tester) async {
      await _abrir(tester, _evento());

      expect(find.text('Por la escuela del pueblo'), findsOneWidget);
    });

    testWidgets('sin descripcion no deja un hueco ni un texto vacio', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _evento(descripcion: null));
      expect(
        find.byKey(const ValueKey<String>('ficha-evento-descripcion')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await _abrir(tester, _evento(descripcion: '   '));
      expect(
        find.byKey(const ValueKey<String>('ficha-evento-descripcion')),
        findsNothing,
      );
    });

    testWidgets('sin empresa conocida no inventa una', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _evento(empresa: null));

      expect(find.textContaining('Organiza'), findsNothing);
    });

    testWidgets('muestra las fechas del evento', (WidgetTester tester) async {
      await _abrir(tester, _evento());

      // Mismo dia: "vie, 10 may 8:00 a. m. - 11:00 a. m." (segun el idioma).
      expect(find.textContaining(' - '), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('dice si es proximo, esta en curso o ya termino', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _evento());
      expect(find.text('PROXIMO'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await _abrir(
        tester,
        _evento(inicio: DateTime(2030, 5, 1, 8), fin: DateTime(2030, 5, 1, 18)),
      );
      expect(find.text('EN CURSO'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await _abrir(
        tester,
        _evento(inicio: DateTime(2030, 4, 1, 8), fin: DateTime(2030, 4, 1, 18)),
      );
      expect(find.text('TERMINADO'), findsOneWidget);
    });

    testWidgets('lista las areas y los recorridos que tiene', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _evento(areas: 2, recorridos: 3));

      expect(find.text('Areas'), findsOneWidget);
      expect(find.text('Area 1'), findsOneWidget);
      expect(find.text('Area 2'), findsOneWidget);
      expect(find.text('Recorridos'), findsOneWidget);
      expect(find.text('Recorrido 1'), findsOneWidget);
      expect(find.text('Recorrido 3'), findsOneWidget);
    });

    testWidgets('un evento solo de recorridos no muestra la seccion de areas', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _evento(areas: 0, recorridos: 1));

      expect(find.text('Areas'), findsNothing);
      expect(find.text('Recorridos'), findsOneWidget);
    });

    testWidgets('un evento solo de areas no muestra la seccion de recorridos', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _evento(areas: 1, recorridos: 0));

      expect(find.text('Recorridos'), findsNothing);
      expect(find.text('Areas'), findsOneWidget);
    });

    testWidgets(
      'se puede cerrar deslizando o tocando fuera, y el mapa sigue ahi',
      (WidgetTester tester) async {
        await _abrir(tester, _evento());
        expect(find.byType(FichaEvento), findsOneWidget);

        await tester.tapAt(const Offset(10, 10)); // fuera de la hoja
        await tester.pumpAndSettle();

        expect(find.byType(FichaEvento), findsNothing);
        expect(find.text('abrir'), findsOneWidget);
      },
    );

    testWidgets(
      'un nombre largo y una descripcion larga no desbordan la hoja',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await _abrir(
          tester,
          _evento(
            nombre: 'Gran caminata benefica por la escuela del pueblo ' * 3,
            descripcion: 'Un texto bastante largo. ' * 40,
            areas: 4,
            recorridos: 4,
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}
