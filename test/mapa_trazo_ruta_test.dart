import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/mapa_trazo_ruta.dart';

import 'helpers/montar.dart';

const List<PuntoRuta> _dosPuntos = <PuntoRuta>[
  PuntoRuta(lat: 9.9281, lng: -84.0907),
  PuntoRuta(lat: 9.9291, lng: -84.0917),
];

void main() {
  testWidgets(
    'sin `--dart-define=ACCESS_TOKEN` usa el token publico de la app y muestra el mapa',
    (WidgetTester tester) async {
      // Las pruebas corren sin ese define, igual que una compilacion que no lo
      // pasa (la de git): el mapa de Home ya funciona asi, el del trazo tambien.
      await montarApp(
        tester,
        const Scaffold(body: MapaTrazoRuta(puntos: _dosPuntos)),
      );

      expect(find.byKey(const ValueKey<String>('mapa-trazo-ruta')), findsOneWidget);
      expect(find.textContaining('ACCESS_TOKEN'), findsNothing);
    },
  );

  testWidgets('con menos de 2 puntos no hay trazo y lo avisa en lugar del mapa', (
    WidgetTester tester,
  ) async {
    await montarApp(
      tester,
      const Scaffold(
        body: MapaTrazoRuta(puntos: <PuntoRuta>[PuntoRuta(lat: 9.9281, lng: -84.0907)]),
      ),
    );

    expect(find.byKey(const ValueKey<String>('mapa-trazo-ruta')), findsNothing);
    expect(find.text('Esta ruta no tiene un trazo para mostrar.'), findsOneWidget);
  });
}
