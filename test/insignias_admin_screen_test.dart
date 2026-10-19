
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/insignia_admin_item.dart';
import 'package:fit_quest_go/Modulos/admin/data/insignias_admin_api.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/insignias_admin_screen.dart';

class _InsigniasApiFalsa extends InsigniasAdminApi {
  _InsigniasApiFalsa(this.insignias);

  final List<InsigniaAdminItem> insignias;

  int consultas = 0;
  int creaciones = 0;
  int ediciones = 0;

  double? ultimaMetaEditada;

  @override
  Future<List<InsigniaAdminItem>> listarInsignias() async {
    consultas++;
    return List<InsigniaAdminItem>.from(insignias);
  }

  @override
  Future<InsigniaAdminItem> crearInsignia({
    required String codigo,
    required String nombre,
    required String descripcion,
    required String emoji,
    required String tipo,
    required String metrica,
    required double meta,
    bool activa = true,
  }) async {
    creaciones++;

    final InsigniaAdminItem nueva = InsigniaAdminItem(
      id: insignias.length + 100,
      codigo: codigo,
      nombre: nombre,
      descripcion: descripcion,
      emoji: emoji,
      tipo: tipo,
      metrica: metrica,
      meta: meta,
      activa: activa,
    );

    insignias.add(nueva);
    return nueva;
  }

  @override
  Future<InsigniaAdminItem> editarInsignia({
    required int id,
    String? nombre,
    String? descripcion,
    String? emoji,
    String? tipo,
    String? metrica,
    double? meta,
    bool? activa,
  }) async {
    ediciones++;
    ultimaMetaEditada = meta;

    final int indice = insignias.indexWhere(
      (InsigniaAdminItem item) => item.id == id,
    );

    if (indice == -1) {
      throw StateError('Insignia no encontrada');
    }

    final InsigniaAdminItem anterior = insignias[indice];

    final InsigniaAdminItem actualizada = anterior.copyWith(
      nombre: nombre,
      descripcion: descripcion,
      emoji: emoji,
      tipo: tipo,
      metrica: metrica,
      meta: meta,
      activa: activa,
    );

    insignias[indice] = actualizada;
    return actualizada;
  }
}

InsigniaAdminItem _insignia({
  required int id,
  required String codigo,
  required String nombre,
  bool activa = true,
  String tipo = 'hito',
  String metrica = 'rutas',
  double? meta = 5,
}) {
  return InsigniaAdminItem(
    id: id,
    codigo: codigo,
    nombre: nombre,
    descripcion: 'Descripción de $nombre',
    emoji: '🏅',
    tipo: tipo,
    metrica: metrica,
    meta: meta,
    activa: activa,
  );
}

