
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogo_item.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogos_api.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';
import 'package:fit_quest_go/Modulos/alertas/presentation/formulario_alerta.dart';

typedef _Reporte = ({
  String tipo,
  String? tipoOtro,
  String gravedad,
  String? descripcion,
});

CatalogoItem _item(
  String clave,
  String nombre, {
  bool activo = true,
  int id = 1,
}) {
  return CatalogoItem(
    id: id,
    catalogo: 'alertas',
    clave: clave,
    nombre: nombre,
    activo: activo,
  );
}

List<CatalogoItem> _catalogoInicial() => <CatalogoItem>[
      _item('arbol_caido', 'Árbol caído', id: 1),
      _item('bache', 'Bache', id: 2),
      _item('derrumbe', 'Derrumbe', id: 3),
      _item('inundacion', 'Inundación', id: 4),
      _item('perro', 'Perro bravo', id: 5),
      _item('via_cerrada', 'Vía cerrada', id: 6),
      _item('accidente', 'Accidente', id: 7),
      _item('zona_insegura', 'Zona insegura', id: 8),
      _item('cable_caido', 'Cable caído', id: 9),
      _item('otro', 'Otro', id: 10),
    ];

class _CatalogosApiFalsa extends CatalogosApi {
  _CatalogosApiFalsa({List<CatalogoItem>? items})
      : items = items ?? _catalogoInicial();

  List<CatalogoItem> items;
  Object? error;
  Completer<List<CatalogoItem>>? respuestaPendiente;
  int consultas = 0;

  @override
  Future<List<CatalogoItem>> listarItemsActivos(String catalogo) async {
    expect(catalogo, 'alertas');
    consultas++;

    if (respuestaPendiente != null) {
      return respuestaPendiente!.future;
    }

    if (error != null) throw error!;

    return items.where((CatalogoItem item) => item.activo).toList();
  }
}

class _AlertaApiFalsa extends AlertaApi {
  final List<_Reporte> reportes = <_Reporte>[];
  Object? error;

  @override
  Future<Alerta> reportar({
    required String tipo,
    String? tipoOtro,
    required String gravedad,
    required double lat,
    required double lng,
    String? descripcion,
  }) async {
    if (error != null) throw error!;

    reportes.add((
      tipo: tipo,
      tipoOtro: tipoOtro,
      gravedad: gravedad,
      descripcion: descripcion,
    ));

    return Alerta(
      id: 1,
      tipo: tipo,
      tipoOtro: tipoOtro,
      gravedad: gravedad,
      lat: lat,
      lng: lng,
      estado: 'Activa',
    );
  }
}

class _Escenario {
  _Escenario({List<CatalogoItem>? items})
      : catalogosApi = _CatalogosApiFalsa(items: items);

  final _AlertaApiFalsa api = _AlertaApiFalsa();
  final _CatalogosApiFalsa catalogosApi;

  Alerta? resultado;
  bool cerrado = false;

  Future<void> abrir(WidgetTester tester) async {
    tester.platformDispatcher.localesTestValue = const <Locale>[
      Locale('es'),
    ];
    tester.platformDispatcher.localeTestValue = const Locale('es');

    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                resultado = await showModalBottomSheet<Alerta>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext _) => FormularioAlerta(
                    api: api,
                    catalogosApi: catalogosApi,
                    lat: 9.93,
                    lng: -84.09,
                  ),
                );
                cerrado = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> publicar(WidgetTester tester) async {
    await tester.tap(
      find.widgetWithText(FilledButton, 'Publicar alerta'),
    );
    await tester.pumpAndSettle();
  }

  bool botonPublicarHabilitado(WidgetTester tester) {
    return tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Publicar alerta'),
            )
            .onPressed !=
        null;
  }
}

