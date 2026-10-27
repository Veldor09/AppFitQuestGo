import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/mapa/mapbox_directions_service.dart';
import 'package:fit_quest_go/core/voz/aviso_voz.dart';
import 'package:fit_quest_go/Modulos/rutas/application/actividades_service.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/recorrido_ruta_screen.dart';

class _VozFalsa implements AvisoVoz {
  final List<String> dichas = <String>[];

  @override
  Future<void> decir(String texto, {required Locale idioma}) async =>
      dichas.add(texto);

  @override
  Future<void> detener() async {}
}

class _DirectionsFalso extends MapboxDirectionsService {
  int llamadas = 0;

  @override
  Future<RutaVial?> rutaHastaInicio({
    required PosicionGps origen,
    required PosicionGps destino,
    String perfil = 'driving',
  }) async {
    llamadas++;
    return RutaVial(
      puntos: <PosicionGps>[origen, destino],
      distanciaMetros: 12000,
      duracionSegundos: 900,
    );
  }
}

class _ServicioFalso extends ActividadesService {
  final List<double> kms = <double>[];

  @override
  Future<ResultadoRecorrido> registrar({
    required int idUsuario,
    required int idRuta,
    required double distanciaKm,
    required int duracionSegundos,
    required DateTime iniciadoEn,
    required DateTime finalizadoEn,
    required List<PuntoRuta> puntos,
  }) async {
    kms.add(distanciaKm);
    return ResultadoRecorrido.guardadoLocal;
  }
}

// ~1.1 km hacia el este sobre lat 10.0.
const Ruta _ruta = Ruta(
  id: 7,
  nombre: 'Sendero Nicoya',
  actividades: <String>['running'],
  dificultad: 'moderada',
  distanciaKm: 1.1,
  estado: 'Publicada',
  puntos: <PuntoRuta>[
    PuntoRuta(lat: 10.0, lng: -85.000),
    PuntoRuta(lat: 10.0, lng: -84.995),
    PuntoRuta(lat: 10.0, lng: -84.990),
  ],
);

