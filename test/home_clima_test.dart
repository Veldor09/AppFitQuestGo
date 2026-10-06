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
import 'package:fit_quest_go/Modulos/clima/data/alerta_clima.dart';
import 'package:fit_quest_go/Modulos/clima/data/clima_api.dart';
import 'package:fit_quest_go/Modulos/home/presentation/home_usuario_screen.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

const PosicionGps _aqui = (lat: 9.9281, lng: -84.0907);

class _NodoApiFalsa extends NodoApi {
  @override
  Future<List<Nodo>> listar() async => <Nodo>[];
}

class _AlertaApiFalsa extends AlertaApi {
  @override
  Future<List<Alerta>> listar() async => <Alerta>[];
}

class _ClimaApiFalsa extends ClimaApi {
  final List<({double lat, double lng})> consultas = <({double lat, double lng})>[];
  List<AlertaClima> respuesta = <AlertaClima>[];
  Object? error;

  @override
  Future<RespuestaClima> alertas({required double lat, required double lng}) async {
    consultas.add((lat: lat, lng: lng));
    if (error != null) throw error!;
    return RespuestaClima(alertas: respuesta, fuente: 'Open-Meteo');
  }
}

class _VozFalsa implements AvisoVoz {
  @override
  Future<void> decir(String texto, {required Locale idioma}) async {}

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

const AlertaClima _calor = AlertaClima(
  tipo: TipoClima.calor,
  nivel: NivelClima.peligro,
  enHoras: 0,
  valor: 41.5,
);
const AlertaClima _lluvia = AlertaClima(
  tipo: TipoClima.lluvia,
  nivel: NivelClima.precaucion,
  enHoras: 1,
  valor: 12,
);

void _forzarEspanol(WidgetTester tester) {
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  tester.platformDispatcher.localeTestValue = const Locale('es');
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
}

void main() {
  late _ClimaApiFalsa clima;
  late StreamController<PosicionGps> gps;

  /// Monta Home y deja pasar la carga inicial. El GPS aun no entrego nada.
  Future<void> montar(WidgetTester tester) async {
    _forzarEspanol(tester);
    clima = _ClimaApiFalsa();
    gps = StreamController<PosicionGps>();
    addTearDown(gps.close);
    await tester.pumpWidget(
      AuthScope(
        auth: _AuthFalso(),
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (BuildContext context, Widget? child) =>
              NotificacionesHost(child: child!),
          home: Scaffold(
            body: HomeUsuarioScreen(
              nodoApi: _NodoApiFalsa(),
              alertaApi: _AlertaApiFalsa(),
              climaApi: clima,
              voz: _VozFalsa(),
              posiciones: () => gps.stream,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Entrega una posicion del GPS y deja terminar la consulta del clima.
  Future<void> mover(WidgetTester tester, PosicionGps pos) async {
    gps.add(pos);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('sin posicion del GPS no consulta el clima ni muestra nada', (
    WidgetTester tester,
  ) async {
    await montar(tester);
    clima.respuesta = <AlertaClima>[_calor];

    await tester.pump(const Duration(seconds: 5));

    expect(clima.consultas, isEmpty);
    expect(find.text('Calor extremo en tu zona'), findsNothing);
  });

  testWidgets('con la primera posicion consulta el clima de esa zona y muestra el aviso', (
    WidgetTester tester,
  ) async {
    await montar(tester);
    clima.respuesta = <AlertaClima>[_calor];

    await mover(tester, _aqui);

    expect(clima.consultas, <({double lat, double lng})>[(lat: _aqui.lat, lng: _aqui.lng)]);
    expect(find.text('Calor extremo en tu zona'), findsOneWidget);
    expect(find.text('Datos: Open-Meteo'), findsOneWidget);
  });

  testWidgets('solo consulta con la primera posicion, no con cada movimiento', (
    WidgetTester tester,
  ) async {
    await montar(tester);

    await mover(tester, _aqui);
    await mover(tester, (lat: _aqui.lat + 0.001, lng: _aqui.lng));
    await mover(tester, (lat: _aqui.lat + 0.002, lng: _aqui.lng));

    expect(clima.consultas, hasLength(1));
  });

  testWidgets('sin mal tiempo no muestra ningun aviso', (WidgetTester tester) async {
    await montar(tester);

    await mover(tester, _aqui);

    expect(clima.consultas, hasLength(1));
    expect(find.textContaining('en tu zona'), findsNothing);
  });

  testWidgets('la X cierra el aviso y deja ver el siguiente', (WidgetTester tester) async {
    await montar(tester);
    clima.respuesta = <AlertaClima>[_calor, _lluvia];
    await mover(tester, _aqui);
    expect(find.text('Calor extremo en tu zona'), findsOneWidget);
    expect(find.text('+1 mas'), findsOneWidget);

    await tester.tap(find.byTooltip('Ahora no'));
    await tester.pump();

    expect(find.text('Calor extremo en tu zona'), findsNothing);
    expect(find.text('Lluvia fuerte en tu zona'), findsOneWidget);
  });

  testWidgets('vuelve a consultar cada 15 minutos y no repite un aviso cerrado', (
    WidgetTester tester,
  ) async {
    await montar(tester);
    clima.respuesta = <AlertaClima>[_calor];
    await mover(tester, _aqui);
    await tester.tap(find.byTooltip('Ahora no'));
    await tester.pump();

    await tester.pump(const Duration(minutes: 15));
    await tester.pump();

    expect(clima.consultas, hasLength(2));
    expect(find.text('Calor extremo en tu zona'), findsNothing);
  });

  testWidgets('si el clima falla no muestra error y el mapa sigue en pie', (
    WidgetTester tester,
  ) async {
    await montar(tester);
    clima.error = ApiException(503, 'no disponible');

    await mover(tester, _aqui);

    expect(find.textContaining('en tu zona'), findsNothing);
    expect(find.text('Cerca de ti'), findsOneWidget);
  });
}