void main() {
  testWidgets(
    'ofrece los tipos de alerta activos para elegir, sin campo de texto',
    (WidgetTester tester) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);

      expect(e.catalogosApi.consultas, 1);

      for (final String tipo in <String>[
        'Arbol caido',
        'Bache',
        'Derrumbe',
        'Inundacion',
        'Perro bravo',
        'Via cerrada u obra',
        'Accidente',
        'Zona insegura',
        'Cable o poste caido',
        'Otro',
      ]) {
        expect(find.text(tipo), findsOneWidget, reason: tipo);
      }

      expect(find.widgetWithText(TextFormField, 'Tipo'), findsNothing);
      expect(find.text('Que tipo de alerta es?'), findsNothing);
    },
  );

  testWidgets(
    'sin elegir tipo avisa y no publica',
    (WidgetTester tester) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);

      await e.publicar(tester);

      expect(find.text('Elegi un tipo de alerta'), findsOneWidget);
      expect(e.api.reportes, isEmpty);
      expect(e.cerrado, isFalse);
    },
  );

  testWidgets(
    'un tipo del catalogo se publica con su clave y gravedad media',
    (WidgetTester tester) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);

      await tester.tap(find.text('Bache'));
      await tester.pump();
      await e.publicar(tester);

      expect(e.api.reportes, hasLength(1));
      expect(e.api.reportes.single.tipo, 'bache');
      expect(e.api.reportes.single.tipoOtro, isNull);
      expect(e.api.reportes.single.gravedad, 'media');
      expect(e.resultado?.tipo, 'bache');
    },
  );

  testWidgets(
    'es de seleccion simple: elegir otro tipo reemplaza al anterior',
    (WidgetTester tester) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);

      await tester.tap(find.text('Bache'));
      await tester.tap(find.text('Derrumbe'));
      await tester.pump();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await e.publicar(tester);

      expect(e.api.reportes.single.tipo, 'derrumbe');
    },
  );

  group('"Otro"', () {
    testWidgets(
      'pide escribir de que alerta se trata',
      (WidgetTester tester) async {
        final _Escenario e = _Escenario();
        await e.abrir(tester);

        await tester.tap(find.text('Otro'));
        await tester.pump();

        expect(
          find.text('Que tipo de alerta es?'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'sin texto no publica',
      (WidgetTester tester) async {
        final _Escenario e = _Escenario();
        await e.abrir(tester);

        await tester.tap(find.text('Otro'));
        await tester.pump();

        await e.publicar(tester);

        expect(find.text('Obligatorio'), findsOneWidget);
        expect(e.api.reportes, isEmpty);
      },
    );

    testWidgets(
      'con texto lo envia junto a la clave "otro"',
      (WidgetTester tester) async {
        final _Escenario e = _Escenario();
        await e.abrir(tester);

        await tester.tap(find.text('Otro'));
        await tester.pump();

        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Que tipo de alerta es?',
          ),
          'Poste inclinado',
        );

        await e.publicar(tester);

        expect(e.api.reportes.single.tipo, 'otro');
        expect(e.api.reportes.single.tipoOtro, 'Poste inclinado');
      },
    );

    testWidgets(
      'si cambias a un tipo del catalogo el campo desaparece '
      'y su texto no viaja',
      (WidgetTester tester) async {
        final _Escenario e = _Escenario();
        await e.abrir(tester);

        await tester.tap(find.text('Otro'));
        await tester.pump();

        await tester.enterText(
          find.widgetWithText(
            TextFormField,
            'Que tipo de alerta es?',
          ),
          'Poste inclinado',
        );

        await tester.tap(find.text('Bache'));
        await tester.pump();

        expect(find.text('Que tipo de alerta es?'), findsNothing);

        await e.publicar(tester);

        expect(e.api.reportes.single.tipo, 'bache');
        expect(e.api.reportes.single.tipoOtro, isNull);
      },
    );
  });

  testWidgets(
    'la gravedad elegida viaja en el reporte',
    (WidgetTester tester) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);

      await tester.tap(find.text('Perro bravo'));
      await tester.pump();

      await tester.tap(find.text('Media'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alta').last);
      await tester.pumpAndSettle();

      await e.publicar(tester);

      expect(e.api.reportes.single.gravedad, 'alta');
    },
  );

  testWidgets(
    'la descripcion es opcional y viaja si se escribe',
    (WidgetTester tester) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);

      await tester.tap(find.text('Accidente'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Descripcion (opcional)',
        ),
        'Dos motos en la curva',
      );

      await e.publicar(tester);

      expect(
        e.api.reportes.single.descripcion,
        'Dos motos en la curva',
      );
    },
  );

  testWidgets(
    'si el servidor falla avisa y la hoja sigue abierta para reintentar',
    (WidgetTester tester) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);

      e.api.error = StateError('sin red');

      await tester.tap(find.text('Bache'));
      await tester.pump();

      await e.publicar(tester);

      expect(
        find.textContaining('No se pudo enviar'),
        findsOneWidget,
      );
      expect(e.cerrado, isFalse);
      expect(e.botonPublicarHabilitado(tester), isTrue);
    },
  );

  group('Integracion ADM-11', () {
    testWidgets(
      'no muestra categorias desactivadas',
      (WidgetTester tester) async {
        final _Escenario e = _Escenario(
          items: <CatalogoItem>[
            _item('bache', 'Bache', id: 1),
            _item('derrumbe', 'Derrumbe', activo: false, id: 2),
            _item('otro', 'Otro', id: 3),
          ],
        );

        await e.abrir(tester);

        expect(find.text('Bache'), findsOneWidget);
        expect(find.text('Derrumbe'), findsNothing);
        expect(find.text('Otro'), findsOneWidget);
      },
    );

    testWidgets(
      'muestra nuevas categorias con el nombre del administrador',
      (WidgetTester tester) async {
        final _Escenario e = _Escenario(
          items: <CatalogoItem>[
            _item('bache', 'Bache', id: 1),
            _item('puente_danado', 'Puente dañado', id: 2),
          ],
        );

        await e.abrir(tester);

        expect(find.text('Puente dañado'), findsOneWidget);

        await tester.tap(find.text('Puente dañado'));
        await tester.pump();

        await e.publicar(tester);

        expect(e.api.reportes.single.tipo, 'puente_danado');
      },
    );

    testWidgets(
      'mantiene los iconos de las categorias conocidas',
      (WidgetTester tester) async {
        final _Escenario e = _Escenario(
          items: <CatalogoItem>[
            _item('bache', 'Bache'),
          ],
        );

        await e.abrir(tester);

        expect(
          find.byIcon(Icons.report_problem_outlined),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'usa icono generico para categorias nuevas',
      (WidgetTester tester) async {
        final _Escenario e = _Escenario(
          items: <CatalogoItem>[
            _item('puente_danado', 'Puente dañado'),
          ],
        );

        await e.abrir(tester);

        expect(
          find.byIcon(Icons.category_outlined),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'sin categorias activas no permite publicar',
      (WidgetTester tester) async {
        final _Escenario e = _Escenario(
          items: <CatalogoItem>[],
        );

        await e.abrir(tester);

        expect(
          find.text('No hay tipos de alerta disponibles.'),
          findsOneWidget,
        );

        expect(e.botonPublicarHabilitado(tester), isFalse);
        expect(e.api.reportes, isEmpty);
      },
    );

    testWidgets(
      'si falla la carga bloquea publicar y permite reintentar',
      (WidgetTester tester) async {
        final _Escenario e = _Escenario();
        e.catalogosApi.error = StateError('sin conexión');

        await e.abrir(tester);

        expect(
          find.text('No se pudieron cargar los tipos de alerta.'),
          findsOneWidget,
        );

        expect(e.botonPublicarHabilitado(tester), isFalse);

        e.catalogosApi.error = null;

        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(find.text('Bache'), findsOneWidget);
        expect(e.botonPublicarHabilitado(tester), isTrue);
        expect(e.catalogosApi.consultas, 2);
      },
    );

    testWidgets(
      'mientras carga el catalogo no permite publicar',
      (WidgetTester tester) async {
        final _Escenario e = _Escenario();
        final Completer<List<CatalogoItem>> pendiente =
            Completer<List<CatalogoItem>>();

        e.catalogosApi.respuestaPendiente = pendiente;

        await e.abrir(tester);

        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
        );
        expect(e.botonPublicarHabilitado(tester), isFalse);

        pendiente.complete(_catalogoInicial());

        await tester.pumpAndSettle();

        expect(find.text('Bache'), findsOneWidget);
        expect(e.botonPublicarHabilitado(tester), isTrue);
      },
    );

    testWidgets(
      'si la opcion otro esta desactivada no aparece su campo',
      (WidgetTester tester) async {
        final _Escenario e = _Escenario(
          items: <CatalogoItem>[
            _item('bache', 'Bache', id: 1),
            _item('otro', 'Otro', activo: false, id: 2),
          ],
        );

        await e.abrir(tester);

        expect(find.text('Bache'), findsOneWidget);
        expect(find.text('Otro'), findsNothing);
        expect(find.text('Que tipo de alerta es?'), findsNothing);
      },
    );
  });
}
