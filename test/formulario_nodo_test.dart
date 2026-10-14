
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/fotos/selector_foto.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogo_item.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogos_api.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/formulario_nodo.dart';

/// PNG valido de 1x1 px para las pruebas de fotografias.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

CatalogoItem _categoria(
  String clave,
  String nombre, {
  bool activo = true,
  int id = 1,
}) {
  return CatalogoItem(
    id: id,
    catalogo: 'nodos',
    clave: clave,
    nombre: nombre,
    activo: activo,
  );
}

List<CatalogoItem> _categoriasIniciales() => <CatalogoItem>[
  _categoria('agua', 'Agua', id: 1),
  _categoria('mirador', 'Mirador', id: 2),
  _categoria('taller', 'Taller', id: 3),
  _categoria('restaurante', 'Restaurante', id: 4),
  _categoria('comercio', 'Comercio', id: 5),
  _categoria('banos', 'Baños', id: 6),
  _categoria('parqueo', 'Parqueo', id: 7),
  _categoria('primeros_auxilios', 'Primeros auxilios', id: 8),
  _categoria('otro', 'Otro', id: 9),
];

class _CatalogosApiFalsa extends CatalogosApi {
  List<CatalogoItem> categorias = _categoriasIniciales();
  Object? error;
  Completer<List<CatalogoItem>>? pendiente;
  int consultas = 0;
  final List<String> catalogosConsultados = <String>[];

  @override
  Future<List<CatalogoItem>> listarItemsActivos(String catalogo) async {
    consultas++;
    catalogosConsultados.add(catalogo);

    if (error != null) throw error!;

    if (pendiente != null) {
      return pendiente!.future;
    }

    return categorias;
  }
}

class _NodoApiFalsa extends NodoApi {
  /// Orden de llamadas: proponer y subirFoto:ID:BYTES.
  final List<String> eventos = <String>[];
  final List<Map<String, Object?>> propuestas = <Map<String, Object?>>[];

  Uint8List? fotoSubida;
  Object? errorAlProponer;
  Object? errorAlSubirFoto;

  Nodo _nodo(String nombre, String categoria, String? otro) => Nodo(
    id: 42,
    nombre: nombre,
    categoria: categoria,
    categoriaOtro: otro,
    lat: 9.93,
    lng: -84.09,
    estado: 'Pendiente',
  );

  @override
  Future<Nodo> proponer({
    required String nombre,
    required String categoria,
    String? categoriaOtro,
    required double lat,
    required double lng,
    String? descripcion,
    String? beneficio,
  }) async {
    if (errorAlProponer != null) throw errorAlProponer!;

    eventos.add('proponer');
    propuestas.add(<String, Object?>{
      'nombre': nombre,
      'categoria': categoria,
      'categoriaOtro': categoriaOtro,
      'descripcion': descripcion,
    });

    return _nodo(nombre, categoria, categoriaOtro);
  }

  @override
  Future<Nodo> subirFoto(int id, Uint8List bytes) async {
    if (errorAlSubirFoto != null) throw errorAlSubirFoto!;

    eventos.add('subirFoto:$id:${bytes.length}');
    fotoSubida = bytes;

    return Nodo(
      id: id,
      nombre: 'x',
      categoria: 'agua',
      lat: 9.93,
      lng: -84.09,
      estado: 'Pendiente',
      conFoto: true,
    );
  }
}

class _SelectorFalso implements SelectorFoto {
  Uint8List? respuesta;
  final List<OrigenFoto> pedidos = <OrigenFoto>[];

  @override
  Future<Uint8List?> elegir(OrigenFoto origen) async {
    pedidos.add(origen);
    return respuesta;
  }
}

class _Escenario {
  final _NodoApiFalsa api = _NodoApiFalsa();
  final _CatalogosApiFalsa catalogosApi = _CatalogosApiFalsa();
  final _SelectorFalso selector = _SelectorFalso();

  Nodo? resultado;
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
        builder: (BuildContext context, Widget? child) =>
            NotificacionesHost(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                resultado = await showModalBottomSheet<Nodo>(
                  context: context,
                  isScrollControlled: true,
                  builder: (BuildContext _) => FormularioNodo(
                    api: api,
                    lat: 9.93,
                    lng: -84.09,
                    selectorFoto: selector,
                    catalogosApi: catalogosApi,
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

    // No usar pumpAndSettle aqui: algunas pruebas dejan
    // intencionalmente una solicitud pendiente con un spinner.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> escribirNombre(
    WidgetTester tester, [
    String nombre = 'Fuente',
  ]) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      nombre,
    );
  }

