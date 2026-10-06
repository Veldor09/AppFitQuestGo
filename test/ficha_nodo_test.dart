import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
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

  /// Votos enviados: (tipo, id, lat, lng).
  final List<({String tipo, int id, double lat, double lng})> votos =
      <({String tipo, int id, double lat, double lng})>[];
  Object? errorAlVotar;

  /// Lo que responde el servidor al votar (por defecto, el mismo nodo con tu voto).
  Nodo Function(Nodo base, String voto)? respuestaAlVotar;
  Nodo? base;

  Future<Nodo> _votar(String voto, int id, double lat, double lng) async {
    votos.add((tipo: voto, id: id, lat: lat, lng: lng));
    if (errorAlVotar != null) throw errorAlVotar!;
    final Nodo n = base!;
    return respuestaAlVotar?.call(n, voto) ??
        Nodo(
          id: n.id,
          nombre: n.nombre,
          categoria: n.categoria,
          lat: n.lat,
          lng: n.lng,
          estado: 'Aprobado',
          creadoPorId: n.creadoPorId,
          miVoto: voto,
          confirmaciones: voto == 'confirmar' ? n.confirmaciones + 1 : n.confirmaciones,
          obsoletos: voto == 'obsoleto' ? n.obsoletos + 1 : n.obsoletos,
        );
  }

  @override
  Future<Nodo> confirmar(int id, {required double lat, required double lng}) =>
      _votar('confirmar', id, lat, lng);

  @override
  Future<Nodo> marcarObsoleto(int id, {required double lat, required double lng}) =>
      _votar('obsoleto', id, lat, lng);

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
            onPressed: () => mostrarFichaNodo(context, nodo, api),
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
        home: Scaffold(body: FichaNodo(nodo: _nodo(conFoto: true), api: api)),
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

  group('votar el punto', () {
    /// A ~56 m al norte del punto (9.93, -84.09).
    const PosicionGps cerca = (lat: 9.9305, lng: -84.09);

    /// A ~1.1 km.
    const PosicionGps lejos = (lat: 9.94, lng: -84.09);

    Future<void> abrirVotando(
      WidgetTester tester,
      Nodo nodo,
      _NodoApiFalsa api, {
      PosicionGps? Function()? posicion,
      int? usuarioId = 42,
      ValueChanged<Nodo>? alVotar,
    }) async {
      api.base = nodo;
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
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => mostrarFichaNodo(
                  context,
                  nodo,
                  api,
                  posicionActual: posicion,
                  usuarioId: usuarioId,
                  alVotar: alVotar,
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

    testWidgets('sin posicion (la cola del admin) no hay seccion de voto', (
      WidgetTester tester,
    ) async {
      await abrirVotando(tester, _nodo(), _NodoApiFalsa(), posicion: null);

      expect(find.text('Sigue existiendo?'), findsNothing);
      expect(find.text('Si, sigue ahi'), findsNothing);
    });

    testWidgets('cerca y sin votar ofrece "Si, sigue ahi" y "Ya no existe"', (
      WidgetTester tester,
    ) async {
      await abrirVotando(tester, _nodo(), _NodoApiFalsa(), posicion: () => cerca);

      expect(find.text('Sigue existiendo?'), findsOneWidget);
      expect(find.widgetWithText(FqButton, 'Si, sigue ahi'), findsOneWidget);
      expect(find.widgetWithText(FqButton, 'Ya no existe'), findsOneWidget);
    });

    testWidgets('lejos dice a cuantos metros estas y no ofrece botones', (
      WidgetTester tester,
    ) async {
      await abrirVotando(tester, _nodo(), _NodoApiFalsa(), posicion: () => lejos);

      expect(
        find.textContaining('Acercate a menos de 150 m para votar este punto'),
        findsOneWidget,
      );
      expect(find.textContaining('estas a 1112 m'), findsOneWidget);
      expect(find.text('Si, sigue ahi'), findsNothing);
    });

    testWidgets('sin GPS pide activar la ubicacion', (WidgetTester tester) async {
      await abrirVotando(tester, _nodo(), _NodoApiFalsa(), posicion: () => null);

      expect(find.text('Activa tu ubicacion para votar este punto.'), findsOneWidget);
      expect(find.text('Si, sigue ahi'), findsNothing);
    });

    testWidgets('quien lo propuso ve una nota, no los botones', (
      WidgetTester tester,
    ) async {
      await abrirVotando(
        tester,
        _nodo(creadoPorId: 42),
        _NodoApiFalsa(),
        posicion: () => cerca,
        usuarioId: 42,
      );

      expect(find.text('Propusiste este punto: lo votan otras personas.'), findsOneWidget);
      expect(find.text('Si, sigue ahi'), findsNothing);
    });

    testWidgets('si ya confirmaste lo dice y no ofrece votar de nuevo', (
      WidgetTester tester,
    ) async {
      await abrirVotando(
        tester,
        _nodo(miVoto: 'confirmar'),
        _NodoApiFalsa(),
        posicion: () => cerca,
      );

      expect(find.text('Ya confirmaste este punto.'), findsOneWidget);
      expect(find.text('Si, sigue ahi'), findsNothing);
    });

    testWidgets('si ya lo marcaste obsoleto tambien lo dice', (
      WidgetTester tester,
    ) async {
      await abrirVotando(
        tester,
        _nodo(miVoto: 'obsoleto'),
        _NodoApiFalsa(),
        posicion: () => cerca,
      );

      expect(find.text('Ya lo marcaste como obsoleto.'), findsOneWidget);
      expect(find.text('Ya no existe'), findsNothing);
    });

    testWidgets('muestra el recuento de votos cuando hay', (WidgetTester tester) async {
      await abrirVotando(
        tester,
        _nodo(confirmaciones: 3, obsoletos: 1),
        _NodoApiFalsa(),
        posicion: () => cerca,
      );

      expect(find.text('Confirmaciones: 3 · Ya no existe: 1'), findsOneWidget);
    });

    testWidgets('sin votos no muestra el recuento', (WidgetTester tester) async {
      await abrirVotando(tester, _nodo(), _NodoApiFalsa(), posicion: () => cerca);

      expect(find.textContaining('Confirmaciones:'), findsNothing);
    });

    testWidgets('"Si, sigue ahi" vota con tu posicion, agradece y avisa del cambio', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa();
      final List<Nodo> cambios = <Nodo>[];
      await abrirVotando(
        tester,
        _nodo(),
        api,
        posicion: () => cerca,
        alVotar: cambios.add,
      );

      await tester.tap(find.widgetWithText(FqButton, 'Si, sigue ahi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.votos, hasLength(1));
      expect(api.votos.single.tipo, 'confirmar');
      expect(api.votos.single.id, 9);
      expect(api.votos.single.lat, cerca.lat);
      expect(api.votos.single.lng, cerca.lng);
      expect(find.text('Gracias, confirmaste que sigue ahi.'), findsOneWidget);
      expect(cambios.single.miVoto, 'confirmar');
      // La ficha sigue abierta y ya refleja tu voto.
      expect(find.text('Ya confirmaste este punto.'), findsOneWidget);
      expect(find.text('Si, sigue ahi'), findsNothing);
    });

    testWidgets('"Ya no existe" vota obsoleto y deja la ficha abierta bajo el umbral', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa();
      await abrirVotando(tester, _nodo(), api, posicion: () => cerca);

      await tester.tap(find.widgetWithText(FqButton, 'Ya no existe'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(api.votos.single.tipo, 'obsoleto');
      expect(find.text('Gracias, avisaste que ya no existe.'), findsOneWidget);
      expect(find.text('Ya lo marcaste como obsoleto.'), findsOneWidget);
      expect(find.text('Fuente del parque'), findsOneWidget);
    });

    testWidgets('si el voto retira el punto del mapa, cierra la ficha', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa()
        ..respuestaAlVotar = (Nodo base, String voto) => Nodo(
          id: base.id,
          nombre: base.nombre,
          categoria: base.categoria,
          lat: base.lat,
          lng: base.lng,
          estado: 'Obsoleto',
          miVoto: voto,
        );
      final List<Nodo> cambios = <Nodo>[];
      await abrirVotando(
        tester,
        _nodo(),
        api,
        posicion: () => cerca,
        alVotar: cambios.add,
      );

      await tester.tap(find.widgetWithText(FqButton, 'Ya no existe'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(cambios.single.estado, 'Obsoleto');
      expect(find.text('Fuente del parque'), findsNothing);
    });

    testWidgets('un 400 dice que estas muy lejos y deja los botones', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa()..errorAlVotar = ApiException(400, 'lejos');
      await abrirVotando(tester, _nodo(), api, posicion: () => cerca);

      await tester.tap(find.widgetWithText(FqButton, 'Si, sigue ahi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Estas muy lejos del punto para votar.'), findsOneWidget);
      expect(find.widgetWithText(FqButton, 'Si, sigue ahi'), findsOneWidget);
    });

    testWidgets('un 403 avisa que no podes votar tu propio punto', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa()..errorAlVotar = ApiException(403, 'propio');
      await abrirVotando(tester, _nodo(), api, posicion: () => cerca);

      await tester.tap(find.widgetWithText(FqButton, 'Si, sigue ahi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No podes votar un punto que propusiste vos.'), findsOneWidget);
    });

    testWidgets('un 409 dice que ya no necesita tu voto y quita los botones', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa()..errorAlVotar = ApiException(409, 'ya votaste');
      await abrirVotando(tester, _nodo(), api, posicion: () => cerca);

      await tester.tap(find.widgetWithText(FqButton, 'Si, sigue ahi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Este punto ya no necesita tu voto.'), findsWidgets);
      expect(find.text('Si, sigue ahi'), findsNothing);
    });

    testWidgets('un error de red deja los botones para reintentar', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa()..errorAlVotar = StateError('sin red');
      await abrirVotando(tester, _nodo(), api, posicion: () => cerca);

      await tester.tap(find.widgetWithText(FqButton, 'Ya no existe'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No se pudo registrar tu voto.'), findsOneWidget);
      expect(find.widgetWithText(FqButton, 'Ya no existe'), findsOneWidget);
    });
  });
}
