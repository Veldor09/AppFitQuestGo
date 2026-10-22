import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/ruta_detalle_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/rutas_screen.dart';
import 'helpers/calificacion_falsa.dart';
import 'helpers/montar.dart';

const List<PuntoRuta> _puntos = <PuntoRuta>[
  PuntoRuta(lat: 9.9281, lng: -84.0907),
  PuntoRuta(lat: 9.9291, lng: -84.0917),
];

Ruta _ruta(int id, String nombre, String estado) => Ruta(
  id: id,
  nombre: nombre,
  actividades: const <String>['running'],
  dificultad: 'facil',
  distanciaKm: 3.2,
  puntos: _puntos,
  estado: estado,
);

class _RutaApiFalsa extends RutaApi {
  List<Ruta> mias = <Ruta>[
    _ruta(2, 'Mi vuelta al lago', 'Privada'),
    _ruta(3, 'Cerro grande', 'Publicada'),
  ];
  Object? errorAlEliminar;
  final List<int> eliminadas = <int>[];

  @override
  Future<Set<int>> favoritasIds() async => <int>{};

  @override
  Future<List<Ruta>> favoritas() async => <Ruta>[];

  @override
  Future<List<Ruta>> explorar() async => <Ruta>[
    _ruta(1, 'Sendero del rio', 'Publicada'),
  ];

  @override
  Future<List<Ruta>> misRutas() async => List<Ruta>.of(mias);

  @override
  Future<void> eliminar(int id) async {
    if (errorAlEliminar != null) throw errorAlEliminar!;
    eliminadas.add(id);
    mias = mias.where((Ruta r) => r.id != id).toList();
  }
}

Future<_RutaApiFalsa> _abrirMisRutas(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final _RutaApiFalsa api = _RutaApiFalsa();
  await montarApp(
    tester,
    Scaffold(body: RutasScreen(api: api, initialTab: 1)),
  );
  await tester.pumpAndSettle();
  return api;
}

Finder get _confirmar => find.descendant(
  of: find.byKey(const ValueKey<String>('confirmar-eliminar-ruta')),
  matching: find.text('Eliminar ruta'),
);

void main() {
  usarCalificacionesFalsas();

  group('Mis rutas: eliminar', () {
    testWidgets('cada ruta mia tiene su boton de eliminar', (tester) async {
      await _abrirMisRutas(tester);

      expect(
        find.byKey(const ValueKey<String>('eliminar-ruta-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('eliminar-ruta-3')),
        findsOneWidget,
      );
    });

    testWidgets('pide confirmacion, elimina y recarga la lista', (tester) async {
      final _RutaApiFalsa api = await _abrirMisRutas(tester);

      await tester.tap(find.byKey(const ValueKey<String>('eliminar-ruta-2')));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar esta ruta?'), findsOneWidget);
      await tester.tap(_confirmar);
      await tester.pumpAndSettle();

      expect(api.eliminadas, <int>[2]);
      expect(find.text('Ruta eliminada.'), findsOneWidget);
      expect(find.text('Mi vuelta al lago'), findsNothing);
      expect(find.text('Cerro grande'), findsOneWidget);
    });

    testWidgets('cancelar no elimina nada', (tester) async {
      final _RutaApiFalsa api = await _abrirMisRutas(tester);

      await tester.tap(find.byKey(const ValueKey<String>('eliminar-ruta-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.eliminadas, isEmpty);
      expect(find.text('Mi vuelta al lago'), findsOneWidget);
    });

    testWidgets('si el servidor falla avisa y deja la ruta', (tester) async {
      final _RutaApiFalsa api = await _abrirMisRutas(tester);
      api.errorAlEliminar = ApiException(403, 'Esta ruta no te pertenece');

      await tester.tap(find.byKey(const ValueKey<String>('eliminar-ruta-2')));
      await tester.pumpAndSettle();
      await tester.tap(_confirmar);
      await tester.pumpAndSettle();

      expect(find.text('No se pudo eliminar la ruta.'), findsOneWidget);
      expect(find.text('Mi vuelta al lago'), findsOneWidget);
    });

    testWidgets('en Explorar no se ofrece eliminar rutas ajenas', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await montarApp(
        tester,
        Scaffold(body: RutasScreen(api: _RutaApiFalsa())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sendero del rio'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('eliminar-ruta-1')),
        findsNothing,
      );
    });
  });

  group('Detalle de ruta: eliminar', () {
    testWidgets('en mi ruta elimina, avisa del cambio y cierra el detalle', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final _RutaApiFalsa api = _RutaApiFalsa();
      int cambios = 0;
      await montarApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext _) => RutaDetalleScreen(
                    ruta: _ruta(2, 'Mi vuelta al lago', 'Privada'),
                    api: api,
                    puedeEliminar: true,
                    onCambio: () => cambios++,
                    calificaciones: CalificacionApiFalsa(),
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

      await tester.ensureVisible(find.byKey(const ValueKey<String>('eliminar-ruta')));
      await tester.tap(find.byKey(const ValueKey<String>('eliminar-ruta')));
      await tester.pumpAndSettle();
      await tester.tap(_confirmar);
      await tester.pumpAndSettle();

      expect(api.eliminadas, <int>[2]);
      expect(cambios, 1);
      expect(find.byType(RutaDetalleScreen), findsNothing);
    });

    testWidgets('en una ruta ajena no aparece el boton', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await montarApp(
        tester,
        RutaDetalleScreen(
          ruta: _ruta(1, 'Sendero del rio', 'Publicada'),
          api: _RutaApiFalsa(),
          calificaciones: CalificacionApiFalsa(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('eliminar-ruta')), findsNothing);
    });
  });
}