Future<void> _abrir(
  WidgetTester tester,
  _InsigniasApiFalsa api,
) async {
  tester.platformDispatcher.localesTestValue =
      const <Locale>[Locale('es')];
  tester.platformDispatcher.localeTestValue = const Locale('es');

  addTearDown(
    tester.platformDispatcher.clearLocalesTestValue,
  );
  addTearDown(
    tester.platformDispatcher.clearLocaleTestValue,
  );

  await tester.binding.setSurfaceSize(
    const Size(1280, 900),
  );

  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates:
          AppLocalizations.localizationsDelegates,
      supportedLocales:
          AppLocalizations.supportedLocales,
      home: Scaffold(
        body: InsigniasAdminScreen(api: api),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'muestra las insignias obtenidas desde la API',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[
        _insignia(
          id: 1,
          codigo: 'RUTAS_5',
          nombre: 'Explorador',
        ),
        _insignia(
          id: 2,
          codigo: 'KM_10',
          nombre: 'Caminante',
          tipo: 'km',
          metrica: 'km',
          meta: 10,
        ),
      ]);

      await _abrir(tester, api);

      expect(find.text('🏅 Explorador'), findsOneWidget);
      expect(find.text('🏅 Caminante'), findsOneWidget);
      expect(api.consultas, 1);
    },
  );

  testWidgets(
    'muestra el estado activo e inactivo',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[
        _insignia(
          id: 1,
          codigo: 'RUTAS_5',
          nombre: 'Explorador',
        ),
        _insignia(
          id: 2,
          codigo: 'RUTAS_10',
          nombre: 'Aventurero',
          activa: false,
        ),
      ]);

      await _abrir(tester, api);

      expect(find.text('Activa'), findsOneWidget);
      expect(find.text('Inactiva'), findsOneWidget);
    },
  );

  testWidgets(
    'filtra las insignias activas',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[
        _insignia(
          id: 1,
          codigo: 'RUTAS_5',
          nombre: 'Explorador',
        ),
        _insignia(
          id: 2,
          codigo: 'RUTAS_10',
          nombre: 'Aventurero',
          activa: false,
        ),
      ]);

      await _abrir(tester, api);

      await tester.tap(find.text('Activas'));
      await tester.pumpAndSettle();

      expect(find.text('🏅 Explorador'), findsOneWidget);
      expect(find.text('🏅 Aventurero'), findsNothing);
    },
  );

  testWidgets(
    'filtra las insignias inactivas',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[
        _insignia(
          id: 1,
          codigo: 'RUTAS_5',
          nombre: 'Explorador',
        ),
        _insignia(
          id: 2,
          codigo: 'RUTAS_10',
          nombre: 'Aventurero',
          activa: false,
        ),
      ]);

      await _abrir(tester, api);

      await tester.tap(find.text('Inactivas'));
      await tester.pumpAndSettle();

      expect(find.text('🏅 Explorador'), findsNothing);
      expect(find.text('🏅 Aventurero'), findsOneWidget);
    },
  );

  testWidgets(
    'permite buscar por nombre',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[
        _insignia(
          id: 1,
          codigo: 'RUTAS_5',
          nombre: 'Explorador',
        ),
        _insignia(
          id: 2,
          codigo: 'KM_10',
          nombre: 'Caminante',
        ),
      ]);

      await _abrir(tester, api);

      await tester.enterText(
        find.byType(TextField).first,
        'Explorador',
      );
      await tester.pumpAndSettle();

      expect(find.text('🏅 Explorador'), findsOneWidget);
      expect(find.text('🏅 Caminante'), findsNothing);
    },
  );

  testWidgets(
    'permite buscar por código',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[
        _insignia(
          id: 1,
          codigo: 'RUTAS_5',
          nombre: 'Explorador',
        ),
        _insignia(
          id: 2,
          codigo: 'KM_10',
          nombre: 'Caminante',
        ),
      ]);

      await _abrir(tester, api);

      await tester.enterText(
        find.byType(TextField).first,
        'KM_10',
      );
      await tester.pumpAndSettle();

      expect(find.text('🏅 Explorador'), findsNothing);
      expect(find.text('🏅 Caminante'), findsOneWidget);
    },
  );

  testWidgets(
    'abre el formulario de creación',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[]);

      await _abrir(tester, api);

      await tester.tap(find.text('Nuevo'));
      await tester.pumpAndSettle();

      expect(find.text('Nueva insignia'), findsOneWidget);
      expect(find.text('Código único'), findsOneWidget);
      expect(find.text('Nombre'), findsOneWidget);
      expect(find.text('Descripción'), findsOneWidget);
      expect(find.text('Emoji'), findsOneWidget);
      expect(find.text('Meta'), findsOneWidget);
    },
  );

  testWidgets(
    'rechaza la creación con campos vacíos',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[]);

      await _abrir(tester, api);

      await tester.tap(find.text('Nuevo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear insignia'));
      await tester.pumpAndSettle();

      expect(
        find.text('Completa todos los campos obligatorios.'),
        findsOneWidget,
      );

      expect(api.creaciones, 0);
    },
  );

  testWidgets(
    'crea una insignia y actualiza el listado',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[]);

      await _abrir(tester, api);

      await tester.tap(find.text('Nuevo'));
      await tester.pumpAndSettle();

      final Finder campos = find.byType(TextField);

      await tester.enterText(campos.at(1), 'RUTAS_20');
      await tester.enterText(campos.at(2), 'Gran explorador');
      await tester.enterText(campos.at(3), 'Completa veinte rutas');
      await tester.enterText(campos.at(4), '🏆');
      await tester.enterText(campos.at(5), '20');

      await tester.tap(find.text('Crear insignia'));
      await tester.pumpAndSettle();

      expect(api.creaciones, 1);
      expect(find.text('🏆 Gran explorador'), findsOneWidget);
    },
  );

  testWidgets(
    'abre el formulario de edición',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[
        _insignia(
          id: 1,
          codigo: 'RUTAS_5',
          nombre: 'Explorador',
        ),
      ]);

      await _abrir(tester, api);

      await tester.tap(find.text('🏅 Explorador'));
      await tester.pumpAndSettle();

      expect(find.text('Editar insignia'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);
    },
  );

  testWidgets(
    'edita el nombre de una insignia',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[
        _insignia(
          id: 1,
          codigo: 'RUTAS_5',
          nombre: 'Explorador',
        ),
      ]);

      await _abrir(tester, api);

      await tester.tap(find.text('🏅 Explorador'));
      await tester.pumpAndSettle();

      final Finder campos = find.byType(TextField);

      await tester.enterText(
        campos.at(2),
        'Explorador avanzado',
      );

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(api.ediciones, 1);
      expect(
        find.text('🏅 Explorador avanzado'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'permite desactivar una insignia',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[
        _insignia(
          id: 1,
          codigo: 'RUTAS_5',
          nombre: 'Explorador',
        ),
      ]);

      await _abrir(tester, api);

      await tester.tap(find.text('🏅 Explorador'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(api.ediciones, 1);
      expect(api.insignias.single.activa, false);
      expect(find.text('Inactiva'), findsOneWidget);
    },
  );

  testWidgets(
    'permite reactivar una insignia',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[
        _insignia(
          id: 1,
          codigo: 'RUTAS_5',
          nombre: 'Explorador',
          activa: false,
        ),
      ]);

      await _abrir(tester, api);

      await tester.tap(find.text('🏅 Explorador'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(api.ediciones, 1);
      expect(api.insignias.single.activa, true);
      expect(find.text('Activa'), findsOneWidget);
    },
  );

  // Prueba 14: insignia especial con meta nula.
  testWidgets(
    'edita una insignia especial conservando meta nula',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[
        _insignia(
          id: 14,
          codigo: 'ESPECIAL_1',
          nombre: 'Insignia especial',
          tipo: 'hito',
          metrica: 'especial',
          meta: null,
        ),
      ]);

      await _abrir(tester, api);

      expect(api.insignias.single.meta, isNull);
      expect(api.insignias.single.metrica, 'especial');

      await tester.tap(find.text('🏅 Insignia especial'));
      await tester.pumpAndSettle();

      expect(find.text('Editar insignia'), findsOneWidget);

      final Finder campos = find.byType(TextField);

      await tester.enterText(
        campos.at(2),
        'Insignia especial actualizada',
      );

      // No se introduce ninguna meta numérica.
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(api.ediciones, 1);
      expect(api.ultimaMetaEditada, isNull);

      expect(
        api.insignias.single.nombre,
        'Insignia especial actualizada',
      );
      expect(api.insignias.single.tipo, 'hito');
      expect(api.insignias.single.metrica, 'especial');
      expect(api.insignias.single.meta, isNull);

      expect(
        find.text('🏅 Insignia especial actualizada'),
        findsOneWidget,
      );
    },
  );

  // Prueba 15: el tipo km restringe las métricas disponibles.
  testWidgets(
    'actualiza y restringe la métrica al cambiar el tipo',
    (WidgetTester tester) async {
      final api = _InsigniasApiFalsa(<InsigniaAdminItem>[]);

      await _abrir(tester, api);

      await tester.tap(find.text('Nuevo'));
      await tester.pumpAndSettle();

      Finder selectores = find.byType(DropdownButtonFormField<String>);
      expect(selectores, findsNWidgets(2));

      await tester.tap(selectores.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kilómetros').last);
      await tester.pumpAndSettle();

      selectores = find.byType(DropdownButtonFormField<String>);

      final DropdownButtonFormField<String> metricaKm =
          tester.widget<DropdownButtonFormField<String>>(selectores.last);

      expect(metricaKm.initialValue, 'km');
      expect(
        tester.widget<DropdownButton<String>>(find.descendant(of: selectores.last, matching: find.byType(DropdownButton<String>))).items!.map((item) => item.value).toList(),
        <String>['km'],
      );

      await tester.tap(selectores.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hito').last);
      await tester.pumpAndSettle();

      selectores = find.byType(DropdownButtonFormField<String>);

      final DropdownButtonFormField<String> metricaHito =
          tester.widget<DropdownButtonFormField<String>>(selectores.last);

      expect(
        tester.widget<DropdownButton<String>>(find.descendant(of: selectores.last, matching: find.byType(DropdownButton<String>))).items!.map((item) => item.value).toList(),
        containsAll(<String>[
          'km',
          'rutas',
          'alertas',
          'nodos',
          'especial',
        ]),
      );

      expect(api.creaciones, 0);
    },
  );}
