import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/voz/aviso_voz.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';
import 'package:fit_quest_go/Modulos/home/presentation/home_usuario_screen.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

const double _lat = 9.9281;
const double _lng = -84.0907;

/// ~56 m al norte de la alerta de prueba.
const PosicionGps _cerca = (lat: _lat + 0.0005, lng: _lng);

/// ~1.1 km al norte.
const PosicionGps _lejos = (lat: _lat + 0.01, lng: _lng);

class _NodoApiFalsa extends NodoApi {
  int cargas = 0;

  @override
  Future<List<Nodo>> listar() async {
    cargas++;
    return <Nodo>[];
  }
}

class _AlertaApiFalsa extends AlertaApi {
  _AlertaApiFalsa(this.alertas);

  List<Alerta> alertas;
  Object? errorAlVotar;
  final List<({String tipo, int id, double lat, double lng})> votos =
      <({String tipo, int id, double lat, double lng})>[];

  @override
  Future<List<Alerta>> listar() async => alertas;

  Alerta _votar(String tipo, int id, double lat, double lng, String estado) {
    votos.add((tipo: tipo, id: id, lat: lat, lng: lng));
    if (errorAlVotar != null) throw errorAlVotar!;
    final Alerta base = alertas.firstWhere((Alerta a) => a.id == id);
    return Alerta(
      id: base.id,
      tipo: base.tipo,
      gravedad: base.gravedad,
      lat: base.lat,
      lng: base.lng,
      estado: estado,
      creadoPorId: base.creadoPorId,
      miVoto: tipo,
    );
  }

  @override
  Future<Alerta> confirmar(int id, {required double lat, required double lng}) async =>
      _votar('confirmar', id, lat, lng, 'Activa');

  @override
  Future<Alerta> desmentir(int id, {required double lat, required double lng}) async =>
      _votar('desmentir', id, lat, lng, 'Resuelta');
}

class _VozFalsa implements AvisoVoz {
  final List<String> dichos = <String>[];
  final List<Locale> idiomas = <Locale>[];

  @override
  Future<void> decir(String texto, {required Locale idioma}) async {
    dichos.add(texto);
    idiomas.add(idioma);
  }

  @override
  Future<void> detener() async {}
}

class _AuthFalso extends AuthRepositorio {
  @override
  UsuarioSesion? get usuario => const UsuarioSesion(
    id: 1,
    nombre: 'Yo',
    email: 'yo@x.co',
    rol: RolUsuario.userNormal,
  );
}

Alerta _alerta({int id = 7, int creadoPorId = 99, String estado = 'Activa'}) {
  return Alerta(
    id: id,
    tipo: 'arbol_caido',
    gravedad: 'alta',
    lat: _lat,
    lng: _lng,
    estado: estado,
    creadoPorId: creadoPorId,
  );
}

class _Escenario {
  _Escenario(List<Alerta> alertas)
    : api = _AlertaApiFalsa(alertas),
      nodoApi = _NodoApiFalsa(),
      voz = _VozFalsa(),
      gps = StreamController<PosicionGps>();

  final _AlertaApiFalsa api;
  final _NodoApiFalsa nodoApi;
  final _VozFalsa voz;
  final StreamController<PosicionGps> gps;

  Widget montar() {
    return AuthScope(
      auth: _AuthFalso(),
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) =>
            NotificacionesHost(child: child!),
        home: Scaffold(
          body: HomeUsuarioScreen(
            nodoApi: nodoApi,
            alertaApi: api,
            voz: voz,
            posiciones: () => gps.stream,
          ),
        ),
      ),
    );
  }

  /// Carga inicial + una posicion del GPS, y deja correr las animaciones.
  Future<void> arrancarEn(WidgetTester tester, PosicionGps pos) async {
    await tester.pumpWidget(montar());
    await tester.pump(); // termina la carga de alertas
    gps.add(pos);
    await tester.pump(); // entrega la posicion
    await tester.pump(const Duration(milliseconds: 300)); // anima el banner
  }
}

void _forzarEspanol(WidgetTester tester) {
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  tester.platformDispatcher.localeTestValue = const Locale('es');
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
}

