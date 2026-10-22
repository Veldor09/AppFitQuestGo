import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogo_item.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogos_api.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/aportes_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'helpers/montar.dart';

class _RutaApiFalsa extends RutaApi {
  @override
  Future<List<Ruta>> misRutas() async => <Ruta>[];
}

class _AlertaApiFalsa extends AlertaApi {
  @override
  Future<List<Alerta>> misAlertas() async => <Alerta>[];
}

class _CatalogosFalsos extends CatalogosApi {
  @override
  Future<List<CatalogoItem>> listarItemsActivos(String catalogo) async =>
      <CatalogoItem>[
        CatalogoItem(
          id: 1,
          catalogo: 'nodos',
          clave: 'agua',
          nombre: 'Agua',
          activo: true,
        ),
        CatalogoItem(
          id: 2,
          catalogo: 'nodos',
          clave: 'mirador',
          nombre: 'Mirador',
          activo: true,
        ),
      ];
}

class _NodoApiFalsa extends NodoApi {
  _NodoApiFalsa(this.nodos);

  List<Nodo> nodos;
  Object? errorAlEliminar;
  final List<int> eliminados = <int>[];
  final List<Map<String, Object?>> actualizados = <Map<String, Object?>>[];

  @override
  Future<List<Nodo>> misNodos() async => List<Nodo>.of(nodos);

  @override
  Future<void> eliminar(int id) async {
    if (errorAlEliminar != null) throw errorAlEliminar!;
    eliminados.add(id);
    nodos = nodos.where((Nodo n) => n.id != id).toList();
  }

  @override
  Future<Nodo> actualizar(
    int id, {
    required String nombre,
    required String categoria,
    String? categoriaOtro,
    required double lat,
    required double lng,
    String? descripcion,
    String? beneficio,
  }) async {
    actualizados.add(<String, Object?>{
      'id': id,
      'nombre': nombre,
      'categoria': categoria,
      'lat': lat,
      'lng': lng,
      'descripcion': descripcion,
    });
    final Nodo nuevo = Nodo(
      id: id,
      nombre: nombre,
      categoria: categoria,
      lat: lat,
      lng: lng,
      estado: 'Aprobado',
      descripcion: descripcion,
    );
    nodos = nodos.map((Nodo n) => n.id == id ? nuevo : n).toList();
    return nuevo;
  }
}

const Nodo _fuente = Nodo(
  id: 11,
  nombre: 'Fuente del parque',
  categoria: 'agua',
  lat: 9.93,
  lng: -84.09,
  estado: 'Aprobado',
  descripcion: 'Agua potable',
);

Future<_NodoApiFalsa> _abrir(
  WidgetTester tester, {
  List<Nodo> nodos = const <Nodo>[_fuente],
}) async {
  final _NodoApiFalsa api = _NodoApiFalsa(nodos);
  await montarApp(
    tester,
    AportesScreen(
      initialTab: 2,
      rutaApi: _RutaApiFalsa(),
      alertaApi: _AlertaApiFalsa(),
      nodoApi: api,
      catalogosApi: _CatalogosFalsos(),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

Future<void> _abrirMenu(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(ValueKey<String>('menu-nodo-$id')));
  await tester.pumpAndSettle();
}

void main() {
  group('Mis aportes > Nodos', () {
    testWidgets('cada punto propio ofrece editar y eliminar', (tester) async {
      await _abrir(tester);

      await _abrirMenu(tester, 11);

      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('eliminar pide confirmacion, borra el punto y recarga la lista', (
      tester,
    ) async {
      final _NodoApiFalsa api = await _abrir(tester);

      await _abrirMenu(tester, 11);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar este punto?'), findsOneWidget);
      expect(find.textContaining('Fuente del parque'), findsWidgets);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('confirmar-eliminar-aporte')),
          matching: find.text('Eliminar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(api.eliminados, <int>[11]);
      expect(find.text('Punto eliminado.'), findsOneWidget);
      expect(find.text('Fuente del parque'), findsNothing);
    });

    testWidgets('cancelar la confirmacion no borra nada', (tester) async {
      final _NodoApiFalsa api = await _abrir(tester);

      await _abrirMenu(tester, 11);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.eliminados, isEmpty);
      expect(find.text('Fuente del parque'), findsOneWidget);
    });

    testWidgets('si el servidor rechaza eliminar avisa y deja el punto', (
      tester,
    ) async {
      final _NodoApiFalsa api = await _abrir(tester);
      api.errorAlEliminar = ApiException(403, 'Este nodo no te pertenece');

      await _abrirMenu(tester, 11);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('confirmar-eliminar-aporte')),
          matching: find.text('Eliminar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No se pudo completar la acción.'), findsOneWidget);
      expect(find.text('Fuente del parque'), findsOneWidget);
    });

    testWidgets('editar abre el formulario con los datos del punto y guarda', (
      tester,
    ) async {
      final _NodoApiFalsa api = await _abrir(tester);

      await _abrirMenu(tester, 11);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar punto'), findsOneWidget);
      expect(find.text('Fuente del parque'), findsWidgets);
      expect(find.text('Agua potable'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Fuente del parque'),
        'Fuente nueva',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(api.actualizados, hasLength(1));
      expect(api.actualizados.single['id'], 11);
      expect(api.actualizados.single['nombre'], 'Fuente nueva');
      expect(api.actualizados.single['categoria'], 'agua');
      // El lugar se queda donde estaba.
      expect(api.actualizados.single['lat'], 9.93);
      expect(api.actualizados.single['lng'], -84.09);
      expect(find.text('Punto actualizado.'), findsOneWidget);
      expect(find.text('Fuente nueva'), findsOneWidget);
    });
  });
}
