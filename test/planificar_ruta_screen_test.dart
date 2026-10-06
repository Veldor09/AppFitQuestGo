import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/planificar_ruta_screen.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:geolocator/geolocator.dart';

/// Reloj controlable: `tester.pump(Duration)` adelanta los timers pero no
/// `DateTime.now()`, asi que el tiempo "de pared" se mueve a mano.
class _Reloj {
  DateTime ahora = DateTime(2026, 10, 5, 8);

  void avanzar(int segundos) => ahora = ahora.add(Duration(seconds: segundos));
}

/// Guarda lo que la pantalla le manda a `crear` en vez de llamar a la red.
class _RutaApiFalsa extends RutaApi {
  final List<List<String>> actividadesCreadas = <List<String>>[];

  @override
  Future<Ruta> crear({
    required String nombre,
    required List<String> actividades,
    String? dificultad,
    required double distanciaKm,
    required List<PuntoRuta> puntos,
  }) async {
    actividadesCreadas.add(actividades);
    return Ruta(
      id: 1,
      nombre: nombre,
      actividades: actividades,
      dificultad: dificultad ?? 'moderada',
      distanciaKm: distanciaKm,
      puntos: puntos,
      estado: 'Privada',
    );
  }
}

Widget _montar({
  Stream<Position>? streamFalso,
  DateTime Function()? ahora,
  RutaApi? api,
}) {
  return MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: PlanificarRutaScreen(
        api: api ?? RutaApi(),
        posicionStream: streamFalso == null ? null : (() => streamFalso),
        ahora: ahora,
      ),
    ),
  );
}

/// El entorno de test no tiene un locale real de dispositivo (por defecto
/// cae en en_US); se fuerza espanol para que las pruebas sean deterministas
/// y coincidan con `locale: Locale('es')` de `_montar()`. Ver nota igual en
/// `widget_test.dart`: `MaterialApp.locale` fuerza la UI, pero algunas rutas
/// de resolucion interna igual consultan `platformDispatcher`, asi que se
/// fijan ambos valores para evitar sorpresas.
void _forzarLocaleEspanol(WidgetTester tester) {
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  tester.platformDispatcher.localeTestValue = const Locale('es');
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);
}

