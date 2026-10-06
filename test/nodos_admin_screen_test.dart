import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/nodos_admin_screen.dart';

final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _NodoApiFalsa extends NodoApi {
  _NodoApiFalsa(this.pendientes);

  final List<Nodo> pendientes;
  final List<int> fotosPedidas = <int>[];

  @override
  Future<List<Nodo>> listarPendientes() async => pendientes;

  @override
  Future<Uint8List> foto(int id) async {
    fotosPedidas.add(id);
    return _png;
  }
}

Future<void> _abrir(WidgetTester tester, NodoApi api) async {
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  tester.platformDispatcher.localeTestValue = const Locale('es');
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(width: 1000, height: 800, child: NodosAdminScreen(api: api)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Nodo _nodo(int id, String categoria, {String? otro, bool conFoto = false}) {
  return Nodo(
    id: id,
    nombre: 'Punto $id',
    categoria: categoria,
    categoriaOtro: otro,
    lat: 9.93,
    lng: -84.09,
    estado: 'Pendiente',
    creadoPorNombre: 'Ana',
    conFoto: conFoto,
  );
}

void main() {
  testWidgets('muestra la categoria traducida (no la clave) de cada propuesta', (
    WidgetTester tester,
  ) async {
    final _NodoApiFalsa api = _NodoApiFalsa(<Nodo>[
      _nodo(1, 'primeros_auxilios'),
      _nodo(2, 'otro', otro: 'Zona de picnic'),
    ]);
    await _abrir(tester, api);

    expect(find.text('Primeros auxilios · propuesto por Ana'), findsOneWidget);
    expect(find.text('Zona de picnic · propuesto por Ana'), findsOneWidget);
    expect(find.textContaining('primeros_auxilios'), findsNothing);
  });

  testWidgets('tocar una fila abre la ficha con la foto para poder decidir', (
    WidgetTester tester,
  ) async {
    final _NodoApiFalsa api = _NodoApiFalsa(<Nodo>[_nodo(1, 'agua', conFoto: true)]);
    await _abrir(tester, api);

    await tester.tap(find.text('Punto 1'));
    await tester.pumpAndSettle();

    expect(api.fotosPedidas, <int>[1]);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('una propuesta sin foto abre la ficha sin pedir ninguna', (
    WidgetTester tester,
  ) async {
    final _NodoApiFalsa api = _NodoApiFalsa(<Nodo>[_nodo(1, 'agua')]);
    await _abrir(tester, api);

    await tester.tap(find.text('Punto 1'));
    await tester.pumpAndSettle();

    expect(api.fotosPedidas, isEmpty);
    expect(find.byType(Image), findsNothing);
  });
}