  Future<void> enviar(WidgetTester tester) async {
    final Finder boton = find.widgetWithText(FilledButton, 'Enviar');

    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('ofrece las categorias para elegir, sin campo de texto', (
    WidgetTester tester,
  ) async {
    final _Escenario e = _Escenario();
    await e.abrir(tester);

    for (final String categoria in <String>[
      'Agua',
      'Mirador',
      'Taller',
      'Restaurante',
      'Comercio',
      'Banos',
      'Parqueo',
      'Primeros auxilios',
      'Otro',
    ]) {
      expect(find.text(categoria), findsOneWidget, reason: categoria);
    }

    expect(find.widgetWithText(TextFormField, 'Categoria'), findsNothing);
    expect(e.catalogosApi.catalogosConsultados, <String>['nodos']);
  });

  testWidgets('sin categoria avisa y no envia', (
    WidgetTester tester,
  ) async {
    final _Escenario e = _Escenario();
    await e.abrir(tester);
    await e.escribirNombre(tester);

    await e.enviar(tester);

    expect(find.text('Elegi una categoria'), findsOneWidget);
    expect(e.api.propuestas, isEmpty);
    expect(e.cerrado, isFalse);
  });

  testWidgets('sin nombre avisa y no envia', (
    WidgetTester tester,
  ) async {
    final _Escenario e = _Escenario();
    await e.abrir(tester);

    await tester.tap(find.text('Agua'));
    await tester.pump();
    await e.enviar(tester);

    expect(find.text('Obligatorio'), findsOneWidget);
    expect(e.api.propuestas, isEmpty);
  });

  testWidgets('una categoria del catalogo se envia con su clave y sin foto', (
    WidgetTester tester,
  ) async {
    final _Escenario e = _Escenario();
    await e.abrir(tester);
    await e.escribirNombre(tester, 'Fuente del parque');

    await tester.tap(find.text('Agua'));
    await tester.pump();
    await e.enviar(tester);

    expect(e.api.propuestas.single['nombre'], 'Fuente del parque');
    expect(e.api.propuestas.single['categoria'], 'agua');
    expect(e.api.propuestas.single['categoriaOtro'], isNull);
    expect(e.api.eventos, <String>['proponer']);
    expect(e.resultado?.id, 42);
  });

  group('"Otro"', () {
    testWidgets('pide escribir cual es', (WidgetTester tester) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);

      await tester.tap(find.text('Otro'));
      await tester.pump();

      expect(find.text('Que categoria es?'), findsOneWidget);
    });

    testWidgets('sin texto no envia; con texto lo manda junto a "otro"', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);
      await e.escribirNombre(tester);

      await tester.tap(find.text('Otro'));
      await tester.pump();

      await e.enviar(tester);

      expect(find.text('Obligatorio'), findsOneWidget);
      expect(e.api.propuestas, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Que categoria es?'),
        'Zona de picnic',
      );
      await e.enviar(tester);

      expect(e.api.propuestas.single['categoria'], 'otro');
      expect(e.api.propuestas.single['categoriaOtro'], 'Zona de picnic');
    });

    testWidgets('si cambias a otra categoria, el texto escrito no viaja', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);
      await e.escribirNombre(tester);

      await tester.tap(find.text('Otro'));
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Que categoria es?'),
        'Zona de picnic',
      );

      await tester.tap(find.text('Mirador'));
      await tester.pump();
      await e.enviar(tester);

      expect(find.text('Que categoria es?'), findsNothing);
      expect(e.api.propuestas.single['categoria'], 'mirador');
      expect(e.api.propuestas.single['categoriaOtro'], isNull);
    });
  });

  group('foto opcional', () {
    testWidgets('al inicio ofrece camara y galeria, sin vista previa', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);

      expect(find.text('Foto (opcional)'), findsOneWidget);
      expect(find.text('Camara'), findsOneWidget);
      expect(find.text('Galeria'), findsOneWidget);
      expect(find.text('Quitar foto'), findsNothing);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('elegir de la galeria muestra la vista previa y "Quitar foto"', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      e.selector.respuesta = _png;
      await e.abrir(tester);

      await tester.tap(find.text('Galeria'));
      await tester.pumpAndSettle();

      expect(e.selector.pedidos, <OrigenFoto>[OrigenFoto.galeria]);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Quitar foto'), findsOneWidget);
      expect(find.text('Camara'), findsNothing);
    });

    testWidgets('la camara pide el origen camara', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      e.selector.respuesta = _png;
      await e.abrir(tester);

      await tester.tap(find.text('Camara'));
      await tester.pumpAndSettle();

      expect(e.selector.pedidos, <OrigenFoto>[OrigenFoto.camara]);
    });

    testWidgets('cancelar la seleccion no cambia nada', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      await e.abrir(tester);

      await tester.tap(find.text('Galeria'));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.text('Galeria'), findsOneWidget);
    });

    testWidgets('"Quitar foto" vuelve a las opciones y no se sube nada', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      e.selector.respuesta = _png;
      await e.abrir(tester);
      await e.escribirNombre(tester);

      await tester.tap(find.text('Agua'));
      await tester.tap(find.text('Galeria'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quitar foto'));
      await tester.pumpAndSettle();

      expect(find.text('Galeria'), findsOneWidget);

      await e.enviar(tester);

      expect(e.api.eventos, <String>['proponer']);
    });

    testWidgets('con foto: primero crea el nodo y despues sube la foto a su id', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      e.selector.respuesta = _png;
      await e.abrir(tester);
      await e.escribirNombre(tester);

      await tester.tap(find.text('Agua'));
      await tester.tap(find.text('Galeria'));
      await tester.pumpAndSettle();

      await e.enviar(tester);

      expect(
        e.api.eventos,
        <String>['proponer', 'subirFoto:42:${_png.length}'],
      );
      expect(e.api.fotoSubida, _png);
      expect(e.resultado?.conFoto, isTrue);
    });

    testWidgets('si la foto no se sube, el punto igual queda enviado y se avisa', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      e.selector.respuesta = _png;
      e.api.errorAlSubirFoto = StateError('sin red');
      await e.abrir(tester);
      await e.escribirNombre(tester);

      await tester.tap(find.text('Agua'));
      await tester.tap(find.text('Galeria'));
      await tester.pumpAndSettle();

      await e.enviar(tester);

      expect(e.cerrado, isTrue);
      expect(e.resultado?.id, 42);
      expect(
        find.text('El punto se envio, pero no se pudo subir la foto.'),
        findsOneWidget,
      );
    });
  });

  testWidgets(
    'si el servidor rechaza el punto avisa, no sube la foto y deja reintentar',
    (WidgetTester tester) async {
      final _Escenario e = _Escenario();
      e.selector.respuesta = _png;
      e.api.errorAlProponer = StateError('sin red');
      await e.abrir(tester);
      await e.escribirNombre(tester);

      await tester.tap(find.text('Agua'));
      await tester.tap(find.text('Galeria'));
      await tester.pumpAndSettle();

      await e.enviar(tester);

      expect(find.textContaining('No se pudo enviar'), findsOneWidget);
      expect(e.cerrado, isFalse);
      expect(e.api.eventos, isEmpty);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Enviar'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  group('ADM-11 - catalogo dinamico de nodos', () {
    testWidgets('solo muestra categorias activas', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();

      e.catalogosApi.categorias = <CatalogoItem>[
        _categoria('agua', 'Agua', id: 1),
        _categoria('taller', 'Taller', activo: false, id: 2),
        _categoria('mirador', 'Mirador', id: 3),
      ];

      await e.abrir(tester);

      expect(find.text('Agua'), findsOneWidget);
      expect(find.text('Mirador'), findsOneWidget);
      expect(find.text('Taller'), findsNothing);
      expect(e.catalogosApi.consultas, 1);
    });

    testWidgets('muestra una categoria nueva y envia su clave', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();

      e.catalogosApi.categorias = <CatalogoItem>[
        _categoria('zona_picnic', 'Zona de picnic', id: 10),
      ];

      await e.abrir(tester);

      expect(find.text('Zona de picnic'), findsOneWidget);

      await e.escribirNombre(tester);
      await tester.tap(find.text('Zona de picnic'));
      await tester.pump();
      await e.enviar(tester);

      expect(e.api.propuestas.single['categoria'], 'zona_picnic');
      expect(e.api.propuestas.single['categoriaOtro'], isNull);
    });

    testWidgets('no permite enviar mientras carga las categorias', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      e.catalogosApi.pendiente = Completer<List<CatalogoItem>>();

      await e.abrir(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Enviar'),
            )
            .onPressed,
        isNull,
      );
      expect(e.api.propuestas, isEmpty);
    });

    testWidgets('si falla la carga muestra reintentar y bloquea el envio', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      e.catalogosApi.error = StateError('sin conexion');

      await e.abrir(tester);

      expect(
        find.text('No se pudieron cargar las categorías.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Enviar'),
            )
            .onPressed,
        isNull,
      );

      e.catalogosApi.error = null;

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(e.catalogosApi.consultas, 2);
      expect(find.text('Agua'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('sin categorias activas no permite enviar', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      e.catalogosApi.categorias = <CatalogoItem>[];

      await e.abrir(tester);

      expect(
        find.text('No hay categorías disponibles actualmente.'),
        findsOneWidget,
      );

      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Enviar'),
            )
            .onPressed,
        isNull,
      );
      expect(e.api.propuestas, isEmpty);
    });

    testWidgets('no muestra Otro cuando esta desactivado', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();

      e.catalogosApi.categorias = <CatalogoItem>[
        _categoria('agua', 'Agua', id: 1),
        _categoria('otro', 'Otro', activo: false, id: 9),
      ];

      await e.abrir(tester);

      expect(find.text('Agua'), findsOneWidget);
      expect(find.text('Otro'), findsNothing);
      expect(find.text('Que categoria es?'), findsNothing);
    });
  });
}