/// Monta la pantalla, pasa a "Grabar GPS" y arranca la grabacion con un stream
/// falso. Devuelve el controlador para emitir posiciones.
Future<StreamController<Position>> _empezarAGrabar(
  WidgetTester tester, {
  _Reloj? reloj,
  RutaApi? api,
}) async {
  _forzarLocaleEspanol(tester);
  // `broadcast`: algunas pruebas graban dos veces y vuelven a suscribirse.
  final StreamController<Position> controlador =
      StreamController<Position>.broadcast();
  addTearDown(controlador.close);

  await tester.pumpWidget(
    _montar(
      streamFalso: controlador.stream,
      ahora: reloj == null ? null : () => reloj.ahora,
      api: api,
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Grabar GPS'));
  await tester.pump();
  await tester.tap(find.text('Iniciar grabacion'));
  await tester.pump();
  return controlador;
}

Future<void> _emitir(
  WidgetTester tester,
  StreamController<Position> controlador,
  double lat,
  double lng,
) async {
  controlador.add(_posicion(lat, lng));
  await tester.pump();
}

/// Toca "Detener", deja que se cancele la suscripcion (necesita el reloj real:
/// `cancel()` espera un hueco de event loop que `pump` no da) y espera a que
/// termine la transicion hacia el resumen.
Future<void> _detener(WidgetTester tester) async {
  await tester.tap(find.text('Detener'));
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('arranca en modo Dibujar, con el selector visible', (
    WidgetTester tester,
  ) async {
    _forzarLocaleEspanol(tester);

    await tester.pumpWidget(_montar());
    await tester.pump();

    expect(find.text('Dibujar'), findsOneWidget);
    expect(find.text('Grabar GPS'), findsOneWidget);
    expect(find.text('Toca el mapa para trazar tu ruta, punto por punto.'),
        findsOneWidget);
  });

  testWidgets('cambiar a modo GPS muestra el boton Iniciar grabacion', (
    WidgetTester tester,
  ) async {
    _forzarLocaleEspanol(tester);

    await tester.pumpWidget(_montar());
    await tester.pump();

    await tester.tap(find.text('Grabar GPS'));
    await tester.pump();

    expect(find.text('Iniciar grabacion'), findsOneWidget);
  });

  testWidgets('al grabar, cada posicion del stream se agrega como punto', (
    WidgetTester tester,
  ) async {
    final StreamController<Position> controlador =
        await _empezarAGrabar(tester);

    await _emitir(tester, controlador, 9.9281, -84.0907);
    await _emitir(tester, controlador, 9.9291, -84.0917);

    expect(find.textContaining('2 puntos'), findsOneWidget);
    expect(find.text('Detener'), findsOneWidget);
  });

  testWidgets('mientras graba muestra tiempo, distancia y ritmo en vivo', (
    WidgetTester tester,
  ) async {
    final _Reloj reloj = _Reloj();
    final StreamController<Position> controlador =
        await _empezarAGrabar(tester, reloj: reloj);

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('--:--'), findsOneWidget); // sin distancia aun, sin ritmo

    await _emitir(tester, controlador, 9.9281, -84.0907);
    await _emitir(tester, controlador, 9.9381, -84.0907); // ~1.11 km
    reloj.avanzar(360);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('06:00'), findsOneWidget);
    expect(find.text('1.11'), findsOneWidget);
    expect(find.text('5:24'), findsOneWidget); // 360 s / 1.11 km
  });

  testWidgets('el cronometro avanza cada segundo', (WidgetTester tester) async {
    final _Reloj reloj = _Reloj();
    await _empezarAGrabar(tester, reloj: reloj);

    reloj.avanzar(1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);

    reloj.avanzar(1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:02'), findsOneWidget);
  });

  testWidgets('Pausar congela el cronometro y no suma puntos; Reanudar retoma', (
    WidgetTester tester,
  ) async {
    final _Reloj reloj = _Reloj();
    final StreamController<Position> controlador =
        await _empezarAGrabar(tester, reloj: reloj);
    await _emitir(tester, controlador, 9.9281, -84.0907);
    await _emitir(tester, controlador, 9.9291, -84.0907);
    reloj.avanzar(10);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:10'), findsOneWidget);

    await tester.tap(find.text('Pausar'));
    await tester.pump();

    expect(find.text('Reanudar'), findsOneWidget);
    expect(find.text('Pausar'), findsNothing);
    expect(find.text('En pausa. Toca "Reanudar" para seguir.'), findsOneWidget);

    reloj.avanzar(60);
    await tester.pump(const Duration(seconds: 1));
    await _emitir(tester, controlador, 9.9301, -84.0907); // en pausa: se ignora

    expect(find.text('00:10'), findsOneWidget);
    expect(find.textContaining('2 puntos'), findsOneWidget);

    await tester.tap(find.text('Reanudar'));
    await tester.pump();
    expect(find.text('Pausar'), findsOneWidget);

    reloj.avanzar(5);
    await _emitir(tester, controlador, 9.9311, -84.0907);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('00:15'), findsOneWidget);
    expect(find.textContaining('3 puntos'), findsOneWidget);
  });

  testWidgets('Detener abre el resumen con los datos de la sesion', (
    WidgetTester tester,
  ) async {
    final _Reloj reloj = _Reloj();
    final StreamController<Position> controlador =
        await _empezarAGrabar(tester, reloj: reloj);
    await _emitir(tester, controlador, 9.9281, -84.0907);
    await _emitir(tester, controlador, 9.9381, -84.0907); // ~1.11 km
    reloj.avanzar(360);

    await _detener(tester);

    expect(find.text('Resumen de la grabacion'), findsOneWidget);
    expect(find.text('06:00'), findsOneWidget);
    expect(find.text('1.11'), findsOneWidget);
    expect(find.text('5:24'), findsOneWidget);
    expect(controlador.hasListener, isFalse);
  });

  testWidgets('Detener sin haber grabado nada no abre el resumen', (
    WidgetTester tester,
  ) async {
    await _empezarAGrabar(tester);

    await _detener(tester);

    expect(find.text('Resumen de la grabacion'), findsNothing);
    expect(find.text('Iniciar grabacion'), findsOneWidget);
  });

  testWidgets('"Guardar ruta" en el resumen abre el formulario de guardado', (
    WidgetTester tester,
  ) async {
    final StreamController<Position> controlador =
        await _empezarAGrabar(tester);
    await _emitir(tester, controlador, 9.9281, -84.0907);
    await _emitir(tester, controlador, 9.9381, -84.0907);
    await _detener(tester);

    await tester.tap(find.text('Guardar ruta'));
    await tester.pumpAndSettle();

    expect(find.text('Resumen de la grabacion'), findsNothing);
    expect(find.text('Nombre'), findsOneWidget);
    expect(find.text('Actividades'), findsOneWidget);
  });

  group('actividades del formulario de guardado (lista cerrada, multiple)', () {
    /// Graba dos puntos, detiene y abre el formulario desde el resumen.
    Future<_RutaApiFalsa> abrirFormulario(WidgetTester tester) async {
      final _RutaApiFalsa api = _RutaApiFalsa();
      final StreamController<Position> controlador =
          await _empezarAGrabar(tester, api: api);
      await _emitir(tester, controlador, 9.9281, -84.0907);
      await _emitir(tester, controlador, 9.9381, -84.0907);
      await _detener(tester);
      await tester.tap(find.text('Guardar ruta'));
      await tester.pumpAndSettle();
      return api;
    }

    Future<void> escribirNombre(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Vuelta al lago',
      );
    }

    Future<void> guardarFormulario(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
    }

    testWidgets('ofrece las actividades para elegir, sin campo de texto', (
      WidgetTester tester,
    ) async {
      await abrirFormulario(tester);

      for (final String actividad in <String>[
        'Running',
        'Ciclismo',
        'MTB',
        'Hiking',
        'Caminata',
        'Otro',
      ]) {
        expect(find.text(actividad), findsOneWidget, reason: actividad);
      }
      expect(find.widgetWithText(TextFormField, 'Actividad'), findsNothing);
    });

    testWidgets('sin elegir ninguna avisa y no guarda', (WidgetTester tester) async {
      final _RutaApiFalsa api = await abrirFormulario(tester);
      await escribirNombre(tester);

      await guardarFormulario(tester);

      expect(find.text('Elegi al menos una actividad'), findsOneWidget);
      expect(find.text('Nombre'), findsOneWidget); // el formulario sigue abierto
      expect(api.actividadesCreadas, isEmpty);
    });

    testWidgets('se pueden elegir varias y viajan en el orden del catalogo', (
      WidgetTester tester,
    ) async {
      final _RutaApiFalsa api = await abrirFormulario(tester);
      await escribirNombre(tester);

      await tester.tap(find.text('Hiking'));
      await tester.tap(find.text('Running'));
      await tester.pump();
      await guardarFormulario(tester);

      expect(api.actividadesCreadas, <List<String>>[
        <String>['running', 'hiking'],
      ]);
    });

    testWidgets('tocar de nuevo una actividad la desmarca', (WidgetTester tester) async {
      final _RutaApiFalsa api = await abrirFormulario(tester);
      await escribirNombre(tester);

      await tester.tap(find.text('Running'));
      await tester.tap(find.text('Ciclismo'));
      await tester.tap(find.text('Running'));
      await tester.pump();
      await guardarFormulario(tester);

      expect(api.actividadesCreadas, <List<String>>[
        <String>['ciclismo'],
      ]);
    });

    testWidgets('elegir una actividad quita el aviso de error', (
      WidgetTester tester,
    ) async {
      await abrirFormulario(tester);
      await escribirNombre(tester);
      await guardarFormulario(tester);
      expect(find.text('Elegi al menos una actividad'), findsOneWidget);

      await tester.tap(find.text('Caminata'));
      await tester.pump();

      expect(find.text('Elegi al menos una actividad'), findsNothing);
    });
  });

  testWidgets('"Descartar" en el resumen limpia la grabacion', (
    WidgetTester tester,
  ) async {
    final StreamController<Position> controlador =
        await _empezarAGrabar(tester);
    await _emitir(tester, controlador, 9.9281, -84.0907);
    await _emitir(tester, controlador, 9.9381, -84.0907);
    await _detener(tester);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(find.text('Sin puntos todavia'), findsOneWidget);
    expect(find.text('Iniciar grabacion'), findsOneWidget);
    expect(find.text('00:00'), findsNothing);
  });

  testWidgets('Iniciar otra vez empieza una grabacion limpia', (
    WidgetTester tester,
  ) async {
    final _Reloj reloj = _Reloj();
    final StreamController<Position> controlador =
        await _empezarAGrabar(tester, reloj: reloj);
    await _emitir(tester, controlador, 9.9281, -84.0907);
    await _emitir(tester, controlador, 9.9381, -84.0907);
    reloj.avanzar(360);
    await _detener(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar grabacion'));
    await tester.pump();

    expect(find.text('Sin puntos todavia'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('06:00'), findsNothing);
  });

  testWidgets('volver del resumen conserva la ruta y habilita Guardar', (
    WidgetTester tester,
  ) async {
    final StreamController<Position> controlador =
        await _empezarAGrabar(tester);
    await _emitir(tester, controlador, 9.9281, -84.0907);
    await _emitir(tester, controlador, 9.9291, -84.0917);

    await _detener(tester);

    expect(controlador.hasListener, isFalse);
    // `pageBack()` busca el tooltip "Back" en ingles; aqui la UI esta en espanol.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Detener'), findsNothing);
    expect(find.text('Iniciar grabacion'), findsOneWidget);

    final Finder guardarFinder = find.widgetWithText(FqButton, 'Guardar');
    expect(guardarFinder, findsOneWidget);
    expect(tester.widget<FqButton>(guardarFinder).onPressed, isNotNull);
  });
}

Position _posicion(double lat, double lng) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
