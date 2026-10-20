import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/home/presentation/home_usuario_screen.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

import 'helpers/datos_mapa.dart';
import 'helpers/home_falsos.dart';

const PosicionGps _aqui = (lat: latBase, lng: lngBase);

/// Responde, en cada carga, la siguiente lista de [respuestas] (la ultima se repite).
class _NodoApiFalsa extends NodoApi {
  _NodoApiFalsa(this.respuestas);

  final List<List<Nodo>> respuestas;
  int cargas = 0;

  @override
  Future<List<Nodo>> listar() async {
    final int i = cargas < respuestas.length ? cargas : respuestas.length - 1;
    cargas++;
    return respuestas[i];
  }
}

class _EventoApiFalsa extends EventoApi {
  _EventoApiFalsa(this.respuestas);

  final List<List<Evento>> respuestas;
  int cargas = 0;

  @override
  Future<List<Evento>> listar() async {
    final int i = cargas < respuestas.length ? cargas : respuestas.length - 1;
    cargas++;
    return respuestas[i];
  }
}

class _ClimaApiFalsa extends ClimaApi {
  @override
  Future<RespuestaClima> alertas({
    required double lat,
    required double lng,
  }) async => const RespuestaClima(alertas: <AlertaClima>[], fuente: '');
}

class _AlertaApiFalsa extends AlertaApi {
  _AlertaApiFalsa(this.alertas);

  final List<Alerta> alertas;

  @override
  Future<List<Alerta>> listar() async => alertas;
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

// A ~334 m al norte de quien esta en (latBase, lngBase).
Nodo _destacado({bool destacado = true}) => nodoDePrueba(
  id: 5,
  nombre: 'Soda Norte',
  categoria: 'comercio',
  lat: latBase + 0.003,
  destacado: destacado,
);

Future<StreamController<PosicionGps>> _montar(
  WidgetTester tester, {
  required List<List<Nodo>> nodos,
  List<List<Evento>> eventos = const <List<Evento>>[<Evento>[]],
  List<Alerta> alertas = const <Alerta>[],
}) async {
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  tester.platformDispatcher.localeTestValue = const Locale('es');
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  final StreamController<PosicionGps> gps = StreamController<PosicionGps>();
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
            nodoApi: _NodoApiFalsa(nodos),
            alertaApi: _AlertaApiFalsa(alertas),
            climaApi: _ClimaApiFalsa(),
            eventoApi: _EventoApiFalsa(eventos),
            rutaApi: RutaApiVacia(),
            notificacionesApi: NotificacionesApiVacia(),
            voz: _VozFalsa(),
            posiciones: () => gps.stream,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  gps.add(_aqui);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return gps;
}

void main() {
  const ValueKey<String> tarjeta = ValueKey<String>('cerca-destacado');

  testWidgets('al pasar cerca de un destacado avisa y lo muestra en "Cerca de ti"', (
    WidgetTester tester,
  ) async {
    await _montar(tester, nodos: <List<Nodo>>[<Nodo>[_destacado()]]);

    expect(find.text('Destacado cerca de ti'), findsOneWidget);
    expect(find.text('Soda Norte · 334 m'), findsOneWidget);
    expect(find.byKey(tarjeta), findsOneWidget);
  });

  testWidgets('"Ahora no" cierra el aviso, pero la tarjeta del cuadro sigue', (
    WidgetTester tester,
  ) async {
    await _montar(tester, nodos: <List<Nodo>>[<Nodo>[_destacado()]]);

    await tester.tap(find.byTooltip('Ahora no'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Destacado cerca de ti'), findsNothing);
    expect(find.byKey(tarjeta), findsOneWidget);
  });

  testWidgets('un punto que no esta destacado no avisa ni sale en el cuadro', (
    WidgetTester tester,
  ) async {
    await _montar(
      tester,
      nodos: <List<Nodo>>[<Nodo>[_destacado(destacado: false)]],
    );

    expect(find.text('Destacado cerca de ti'), findsNothing);
    expect(find.byKey(tarjeta), findsNothing);
  });

  testWidgets('una alerta de peligro cerca tapa el aviso del destacado', (
    WidgetTester tester,
  ) async {
    // Review Focus 4: el destacado nunca tapa una alerta.
    await _montar(
      tester,
      nodos: <List<Nodo>>[<Nodo>[_destacado()]],
      alertas: <Alerta>[
        alertaDePrueba(id: 7, tipo: 'arbol_caido', gravedad: 'alta', creadoPorId: 99),
      ],
    );

    expect(find.text('Alerta cerca de ti'), findsOneWidget);
    expect(find.text('Destacado cerca de ti'), findsNothing);
  });

  testWidgets('el refresco del mapa recoge un cambio de `destacado` sin reiniciar la app', (
    WidgetTester tester,
  ) async {
    // Review Focus 3: sin comparar `destacado`, un plan vencido seguiria dorado.
    await _montar(
      tester,
      nodos: <List<Nodo>>[
        <Nodo>[_destacado(destacado: false)],
        <Nodo>[_destacado()],
        <Nodo>[_destacado(destacado: false)],
      ],
    );
    expect(find.byKey(tarjeta), findsNothing);

    await tester.pump(const Duration(seconds: 61));
    await tester.pump();
    expect(find.byKey(tarjeta), findsOneWidget);

    await tester.pump(const Duration(seconds: 61));
    await tester.pump();
    expect(find.byKey(tarjeta), findsNothing);
  });

  testWidgets('un evento destacado cerca tambien sale en el cuadro', (
    WidgetTester tester,
  ) async {
    await _montar(
      tester,
      nodos: <List<Nodo>>[<Nodo>[]],
      eventos: <List<Evento>>[
        <Evento>[
          eventoDePrueba(
            id: 9,
            nombre: 'Maraton',
            destacado: true,
            recorridos: const <ZonaEvento>[
              ZonaEvento(
                nombre: 'R',
                puntos: <PuntoGeo>[
                  PuntoGeo(lat: latBase + 0.002, lng: lngBase),
                  PuntoGeo(lat: latBase + 0.05, lng: lngBase),
                ],
              ),
            ],
          ),
        ],
      ],
    );

    expect(find.text('Maraton'), findsWidgets);
    expect(find.byKey(tarjeta), findsOneWidget);
  });
}
