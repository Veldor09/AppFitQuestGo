import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/presentation/ficha_alerta.dart';

import 'helpers/datos_mapa.dart';
import 'helpers/montar.dart';

void main() {
  Future<void> abrir(WidgetTester tester, Alerta alerta, {double? metros}) async {
    await montarApp(
      tester,
      Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () => mostrarFichaAlerta(context, alerta, metros: metros),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el tipo de alerta y su gravedad', (WidgetTester tester) async {
    await abrir(tester, alertaDePrueba(tipo: 'bache', gravedad: 'alta'));

    expect(find.text('Bache'), findsOneWidget);
    expect(find.text('Gravedad Alta'), findsOneWidget);
  });

  testWidgets('dice quien la reporto cuando se sabe', (WidgetTester tester) async {
    await abrir(
      tester,
      const Alerta(
        id: 1,
        tipo: 'perro',
        gravedad: 'media',
        lat: latBase,
        lng: lngBase,
        estado: 'Activa',
        creadoPorNombre: 'Ana',
      ),
    );

    expect(find.text('Gravedad Media · reportada por Ana'), findsOneWidget);
  });

  testWidgets('con tipo "otro" muestra lo que escribio quien reporto', (WidgetTester tester) async {
    await abrir(tester, alertaDePrueba(tipo: 'otro', tipoOtro: 'Poste inclinado'));

    expect(find.text('Poste inclinado'), findsOneWidget);
  });

  testWidgets('muestra la descripcion si la tiene', (WidgetTester tester) async {
    await abrir(tester, alertaDePrueba(descripcion: 'Hueco grande junto a la acera'));

    expect(find.text('Hueco grande junto a la acera'), findsOneWidget);
  });

  testWidgets('con la posicion conocida dice a cuantos metros esta', (WidgetTester tester) async {
    await abrir(tester, alertaDePrueba(), metros: 296.4);

    expect(find.text('A unos 296 m'), findsOneWidget);
  });

  testWidgets('sin posicion no dice la distancia', (WidgetTester tester) async {
    await abrir(tester, alertaDePrueba());

    expect(find.textContaining('A unos'), findsNothing);
  });
}
