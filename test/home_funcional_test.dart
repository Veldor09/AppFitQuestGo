import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/voz/aviso_voz.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';
import 'package:fit_quest_go/Modulos/alertas/presentation/ficha_alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/presentation/formulario_alerta.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';
import 'package:fit_quest_go/Modulos/clima/data/alerta_clima.dart';
import 'package:fit_quest_go/Modulos/clima/data/clima_api.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/ficha_evento.dart';
import 'package:fit_quest_go/Modulos/home/presentation/home_usuario_screen.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/campana_notificaciones.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/resultados_busqueda.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/ficha_nodo.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificacion.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificaciones_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/ruta_detalle_screen.dart';

import 'helpers/datos_mapa.dart';

const PosicionGps _aqui = (lat: latBase, lng: lngBase);

class _NodoApiFalsa extends NodoApi {
  _NodoApiFalsa(this.nodos);
  final List<Nodo> nodos;

  @override
  Future<List<Nodo>> listar() async => nodos;
}

class _AlertaApiFalsa extends AlertaApi {
  _AlertaApiFalsa(this.alertas);
  final List<Alerta> alertas;

  @override
  Future<List<Alerta>> listar() async => alertas;
}

class _EventoApiFalsa extends EventoApi {
  _EventoApiFalsa(this.eventos);
  final List<Evento> eventos;
  int cargas = 0;

  @override
  Future<List<Evento>> listar() async {
    cargas++;
    return eventos;
  }
}

class _RutaApiFalsa extends RutaApi {
  _RutaApiFalsa(this.rutas);
  List<Ruta> rutas;
  int cargas = 0;

  @override
  Future<List<Ruta>> explorar() async {
    cargas++;
    return rutas;
  }

  @override
  Future<Set<int>> favoritasIds() async => <int>{};
}

class _NotificacionesApiFalsa extends NotificacionesApi {
  int noLeidas = 0;
  int consultas = 0;

  @override
  Future<int> conteoNoLeidas() async {
    consultas++;
    return noLeidas;
  }

  @override
  Future<List<Notificacion>> listar() async => <Notificacion>[];
}

class _ClimaApiFalsa extends ClimaApi {
  @override
  Future<RespuestaClima> alertas({
    required double lat,
    required double lng,
  }) async => const RespuestaClima(alertas: <AlertaClima>[], fuente: '');
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

class _Escenario {
  _Escenario({
    List<Nodo> nodos = const <Nodo>[],
    List<Ruta> rutas = const <Ruta>[],
    List<Alerta> alertas = const <Alerta>[],
    List<Evento> eventos = const <Evento>[],
    int noLeidas = 0,
  }) : nodoApi = _NodoApiFalsa(nodos),
       rutaApi = _RutaApiFalsa(rutas),
       alertaApi = _AlertaApiFalsa(alertas),
       eventoApi = _EventoApiFalsa(eventos),
       notificacionesApi = _NotificacionesApiFalsa()..noLeidas = noLeidas,
       gps = StreamController<PosicionGps>();

  final _NodoApiFalsa nodoApi;
  final _RutaApiFalsa rutaApi;
  final _AlertaApiFalsa alertaApi;
  final _EventoApiFalsa eventoApi;
  final _NotificacionesApiFalsa notificacionesApi;
  final StreamController<PosicionGps> gps;

  Widget app() {
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
            rutaApi: rutaApi,
            alertaApi: alertaApi,
            eventoApi: eventoApi,
            notificacionesApi: notificacionesApi,
            climaApi: _ClimaApiFalsa(),
            voz: _VozFalsa(),
            posiciones: () => gps.stream,
          ),
        ),
      ),
    );
  }
}

/// Monta Home con [e] y deja pasar la carga inicial de todo.
Future<void> _montar(WidgetTester tester, _Escenario e) async {
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  tester.platformDispatcher.localeTestValue = const Locale('es');
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  addTearDown(e.gps.close);
  await tester.pumpWidget(e.app());
  await tester.pump();
  await tester.pump();
}

/// Entrega una posicion del GPS y deja que Home la procese.
Future<void> _mover(WidgetTester tester, _Escenario e, PosicionGps pos) async {
  e.gps.add(pos);
  await tester.pump();
  await tester.pump();
}

Future<void> _escribir(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.pump();
}

const ValueKey<String> _contador = ValueKey<String>('campana-contador');

