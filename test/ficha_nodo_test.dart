import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'helpers/calificacion_falsa.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/ficha_nodo.dart';

/// PNG valido de 1x1 px.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _NodoApiFalsa extends NodoApi {
  final List<int> fotosPedidas = <int>[];
  Completer<Uint8List>? pendiente;
  Object? error;

  @override
  Future<Uint8List> foto(int id) {
    fotosPedidas.add(id);
    if (pendiente != null) return pendiente!.future;
    if (error != null) return Future<Uint8List>.error(error!);
    return Future<Uint8List>.value(_png);
  }
}

Nodo _nodo({
  String categoria = 'agua',
  String? categoriaOtro,
  String? descripcion = 'Agua potable todo el dia',
  bool conFoto = false,
  String? creadoPorNombre = 'Ana',
  int? creadoPorId = 3,
  String? miVoto,
  int confirmaciones = 0,
  int obsoletos = 0,
  String estado = 'Aprobado',
}) {
  return Nodo(
    id: 9,
    nombre: 'Fuente del parque',
    categoria: categoria,
    categoriaOtro: categoriaOtro,
    lat: 9.93,
    lng: -84.09,
    estado: estado,
    descripcion: descripcion,
    creadoPorNombre: creadoPorNombre,
    conFoto: conFoto,
    creadoPorId: creadoPorId,
    miVoto: miVoto,
    confirmaciones: confirmaciones,
    obsoletos: obsoletos,
  );
}

Future<void> _abrir(WidgetTester tester, Nodo nodo, NodoApi api) async {
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
        body: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => mostrarFichaNodo(
              context,
              nodo,
              api,
              calificaciones: CalificacionApiFalsa(),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra nombre, categoria traducida, quien lo propuso y la descripcion', (
    WidgetTester tester,
  ) async {
    await _abrir(tester, _nodo(), _NodoApiFalsa());

    expect(find.text('Fuente del parque'), findsOneWidget);
    expect(find.text('Agua · propuesto por Ana'), findsOneWidget);
    expect(find.text('Agua potable todo el dia'), findsOneWidget);
  });

  testWidgets('con categoria "otro" muestra lo que escribio quien lo propuso', (
    WidgetTester tester,
  ) async {
    await _abrir(
      tester,
      _nodo(categoria: 'otro', categoriaOtro: 'Zona de picnic'),
      _NodoApiFalsa(),
    );

    expect(find.text('Zona de picnic · propuesto por Ana'), findsOneWidget);
  });

  testWidgets('sin autor ni descripcion solo muestra lo que hay', (
    WidgetTester tester,
  ) async {
    await _abrir(
      tester,
      _nodo(creadoPorNombre: null, descripcion: null),
      _NodoApiFalsa(),
    );

    expect(find.text('Agua'), findsOneWidget);
    expect(find.textContaining('propuesto por'), findsNothing);
  });

  testWidgets('sin foto no pide ninguna ni muestra imagen', (WidgetTester tester) async {
    final _NodoApiFalsa api = _NodoApiFalsa();
    await _abrir(tester, _nodo(conFoto: false), api);

    expect(api.fotosPedidas, isEmpty);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('con foto la pide por el id del nodo y la muestra', (
    WidgetTester tester,
  ) async {
    final _NodoApiFalsa api = _NodoApiFalsa();
    await _abrir(tester, _nodo(conFoto: true), api);

    expect(api.fotosPedidas, <int>[9]);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('mientras baja la foto muestra un indicador de carga', (
    WidgetTester tester,
  ) async {
    final _NodoApiFalsa api = _NodoApiFalsa()..pendiente = Completer<Uint8List>();
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
          body: FichaNodo(
            nodo: _nodo(conFoto: true),
            api: api,
            calificaciones: CalificacionApiFalsa(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    api.pendiente!.complete(_png);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('si la foto no se puede cargar lo dice, sin romper la ficha', (
    WidgetTester tester,
  ) async {
    final _NodoApiFalsa api = _NodoApiFalsa()..error = ApiException(404, 'sin foto');
    await _abrir(tester, _nodo(conFoto: true), api);

    expect(find.text('No se pudo cargar la foto'), findsOneWidget);
    expect(find.text('Fuente del parque'), findsOneWidget);
  });

  group('los puntos ya no se votan (eso es solo de las alertas)', () {
    Future<void> abrir(
      WidgetTester tester, {
      PosicionGps? posicion,
      int? usuarioId,
      Nodo? nodo,
    }) async {
      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
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
            body: FichaNodo(
              nodo: nodo ?? _nodo(),
              api: _NodoApiFalsa(),
              posicionActual: () => posicion,
              usuarioId: usuarioId,
              calificaciones: CalificacionApiFalsa(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('cerca del punto no ofrece "sigue ahi" ni "ya no existe"', (
      WidgetTester tester,
    ) async {
      await abrir(tester, posicion: (lat: 9.93, lng: -84.09));

      expect(find.text('Sigue existiendo?'), findsNothing);
      expect(find.text('Si, sigue ahi'), findsNothing);
      expect(find.text('Ya no existe'), findsNothing);
    });

    testWidgets('no muestra el recuento de confirmaciones ni de bajas', (
      WidgetTester tester,
    ) async {
      await abrir(
        tester,
        nodo: _nodo(confirmaciones: 3, obsoletos: 1),
        posicion: (lat: 9.93, lng: -84.09),
      );

      expect(find.textContaining('Confirmaciones:'), findsNothing);
    });

    testWidgets('en cambio si deja calificarlo con pulgares', (
      WidgetTester tester,
    ) async {
      await abrir(tester, posicion: (lat: 9.93, lng: -84.09), usuarioId: 99);

      expect(find.text('¿Qué te pareció?'), findsOneWidget);
    });
  });
}