void main() {
  late _Escenario e;

  Future<void> montarConAlertas(
    WidgetTester tester,
    List<Alerta> alertas, {
    PosicionGps en = _cerca,
  }) async {
    _forzarEspanol(tester);
    e = _Escenario(alertas);
    addTearDown(e.gps.close);
    await e.arrancarEn(tester, en);
  }

  testWidgets('al acercarte a una alerta la anuncia por voz y muestra el banner', (
    WidgetTester tester,
  ) async {
    await montarConAlertas(tester, <Alerta>[_alerta()]);

    expect(find.text('Alerta cerca de ti'), findsOneWidget);
    expect(find.text('Sigue ahi?'), findsOneWidget);
    expect(e.voz.dichos, hasLength(1));
    expect(e.voz.dichos.single, contains('Arbol caido'));
    expect(e.voz.dichos.single, contains('56 metros'));
    expect(e.voz.idiomas.single, const Locale('es'));
  });

  testWidgets('lejos de la alerta no hay aviso ni voz', (WidgetTester tester) async {
    await montarConAlertas(tester, <Alerta>[_alerta()], en: _lejos);

    expect(find.text('Alerta cerca de ti'), findsNothing);
    expect(e.voz.dichos, isEmpty);
  });

  testWidgets('no avisa de una alerta que reportaste vos', (WidgetTester tester) async {
    await montarConAlertas(tester, <Alerta>[_alerta(creadoPorId: 1)]);

    expect(find.text('Alerta cerca de ti'), findsNothing);
    expect(e.voz.dichos, isEmpty);
  });

  testWidgets('"Si, sigue ahi" confirma con tu posicion y cierra el banner', (
    WidgetTester tester,
  ) async {
    await montarConAlertas(tester, <Alerta>[_alerta()]);

    await tester.tap(find.text('Si, sigue ahi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(e.api.votos, hasLength(1));
    expect(e.api.votos.single.tipo, 'confirmar');
    expect(e.api.votos.single.id, 7);
    expect(e.api.votos.single.lat, _cerca.lat);
    expect(e.api.votos.single.lng, _cerca.lng);
    expect(find.text('Alerta cerca de ti'), findsNothing);
    expect(find.text('Gracias, confirmaste que sigue ahi.'), findsOneWidget);
  });

  testWidgets('"Ya no esta" desmiente y cierra el banner', (WidgetTester tester) async {
    await montarConAlertas(tester, <Alerta>[_alerta()]);

    await tester.tap(find.text('Ya no esta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(e.api.votos.single.tipo, 'desmentir');
    expect(find.text('Alerta cerca de ti'), findsNothing);
    expect(find.text('Gracias, avisaste que ya no esta.'), findsOneWidget);
  });

  testWidgets('un 409 dice que ya no necesita tu voto y cierra el banner', (
    WidgetTester tester,
  ) async {
    await montarConAlertas(tester, <Alerta>[_alerta()]);
    e.api.errorAlVotar = ApiException(409, 'Ya votaste esta alerta');

    await tester.tap(find.text('Si, sigue ahi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Esta alerta ya no necesita tu voto.'), findsOneWidget);
    expect(find.text('Alerta cerca de ti'), findsNothing);
  });

  testWidgets('un 400 dice que estas muy lejos y cierra el banner', (
    WidgetTester tester,
  ) async {
    await montarConAlertas(tester, <Alerta>[_alerta()]);
    e.api.errorAlVotar = ApiException(400, 'Estas a 1112 m de la alerta');

    await tester.tap(find.text('Si, sigue ahi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Estas muy lejos de la alerta para votar.'), findsOneWidget);
    expect(find.text('Alerta cerca de ti'), findsNothing);
  });

  testWidgets('un error de red deja el banner para reintentar', (
    WidgetTester tester,
  ) async {
    await montarConAlertas(tester, <Alerta>[_alerta()]);
    e.api.errorAlVotar = StateError('sin red');

    await tester.tap(find.text('Si, sigue ahi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('No se pudo registrar tu voto.'), findsOneWidget);
    expect(find.text('Alerta cerca de ti'), findsOneWidget);
  });

  testWidgets('recarga las alertas cada minuto y avisa de una nueva', (
    WidgetTester tester,
  ) async {
    await montarConAlertas(tester, <Alerta>[]);
    expect(find.text('Alerta cerca de ti'), findsNothing);

    // Otra persona la reporta mientras caminas.
    e.api.alertas = <Alerta>[_alerta()];
    await tester.pump(const Duration(seconds: 61));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Alerta cerca de ti'), findsOneWidget);
    expect(e.voz.dichos, hasLength(1));
  });

  testWidgets('vuelve a pedir los puntos de interes cada minuto', (
    WidgetTester tester,
  ) async {
    await montarConAlertas(tester, <Alerta>[], en: _lejos);
    expect(e.nodoApi.cargas, 1);

    // Otra persona pudo votar un punto como obsoleto mientras caminas.
    await tester.pump(const Duration(seconds: 61));
    await tester.pump();

    expect(e.nodoApi.cargas, 2);
  });

  testWidgets('la X cierra el banner sin votar y no se vuelve a avisar', (
    WidgetTester tester,
  ) async {
    await montarConAlertas(tester, <Alerta>[_alerta()]);

    await tester.tap(find.byTooltip('Ahora no'));
    await tester.pump();
    e.gps.add((lat: _cerca.lat + 0.00001, lng: _cerca.lng));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(e.api.votos, isEmpty);
    expect(find.text('Alerta cerca de ti'), findsNothing);
    expect(e.voz.dichos, hasLength(1));
  });
}
