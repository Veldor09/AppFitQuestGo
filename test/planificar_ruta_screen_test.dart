import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/planificar_ruta_screen.dart';
import 'package:geolocator/geolocator.dart';

Widget _montar({Stream<Position>? streamFalso}) {
  return MaterialApp(
    home: Scaffold(
      body: PlanificarRutaScreen(
        api: RutaApi(),
        posicionStream: streamFalso == null ? null : (() => streamFalso),
      ),
    ),
  );
}

void main() {
  testWidgets('arranca en modo Dibujar, con el selector visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_montar());
    await tester.pump();

    expect(find.text('Dibujar'), findsOneWidget);
    expect(find.text('Grabar GPS'), findsOneWidget);
    expect(find.text('Toca el mapa para trazar tu ruta, punto por punto.'),
        findsOneWidget);
  });

  testWidgets('cambiar a modo GPS muestra el boton Iniciar grabacion', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_montar());
    await tester.pump();

    await tester.tap(find.text('Grabar GPS'));
    await tester.pump();

    expect(find.text('Iniciar grabacion'), findsOneWidget);
  });

  testWidgets('al grabar, cada posicion del stream se agrega como punto', (
    WidgetTester tester,
  ) async {
    final StreamController<Position> controlador =
        StreamController<Position>();
    addTearDown(controlador.close);

    await tester.pumpWidget(_montar(streamFalso: controlador.stream));
    await tester.pump();
    await tester.tap(find.text('Grabar GPS'));
    await tester.pump();
    await tester.tap(find.text('Iniciar grabacion'));
    await tester.pump();

    controlador.add(_posicion(9.9281, -84.0907));
    await tester.pump();
    controlador.add(_posicion(9.9291, -84.0917));
    await tester.pump();

    expect(find.textContaining('2 puntos'), findsOneWidget);
    expect(find.text('Detener'), findsOneWidget);
  });
}

Position _posicion(double lat, double lng) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