void main() {
  group('filtros', () {
    testWidgets('empieza en Todo y tocar un filtro lo selecciona', (WidgetTester tester) async {
      final SemanticsHandle semantica = tester.ensureSemantics();
      await _montar(tester, _Escenario());

      Matcher seleccionado(bool si) => isSemantics(isSelected: si);
      expect(tester.getSemantics(find.byKey(const ValueKey<String>('filtro-todo'))), seleccionado(true));

      await tester.tap(find.text('Rutas'));
      await tester.pump();

      expect(tester.getSemantics(find.byKey(const ValueKey<String>('filtro-rutas'))), seleccionado(true));
      expect(tester.getSemantics(find.byKey(const ValueKey<String>('filtro-todo'))), seleccionado(false));
      semantica.dispose();
    });

    testWidgets('tocar otra vez el filtro activo vuelve a Todo', (WidgetTester tester) async {
      final SemanticsHandle semantica = tester.ensureSemantics();
      await _montar(tester, _Escenario());

      await tester.tap(find.text('Alertas'));
      await tester.pump();
      await tester.tap(find.text('Alertas'));
      await tester.pump();

      expect(
        tester.getSemantics(find.byKey(const ValueKey<String>('filtro-todo'))),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey<String>('filtro-alertas'))),
        isSemantics(isSelected: false),
      );
      semantica.dispose();
    });
  });

  group('campana de notificaciones', () {
    testWidgets('sin notificaciones sin leer no lleva contador', (WidgetTester tester) async {
      await _montar(tester, _Escenario());

      expect(find.byKey(_contador), findsNothing);
    });

    testWidgets('con notificaciones sin leer muestra cuantas son', (WidgetTester tester) async {
      await _montar(tester, _Escenario(noLeidas: 3));

      expect(find.descendant(of: find.byKey(_contador), matching: find.text('3')), findsOneWidget);
    });

    testWidgets('tocarla abre el centro de notificaciones y al volver vuelve a contar', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario(noLeidas: 3);
      await _montar(tester, e);
      final int antes = e.notificacionesApi.consultas;

      // Mientras las lees, ya no queda ninguna sin leer.
      e.notificacionesApi.noLeidas = 0;
      await tester.tap(find.byType(CampanaNotificaciones));
      await tester.pumpAndSettle();
      expect(find.text('Centro de notificaciones'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(e.notificacionesApi.consultas, greaterThan(antes));
      expect(find.byKey(_contador), findsNothing);
    });

    testWidgets('cada minuto vuelve a preguntar si hay notificaciones nuevas', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      await _montar(tester, e);
      expect(find.byKey(_contador), findsNothing);

      e.notificacionesApi.noLeidas = 2;
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();

      expect(find.descendant(of: find.byKey(_contador), matching: find.text('2')), findsOneWidget);
    });
  });

  group('buscador', () {
    final Nodo fuente = nodoDePrueba(id: 1, nombre: 'Fuente del parque', lat: latBase + 0.001);
    final Ruta sendero = rutaDePrueba(id: 2, nombre: 'Sendero del parque');
    final Alerta bache = alertaDePrueba(id: 3, tipo: 'bache', descripcion: 'Cerca del parque');
    final Evento carrera = eventoDePrueba(id: 4, nombre: 'Carrera del parque');

    _Escenario completo() => _Escenario(
      nodos: <Nodo>[fuente],
      rutas: <Ruta>[sendero],
      alertas: <Alerta>[bache],
      eventos: <Evento>[carrera],
    );

    testWidgets('sin escribir no muestra resultados', (WidgetTester tester) async {
      await _montar(tester, completo());

      expect(find.byType(ResultadosBusqueda), findsNothing);
    });

    testWidgets('al escribir lista lo que coincide entre lo cargado', (WidgetTester tester) async {
      final _Escenario e = completo();
      await _montar(tester, e);
      await _mover(tester, e, _aqui);

      await _escribir(tester, 'parque');

      expect(find.byType(ResultadosBusqueda), findsOneWidget);
      expect(find.text('Fuente del parque'), findsOneWidget);
      expect(find.text('Sendero del parque'), findsOneWidget);
      expect(find.text('Bache'), findsOneWidget);
      expect(find.text('Carrera del parque'), findsOneWidget);
    });

    testWidgets('si nada coincide lo dice', (WidgetTester tester) async {
      await _montar(tester, completo());

      await _escribir(tester, 'zzzz');

      expect(find.text('Sin resultados para "zzzz"'), findsOneWidget);
    });

    testWidgets('el filtro activo limita donde busca', (WidgetTester tester) async {
      await _montar(tester, completo());
      await tester.tap(find.text('Alertas'));
      await tester.pump();

      await _escribir(tester, 'parque');

      expect(find.text('Bache'), findsOneWidget);
      expect(find.text('Fuente del parque'), findsNothing);
      expect(find.text('Sendero del parque'), findsNothing);
    });

    testWidgets('con GPS cada resultado dice a cuantos metros esta', (WidgetTester tester) async {
      final _Escenario e = completo();
      await _montar(tester, e);
      await _mover(tester, e, _aqui);

      await _escribir(tester, 'fuente');

      expect(find.text('111 m'), findsOneWidget);
    });

    testWidgets('elegir un punto de interes abre su ficha y cierra la lista', (WidgetTester tester) async {
      await _montar(tester, completo());
      await _escribir(tester, 'fuente');

      await tester.tap(find.text('Fuente del parque'));
      await tester.pumpAndSettle();

      expect(find.byType(FichaNodo), findsOneWidget);
      expect(find.byType(ResultadosBusqueda), findsNothing);
    });

    testWidgets('elegir una ruta abre su detalle', (WidgetTester tester) async {
      await _montar(tester, completo());
      await _escribir(tester, 'sendero');

      await tester.tap(find.text('Sendero del parque'));
      await tester.pumpAndSettle();

      expect(find.byType(RutaDetalleScreen), findsOneWidget);
    });

    testWidgets('elegir una alerta abre su ficha', (WidgetTester tester) async {
      await _montar(tester, completo());
      await _escribir(tester, 'bache');

      await tester.tap(find.text('Bache'));
      await tester.pumpAndSettle();

      expect(find.byType(FichaAlerta), findsOneWidget);
    });

    testWidgets('elegir un evento abre su ficha', (WidgetTester tester) async {
      await _montar(tester, completo());
      await _escribir(tester, 'carrera');

      await tester.tap(find.text('Carrera del parque'));
      await tester.pumpAndSettle();

      expect(find.byType(FichaEvento), findsOneWidget);
    });

    testWidgets('el boton X borra lo escrito y cierra la lista', (WidgetTester tester) async {
      await _montar(tester, completo());
      await _escribir(tester, 'fuente');

      await tester.tap(find.byTooltip('Borrar busqueda'));
      await tester.pump();

      expect(find.byType(ResultadosBusqueda), findsNothing);
      expect(find.text('Buscar lugar, ruta o evento'), findsOneWidget);
    });

    testWidgets('mientras se escribe se esconde el cuadro Cerca de ti', (WidgetTester tester) async {
      await _montar(tester, completo());
      expect(find.text('Cerca de ti'), findsOneWidget);

      await _escribir(tester, 'fuente');
      expect(find.text('Cerca de ti'), findsNothing);

      await tester.tap(find.byTooltip('Borrar busqueda'));
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.text('Cerca de ti'), findsOneWidget);
    });
  });

  group('cuadro Cerca de ti', () {
    // Una ruta que pasa a ~222 m al norte y una alerta a ~333 m.
    final Ruta ruta = rutaDePrueba(
      id: 2,
      nombre: 'Sendero del Rio',
      puntos: const <PuntoRuta>[
        PuntoRuta(lat: latBase + 0.002, lng: lngBase),
        PuntoRuta(lat: latBase + 0.01, lng: lngBase),
      ],
    );
    final Alerta alerta = alertaDePrueba(id: 3, tipo: 'bache', lat: latBase + 0.003);

    testWidgets('mientras no hay GPS dice que busca la ubicacion', (WidgetTester tester) async {
      await _montar(tester, _Escenario(rutas: <Ruta>[ruta], alertas: <Alerta>[alerta]));

      expect(find.text('Buscando tu ubicacion...'), findsNWidgets(2));
      expect(find.text('Sendero del Rio'), findsNothing);
    });

    testWidgets('con GPS muestra la ruta y la alerta mas cercanas con su distancia', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario(rutas: <Ruta>[ruta], alertas: <Alerta>[alerta]);
      await _montar(tester, e);

      await _mover(tester, e, _aqui);

      expect(find.text('Sendero del Rio'), findsOneWidget);
      expect(find.text('222 m'), findsOneWidget);
      expect(find.text('Bache'), findsOneWidget);
      expect(find.text('334 m'), findsOneWidget);
    });

    testWidgets('las distancias se actualizan cuando te mueves', (WidgetTester tester) async {
      final _Escenario e = _Escenario(rutas: <Ruta>[ruta], alertas: <Alerta>[alerta]);
      await _montar(tester, e);
      await _mover(tester, e, _aqui);

      await _mover(tester, e, (lat: latBase + 0.001, lng: lngBase));

      expect(find.text('111 m'), findsOneWidget);
      expect(find.text('222 m'), findsOneWidget);
    });

    testWidgets('sin nada cerca lo dice', (WidgetTester tester) async {
      final _Escenario e = _Escenario(
        rutas: <Ruta>[rutaDePrueba(puntos: const <PuntoRuta>[
          PuntoRuta(lat: latBase + 1, lng: lngBase),
          PuntoRuta(lat: latBase + 1.01, lng: lngBase),
        ])],
      );
      await _montar(tester, e);

      await _mover(tester, e, _aqui);

      expect(find.text('Sin rutas cerca'), findsOneWidget);
      expect(find.text('Sin alertas cerca'), findsOneWidget);
    });

    testWidgets('el filtro del mapa no cambia lo que muestra el cuadro', (WidgetTester tester) async {
      final _Escenario e = _Escenario(rutas: <Ruta>[ruta], alertas: <Alerta>[alerta]);
      await _montar(tester, e);
      await _mover(tester, e, _aqui);

      await tester.tap(find.text('POIs'));
      await tester.pump();

      expect(find.text('Sendero del Rio'), findsOneWidget);
      expect(find.text('Bache'), findsOneWidget);
    });

    testWidgets('tocar la ruta abre su detalle', (WidgetTester tester) async {
      final _Escenario e = _Escenario(rutas: <Ruta>[ruta]);
      await _montar(tester, e);
      await _mover(tester, e, _aqui);

      await tester.tap(find.byKey(const ValueKey<String>('cerca-ruta')));
      await tester.pumpAndSettle();

      expect(find.byType(RutaDetalleScreen), findsOneWidget);
    });

    testWidgets('tocar la alerta abre su ficha con la distancia', (WidgetTester tester) async {
      final _Escenario e = _Escenario(alertas: <Alerta>[alerta]);
      await _montar(tester, e);
      await _mover(tester, e, _aqui);

      await tester.tap(find.byKey(const ValueKey<String>('cerca-alerta')));
      await tester.pumpAndSettle();

      expect(find.byType(FichaAlerta), findsOneWidget);
      expect(find.text('A unos 334 m'), findsOneWidget);
    });

    testWidgets('el "+" sin ubicacion avisa que aun no la tiene', (WidgetTester tester) async {
      await _montar(tester, _Escenario());

      await tester.tap(find.byTooltip('Reportar aqui'));
      await tester.pump();

      expect(
        find.text('Todavia no tengo tu ubicacion. Espera unos segundos o manten presionado el mapa.'),
        findsOneWidget,
      );
      expect(find.text('Que queres reportar?'), findsNothing);
    });

    testWidgets('el "+" con ubicacion deja reportar justo donde estas', (WidgetTester tester) async {
      final _Escenario e = _Escenario();
      await _montar(tester, e);
      await _mover(tester, e, _aqui);

      await tester.tap(find.byTooltip('Reportar aqui'));
      await tester.pumpAndSettle();
      expect(find.text('Que queres reportar?'), findsOneWidget);

      await tester.tap(find.text('Alerta'));
      await tester.pumpAndSettle();

      expect(find.byType(FormularioAlerta), findsOneWidget);
      expect(find.text('9.92810, -84.09070'), findsOneWidget);
    });
  });

  group('refresco', () {
    testWidgets('las rutas se piden al abrir y cada 5 minutos (cada una trae todo su trazo)', (
      WidgetTester tester,
    ) async {
      final _Escenario e = _Escenario();
      await _montar(tester, e);
      expect(e.rutaApi.cargas, 1);

      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      expect(e.rutaApi.cargas, 1);

      await tester.pump(const Duration(minutes: 4));
      await tester.pump();
      expect(e.rutaApi.cargas, 2);
    });

    testWidgets('los eventos se piden al abrir y cada minuto', (WidgetTester tester) async {
      final _Escenario e = _Escenario();
      await _montar(tester, e);
      expect(e.eventoApi.cargas, 1);

      await tester.pump(const Duration(seconds: 60));
      await tester.pump();

      expect(e.eventoApi.cargas, 2);
    });
  });
}
