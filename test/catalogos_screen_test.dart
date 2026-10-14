
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogo_item.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogos_api.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/catalogos_screen.dart';

class CatalogosApiSimulada extends CatalogosApi {
  final Map<String, List<CatalogoItem>> datos =
      <String, List<CatalogoItem>>{
    'alertas': <CatalogoItem>[
      const CatalogoItem(
        id: 1,
        catalogo: 'alertas',
        clave: 'bache',
        nombre: 'Bache',
        activo: true,
      ),
      const CatalogoItem(
        id: 2,
        catalogo: 'alertas',
        clave: 'derrumbe',
        nombre: 'Derrumbe',
        activo: false,
      ),
    ],
    'nodos': <CatalogoItem>[
      const CatalogoItem(
        id: 3,
        catalogo: 'nodos',
        clave: 'mirador',
        nombre: 'Mirador',
        activo: true,
      ),
    ],
    'actividades': <CatalogoItem>[],
  };

  int siguienteId = 4;
  int consultas = 0;

  @override
  Future<List<CatalogoItem>> listarItems(String catalogo) async {
    consultas++;
    return List<CatalogoItem>.from(
      datos[catalogo] ?? <CatalogoItem>[],
    );
  }

  @override
  Future<CatalogoItem> crearItem({
    required String catalogo,
    required String clave,
    required String nombre,
  }) async {
    final CatalogoItem nuevo = CatalogoItem(
      id: siguienteId++,
      catalogo: catalogo,
      clave: clave.trim(),
      nombre: nombre.trim(),
      activo: true,
    );

    datos.putIfAbsent(catalogo, () => <CatalogoItem>[]).add(nuevo);
    return nuevo;
  }

  @override
  Future<CatalogoItem> editarItem({
    required String catalogo,
    required int id,
    required String nombre,
    required bool activo,
  }) async {
    final List<CatalogoItem> items = datos[catalogo]!;
    final int indice = items.indexWhere(
      (CatalogoItem item) => item.id == id,
    );

    if (indice == -1) {
      throw StateError('Elemento no encontrado');
    }

    final CatalogoItem anterior = items[indice];

    final CatalogoItem actualizado = CatalogoItem(
      id: anterior.id,
      catalogo: anterior.catalogo,
      clave: anterior.clave,
      nombre: nombre.trim(),
      activo: activo,
    );

    items[indice] = actualizado;
    return actualizado;
  }
}

void main() {
  Future<void> abrirPantalla(
    WidgetTester tester,
    CatalogosApiSimulada api,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates:
            AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CatalogosScreen(api: api),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('carga elementos activos e inactivos', (
    WidgetTester tester,
  ) async {
    final CatalogosApiSimulada api = CatalogosApiSimulada();

    await abrirPantalla(tester, api);

    expect(find.text('Bache'), findsOneWidget);
    expect(find.text('Derrumbe'), findsOneWidget);
    expect(api.consultas, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtra elementos mediante la busqueda', (
    WidgetTester tester,
  ) async {
    final CatalogosApiSimulada api = CatalogosApiSimulada();

    await abrirPantalla(tester, api);

    await tester.enterText(
      find.byType(TextField).first,
      'derrumbe',
    );
    await tester.pumpAndSettle();

    expect(find.text('Derrumbe'), findsOneWidget);
    expect(find.text('Bache'), findsNothing);
  });

  testWidgets('filtra elementos activos e inactivos', (
    WidgetTester tester,
  ) async {
    final CatalogosApiSimulada api = CatalogosApiSimulada();

    await abrirPantalla(tester, api);

    await tester.tap(find.text('Inactivos'));
    await tester.pumpAndSettle();

    expect(find.text('Derrumbe'), findsOneWidget);
    expect(find.text('Bache'), findsNothing);

    await tester.tap(find.text('Activos'));
    await tester.pumpAndSettle();

    expect(find.text('Bache'), findsOneWidget);
    expect(find.text('Derrumbe'), findsNothing);
  });

  testWidgets('cambia entre catalogos', (
    WidgetTester tester,
  ) async {
    final CatalogosApiSimulada api = CatalogosApiSimulada();

    await abrirPantalla(tester, api);

    await tester.tap(find.text('Tipos de alertas'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Categorías de nodos').last);
    await tester.pumpAndSettle();

    expect(find.text('Mirador'), findsOneWidget);
    expect(find.text('Bache'), findsNothing);
  });

  testWidgets('crea un elemento nuevo', (
    WidgetTester tester,
  ) async {
    final CatalogosApiSimulada api = CatalogosApiSimulada();

    await abrirPantalla(tester, api);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(find.text('Nuevo elemento'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Clave'),
      'accidente',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre'),
      'Accidente',
    );

    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    expect(find.text('Accidente'), findsOneWidget);
    expect(
      api.datos['alertas']!.any(
        (CatalogoItem item) => item.clave == 'accidente',
      ),
      isTrue,
    );
  });

  testWidgets('impide crear elementos con campos vacios', (
    WidgetTester tester,
  ) async {
    final CatalogosApiSimulada api = CatalogosApiSimulada();

    await abrirPantalla(tester, api);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    expect(
      find.text('Completa los campos obligatorios.'),
      findsOneWidget,
    );
    expect(api.datos['alertas'], hasLength(2));
  });

  testWidgets('edita el nombre de un elemento', (
    WidgetTester tester,
  ) async {
    final CatalogosApiSimulada api = CatalogosApiSimulada();

    await abrirPantalla(tester, api);

    await tester.tap(find.text('Bache'));
    await tester.pumpAndSettle();

    expect(find.text('Editar elemento'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre'),
      'Bache peligroso',
    );

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.text('Bache peligroso'), findsOneWidget);
    expect(api.datos['alertas']!.first.clave, 'bache');
  });

  testWidgets('desactiva un elemento existente', (
    WidgetTester tester,
  ) async {
    final CatalogosApiSimulada api = CatalogosApiSimulada();

    await abrirPantalla(tester, api);

    await tester.tap(find.text('Bache'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(api.datos['alertas']!.first.activo, isFalse);
    expect(find.text('Inactivo'), findsWidgets);
  });

  testWidgets('permite cancelar la creacion', (
    WidgetTester tester,
  ) async {
    final CatalogosApiSimulada api = CatalogosApiSimulada();

    await abrirPantalla(tester, api);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo elemento'), findsNothing);
    expect(api.datos['alertas'], hasLength(2));
  });
}