void main() {
  testWidgets(
    'lejos del inicio pide el camino una vez; al llegar empieza, avisa y finaliza',
    (WidgetTester tester) async {
      final StreamController<PosicionGps> gps =
          StreamController<PosicionGps>.broadcast();
      final _VozFalsa voz = _VozFalsa();
      final _DirectionsFalso directions = _DirectionsFalso();
      final _ServicioFalso servicio = _ServicioFalso();
      DateTime reloj = DateTime(2026, 1, 1, 8);

      await tester.pumpWidget(
        MaterialApp(
          home: RecorridoRutaScreen(
            ruta: _ruta,
            accessToken: '',
            posiciones: () => gps.stream,
            directions: directions,
            voz: voz,
            servicio: servicio,
            ahora: () => reloj,
            idUsuario: 1,
          ),
        ),
      );

      // Estas lejos (~11 km al oeste): fase de acercamiento.
      gps.add((lat: 10.0, lng: -85.10));
      await tester.pump();
      gps.add((lat: 10.0, lng: -85.09));
      await tester.pump();
      expect(find.textContaining('Rumbo al inicio'), findsOneWidget);
      expect(find.text('Empezar aquí'), findsOneWidget);
      expect(directions.llamadas, 1); // una sola consulta

      // Llegas al inicio: empieza solo y lo dice.
      gps.add((lat: 10.0, lng: -85.0001));
      await tester.pump();
      expect(find.textContaining('En ruta'), findsOneWidget);
      expect(find.text('Pausar'), findsOneWidget);
      expect(voz.dichas.last, contains('Has llegado al inicio'));

      // Caminas por el trazo (~300 m).
      reloj = reloj.add(const Duration(minutes: 3));
      gps.add((lat: 10.0, lng: -84.9980));
      await tester.pump();
      gps.add((lat: 10.0, lng: -84.9970));
      await tester.pump();

      // Te sales ~110 m del sendero: aviso de desviacion.
      gps.add((lat: 10.001, lng: -84.9970));
      await tester.pump();
      expect(find.textContaining('Fuera de ruta'), findsOneWidget);
      expect(voz.dichas.last, contains('desviado'));

      // Vuelves y finalizas.
      gps.add((lat: 10.0, lng: -84.9965));
      await tester.pump();
      expect(voz.dichas.last, contains('regresado'));

      await tester.tap(find.text('Finalizar'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Finalizar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('¡Felicidades!'), findsOneWidget);
      expect(find.textContaining('Recorriste'), findsOneWidget);
      expect(find.text('Listo'), findsOneWidget);

      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();

      expect(servicio.kms, hasLength(1));
      expect(servicio.kms.single, greaterThan(0.3));

      await gps.close();
    },
  );

  testWidgets(
    'al desviarse a otra calle antes de iniciar, reconstruye la ruta vial',
    (WidgetTester tester) async {
      final StreamController<PosicionGps> gps =
          StreamController<PosicionGps>.broadcast();
      final _VozFalsa voz = _VozFalsa();
      final _DirectionsFalso directions = _DirectionsFalso();
      final _ServicioFalso servicio = _ServicioFalso();
      DateTime reloj = DateTime(2026, 1, 1, 8);

      await tester.pumpWidget(
        MaterialApp(
          home: RecorridoRutaScreen(
            ruta: _ruta,
            accessToken: '',
            posiciones: () => gps.stream,
            directions: directions,
            voz: voz,
            servicio: servicio,
            ahora: () => reloj,
            idUsuario: 1,
          ),
        ),
      );

      // Posición 1 lejos: se solicita la ruta inicial por calles.
      gps.add((lat: 10.0, lng: -85.10));
      await tester.pump();
      expect(directions.llamadas, 1);

      // Posición 2: avanza sobre la misma calle/línea. No debe pedir otra vez.
      gps.add((lat: 10.0, lng: -85.09));
      await tester.pump();
      expect(directions.llamadas, 1);

      // Posición 3: entra a otra calle (se desvía > 30m del trazo vial previo).
      // Simulamos que pasan 5 segundos para superar el intervalo mínimo de repedir.
      reloj = reloj.add(const Duration(seconds: 5));
      gps.add((lat: 10.002, lng: -85.09));
      await tester.pump();

      // Debe haber pedido una nueva ruta para reconstruir el camino desde la nueva calle
      expect(directions.llamadas, 2);

      await gps.close();
    },
  );

  testWidgets(
    'cuando la carretera termina antes del inicio o no hay carretera, proyecta guia hacia el inicio',
    (WidgetTester tester) async {
      final StreamController<PosicionGps> gps =
          StreamController<PosicionGps>.broadcast();
      final _VozFalsa voz = _VozFalsa();
      final _DirectionsFalso directions = _DirectionsFalso();
      final _ServicioFalso servicio = _ServicioFalso();

      await tester.pumpWidget(
        MaterialApp(
          home: RecorridoRutaScreen(
            ruta: _ruta,
            accessToken: '',
            posiciones: () => gps.stream,
            directions: directions,
            voz: voz,
            servicio: servicio,
            idUsuario: 1,
          ),
        ),
      );

      // El usuario está a 150m del inicio
      gps.add((lat: 10.001, lng: -85.000));
      await tester.pump();

      expect(find.textContaining('Rumbo al inicio'), findsOneWidget);
      expect(find.text('Empezar aquí'), findsOneWidget);

      await gps.close();
    },
  );

  testWidgets(
    'al meterse a una casa mientras avanza, el trazo vial se mantiene en el asfalto y se guía con puntitos',
    (WidgetTester tester) async {
      final StreamController<PosicionGps> gps =
          StreamController<PosicionGps>.broadcast();
      final _VozFalsa voz = _VozFalsa();
      final _DirectionsFalso directions = _DirectionsFalso();
      final _ServicioFalso servicio = _ServicioFalso();

      await tester.pumpWidget(
        MaterialApp(
          home: RecorridoRutaScreen(
            ruta: _ruta,
            accessToken: '',
            posiciones: () => gps.stream,
            directions: directions,
            voz: voz,
            servicio: servicio,
            idUsuario: 1,
          ),
        ),
      );

      // Posición 1 sobre la carretera (lat 10.0, lng -85.10)
      gps.add((lat: 10.0, lng: -85.10));
      await tester.pump();
      expect(directions.llamadas, 1);

      // Posición 2: se mete a una casa a 15m al norte del asfalto (lat 10.000135, lng -85.09)
      gps.add((lat: 10.000135, lng: -85.09));
      await tester.pump();

      // No dispara petición innecesaria porque está dentro del umbral vial (< 30m)
      expect(directions.llamadas, 1);
      expect(find.textContaining('Rumbo al inicio'), findsOneWidget);

      await gps.close();
    },
  );

  testWidgets('sin posiciones muestra que busca la ubicacion', (
    WidgetTester tester,
  ) async {
    final StreamController<PosicionGps> gps =
        StreamController<PosicionGps>.broadcast();
    await tester.pumpWidget(
      MaterialApp(
        home: RecorridoRutaScreen(
          ruta: _ruta,
          accessToken: '',
          posiciones: () => gps.stream,
          directions: _DirectionsFalso(),
          voz: _VozFalsa(),
          servicio: _ServicioFalso(),
        ),
      ),
    );
    expect(find.textContaining('Buscando tu ubicación'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await gps.close();
  });

  testWidgets('muestra boton Activar ubicacion al no tener GPS y reconecta al reanudar app', (
    WidgetTester tester,
  ) async {
    int llamadasGps = 0;
    StreamController<PosicionGps> gps = StreamController<PosicionGps>.broadcast();

    await tester.pumpWidget(
      MaterialApp(
        home: RecorridoRutaScreen(
          ruta: _ruta,
          accessToken: '',
          posiciones: () {
            llamadasGps++;
            return gps.stream;
          },
          directions: _DirectionsFalso(),
          voz: _VozFalsa(),
          servicio: _ServicioFalso(),
        ),
      ),
    );

    // Cierra el stream sin emitir -> entra en _sinGps
    await gps.close();
    await tester.pump();

    expect(find.text('Activar ubicación'), findsOneWidget);
    expect(llamadasGps, 1);

    // Reanudar la app simula volver desde los ajustes del teléfono
    gps = StreamController<PosicionGps>.broadcast();
    final WidgetsBindingObserver state =
        tester.state(find.byType(RecorridoRutaScreen)) as WidgetsBindingObserver;
    state.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(llamadasGps, 2);
    await tester.pumpWidget(const SizedBox());
    await gps.close();
  });

  testWidgets('tocar Empezar aquí inicia inmediatamente la ruta y muestra Pausar y Finalizar', (
    WidgetTester tester,
  ) async {
    final StreamController<PosicionGps> gps = StreamController<PosicionGps>.broadcast();
    final _VozFalsa voz = _VozFalsa();

    await tester.pumpWidget(
      MaterialApp(
        home: RecorridoRutaScreen(
          ruta: _ruta,
          accessToken: '',
          posiciones: () => gps.stream,
          directions: _DirectionsFalso(),
          voz: voz,
          servicio: _ServicioFalso(),
        ),
      ),
    );

    // Usuario lejos del inicio
    gps.add((lat: 10.0, lng: -85.10));
    await tester.pump();
    expect(find.text('Empezar aquí'), findsOneWidget);
    expect(find.text('Pausar'), findsNothing);

    // Toca "Empezar aquí"
    await tester.tap(find.text('Empezar aquí'));
    await tester.pump();

    // Muestra los controles de sesión activa pero mantiene la indicación vial
    expect(find.text('Pausar'), findsOneWidget);
    expect(find.text('Finalizar'), findsOneWidget);
    expect(find.text('Empezar aquí'), findsNothing);
    expect(find.text('Sigue la línea verde hasta el inicio de la ruta'), findsOneWidget);
    expect(voz.dichas.last, contains('Comienza el recorrido'));

    // Al llegar al inicio de la ruta, avisa la llegada y oculta la guía vial
    gps.add((lat: 10.0, lng: -85.0001));
    await tester.pump();
    expect(find.text('Sigue la línea verde hasta el inicio de la ruta'), findsNothing);
    expect(voz.dichas.last, contains('Has llegado al inicio'));

    await tester.pumpWidget(const SizedBox());
    await gps.close();
  });

  testWidgets(
    'al avanzar en ruta se evalua progreso, al desviarse 20m o mas y al regresar',
    (WidgetTester tester) async {
      final StreamController<PosicionGps> gps =
          StreamController<PosicionGps>.broadcast();
      final _VozFalsa voz = _VozFalsa();
      final _DirectionsFalso directions = _DirectionsFalso();
      final _ServicioFalso servicio = _ServicioFalso();
      DateTime reloj = DateTime(2026, 1, 1, 8);

      await tester.pumpWidget(
        MaterialApp(
          home: RecorridoRutaScreen(
            ruta: _ruta,
            accessToken: '',
            posiciones: () => gps.stream,
            directions: directions,
            voz: voz,
            servicio: servicio,
            ahora: () => reloj,
            idUsuario: 1,
          ),
        ),
      );

      // 1. Llega al inicio de la ruta.
      gps.add((lat: 10.0, lng: -85.0001));
      await tester.pump();
      expect(find.textContaining('En ruta'), findsOneWidget);

      // 2. Avanza por el sendero.
      reloj = reloj.add(const Duration(minutes: 2));
      gps.add((lat: 10.0, lng: -84.9960));
      await tester.pump();
      expect(find.textContaining('En ruta'), findsOneWidget);

      // 3. Retrocede en el sendero (se vuelve a evaluar el segmento previo).
      gps.add((lat: 10.0, lng: -84.9975));
      await tester.pump();
      expect(find.textContaining('En ruta'), findsOneWidget);

      // 4. Se desvía ~60m de la ruta (activa tanto puntitos a >=20m como alerta fuera de ruta).
      gps.add((lat: 10.0006, lng: -84.9975));
      await tester.pump();
      expect(find.textContaining('Fuera de ruta'), findsOneWidget);

      // 5. Regresa al sendero.
      gps.add((lat: 10.0, lng: -84.9975));
      await tester.pump();
      expect(find.textContaining('En ruta'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await gps.close();
    },
  );

  testWidgets(
    'al llegar al final de la ruta finaliza automáticamente y muestra estadísticas sin requerir pulsar el botón',
    (WidgetTester tester) async {
      final StreamController<PosicionGps> gps =
          StreamController<PosicionGps>.broadcast();
      final _VozFalsa voz = _VozFalsa();
      final _DirectionsFalso directions = _DirectionsFalso();
      final _ServicioFalso servicio = _ServicioFalso();
      DateTime reloj = DateTime(2026, 1, 1, 8);

      await tester.pumpWidget(
        MaterialApp(
          home: RecorridoRutaScreen(
            ruta: _ruta,
            accessToken: '',
            posiciones: () => gps.stream,
            directions: directions,
            voz: voz,
            servicio: servicio,
            ahora: () => reloj,
            idUsuario: 1,
          ),
        ),
      );

      // 1. Llega al inicio de la ruta
      gps.add((lat: 10.0, lng: -85.0001));
      await tester.pump();
      expect(find.textContaining('En ruta'), findsOneWidget);

      // 2. Avanza por el sendero
      reloj = reloj.add(const Duration(minutes: 5));
      gps.add((lat: 10.0, lng: -84.9950));
      await tester.pump();

      // 3. Llega al final de la ruta (a menos de 30m del punto final -84.990)
      reloj = reloj.add(const Duration(minutes: 5));
      gps.add((lat: 10.0, lng: -84.9901));
      await tester.pumpAndSettle();

      // Finaliza automáticamente: muestra modal con felicitaciones y estadísticas sin tocar Finalizar
      expect(voz.dichas.last, contains('Has llegado al final'));
      expect(find.text('¡Felicidades!'), findsOneWidget);
      expect(find.textContaining('Recorriste'), findsOneWidget);
      expect(find.text('Listo'), findsOneWidget);
      expect(servicio.kms, hasLength(1));
      expect(servicio.kms.single, greaterThan(1.0));

      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await gps.close();
    },
  );
}

