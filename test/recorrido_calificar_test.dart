import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/mapa/mapbox_directions_service.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/voz/aviso_voz.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/rutas/application/actividades_service.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/recorrido_ruta_screen.dart';
import 'helpers/calificacion_falsa.dart';

class _VozFalsa implements AvisoVoz {
  @override
  Future<void> decir(String texto, {required Locale idioma}) async {}

  @override
  Future<void> detener() async {}
}

class _DirectionsFalso extends MapboxDirectionsService {
  @override
  Future<RutaVial?> rutaHastaInicio({
    required PosicionGps origen,
    required PosicionGps destino,
    String perfil = 'driving',
  }) async => null;
}

class _ServicioFalso extends ActividadesService {
  _ServicioFalso(this.resultado);

  final ResultadoRecorrido resultado;

  @override
  Future<ResultadoRecorrido> registrar({
    required int idUsuario,
    required int idRuta,
    required double distanciaKm,
    required int duracionSegundos,
    required DateTime iniciadoEn,
    required DateTime finalizadoEn,
    required List<PuntoRuta> puntos,
  }) async => resultado;
}

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

/// Empieza en el inicio, camina ~300 m, finaliza y confirma. Deja abierto el
/// resumen de llegada.
Future<void> _recorrerYFinalizar(
  WidgetTester tester, {
  required ResultadoRecorrido resultado,
  required CalificacionApiFalsa calificaciones,
}) async {
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  tester.platformDispatcher.localeTestValue = const Locale('es');
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);

  final StreamController<PosicionGps> gps =
      StreamController<PosicionGps>.broadcast();
  addTearDown(gps.close);
  DateTime reloj = DateTime(2026, 1, 1, 8);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) =>
          NotificacionesHost(child: child!),
      home: RecorridoRutaScreen(
        ruta: _ruta,
        accessToken: '',
        posiciones: () => gps.stream,
        directions: _DirectionsFalso(),
        voz: _VozFalsa(),
        servicio: _ServicioFalso(resultado),
        ahora: () => reloj,
        idUsuario: 1,
        calificaciones: calificaciones,
      ),
    ),
  );

  gps.add((lat: 10.0, lng: -85.0001));
  await tester.pump();
  reloj = reloj.add(const Duration(minutes: 3));
  gps.add((lat: 10.0, lng: -84.9980));
  await tester.pump();
  gps.add((lat: 10.0, lng: -84.9970));
  await tester.pump();

  await tester.tap(find.text('Finalizar'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Finalizar'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('al terminar un recorrido ya registrado ofrece calificar la ruta', (
    WidgetTester tester,
  ) async {
    final CalificacionApiFalsa api = CalificacionApiFalsa();

    await _recorrerYFinalizar(
      tester,
      resultado: ResultadoRecorrido.subido,
      calificaciones: api,
    );

    expect(find.text('¡Felicidades!'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('calificar-recorrido')),
      findsOneWidget,
    );
    expect(find.text('¿Cómo estuvo tu recorrido?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('pulgar-arriba')));
    await tester.pumpAndSettle();

    expect(api.enviadas.single.tipo, TipoCalificable.ruta);
    expect(api.enviadas.single.id, 7);
    expect(api.enviadas.single.valor, ValorCalificacion.arriba);
    expect(find.text('¡Gracias por tu calificación!'), findsOneWidget);
  });

  testWidgets('el pulgar abajo tambien se manda', (WidgetTester tester) async {
    final CalificacionApiFalsa api = CalificacionApiFalsa();

    await _recorrerYFinalizar(
      tester,
      resultado: ResultadoRecorrido.subido,
      calificaciones: api,
    );
    await tester.tap(find.byKey(const ValueKey<String>('pulgar-abajo')));
    await tester.pumpAndSettle();

    expect(api.enviadas.single.valor, ValorCalificacion.abajo);
  });

  testWidgets(
    'si el recorrido solo quedo guardado en el telefono no ofrece calificar',
    (WidgetTester tester) async {
      final CalificacionApiFalsa api = CalificacionApiFalsa();

      await _recorrerYFinalizar(
        tester,
        resultado: ResultadoRecorrido.guardadoLocal,
        calificaciones: api,
      );

      expect(find.text('¡Felicidades!'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('calificar-recorrido')),
        findsNothing,
      );
      expect(api.resumenesPedidos, isEmpty);
    },
  );

  testWidgets('se puede cerrar el resumen sin calificar', (
    WidgetTester tester,
  ) async {
    final CalificacionApiFalsa api = CalificacionApiFalsa();

    await _recorrerYFinalizar(
      tester,
      resultado: ResultadoRecorrido.subido,
      calificaciones: api,
    );
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();

    expect(api.enviadas, isEmpty);
  });
}
