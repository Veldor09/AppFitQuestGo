import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/mapa/mapbox_directions_service.dart';
import 'package:fit_quest_go/core/voz/aviso_voz.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/evento_detalle_screen.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/ficha_evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/recorrido_evento_screen.dart';
import 'helpers/calificacion_falsa.dart';
import 'helpers/montar.dart';

class _AvisoVozFalso implements AvisoVoz {
  final List<String> dichos = <String>[];

  @override
  Future<void> decir(String texto, {Locale? idioma}) async {
    dichos.add(texto);
  }

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
      distanciaMetros: 500,
      duracionSegundos: 360,
    );
  }
}

const List<PuntoGeo> _triangulo = <PuntoGeo>[
  PuntoGeo(lat: 10.0, lng: -84.0),
  PuntoGeo(lat: 10.0, lng: -83.9),
  PuntoGeo(lat: 10.1, lng: -84.0),
];

Evento _evento() {
  return Evento(
    id: 12,
    nombre: 'Festival Deportivo Heredia',
    categoria: 'competencia',
    fechaInicio: DateTime(2030, 5, 10, 8),
    fechaFin: DateTime(2030, 5, 10, 11),
    areas: const <ZonaEvento>[
      ZonaEvento(nombre: 'Zona Principal', puntos: _triangulo),
    ],
    recorridos: const <ZonaEvento>[],
    creadoPorNombre: 'Comité de Deportes',
  );
}

void main() {
  testWidgets('EventoDetalleScreen: Como llegar abre RecorridoEventoScreen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Evento ev = _evento();
    await montarApp(
      tester,
      EventoDetalleScreen(
        evento: ev,
        mapaBuilder: (_) => const SizedBox(height: 100),
        calificaciones: CalificacionApiFalsa(
          respuesta: ResumenCalificacion(
            arriba: 5,
            abajo: 0,
            puedeCalificar: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder btnComoLlegar = find.byKey(
      const ValueKey<String>('ficha-como-llegar'),
    );
    expect(btnComoLlegar, findsOneWidget);

    await tester.tap(btnComoLlegar);
    await tester.pumpAndSettle();

    expect(find.byType(RecorridoEventoScreen), findsOneWidget);
    expect(find.text('Festival Deportivo Heredia'), findsAtLeastNWidgets(1));
  });

  testWidgets('FichaEvento: Como llegar abre RecorridoEventoScreen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Evento ev = _evento();
    await montarApp(
      tester,
      Scaffold(
        body: FichaEvento(
          evento: ev,
          calificaciones: CalificacionApiFalsa(
            respuesta: ResumenCalificacion(
              arriba: 1,
              abajo: 0,
              puedeCalificar: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder btnComoLlegar = find.byKey(
      const ValueKey<String>('ficha-como-llegar'),
    );
    expect(btnComoLlegar, findsOneWidget);

    await tester.tap(btnComoLlegar);
    await tester.pumpAndSettle();

    expect(find.byType(RecorridoEventoScreen), findsOneWidget);
    expect(find.text('Festival Deportivo Heredia'), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'RecorridoEventoScreen: pide camino y al llegar anuncia por voz y muestra resumen',
    (WidgetTester tester) async {
      final StreamController<PosicionGps> gps =
          StreamController<PosicionGps>.broadcast();
      addTearDown(gps.close);

      final _DirectionsFalso directions = _DirectionsFalso();
      final _AvisoVozFalso voz = _AvisoVozFalso();
      final Evento ev = _evento();

      await montarApp(
        tester,
        RecorridoEventoScreen(
          evento: ev,
          accessToken: '', // Sin mapbox nativo
          directions: directions,
          voz: voz,
          posiciones: () => gps.stream,
        ),
      );
      await tester.pump();

      expect(find.text('Festival Deportivo Heredia'), findsOneWidget);
      expect(find.text('Buscando tu ubicación…'), findsOneWidget);

      // Posición lejos (~500 m)
      gps.add((lat: 10.03, lng: -83.98));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(directions.llamadas, 1);
      expect(find.textContaining('Rumbo al evento'), findsOneWidget);

      // Posición en destino (< 50 m del centroide)
      final ({double lat, double lng}) dest = destinoDeEvento(ev)!;
      gps.add((lat: dest.lat, lng: dest.lng));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        voz.dichos.any((String d) => d.contains('Festival Deportivo Heredia')),
        isTrue,
      );
      expect(find.text('¡Has llegado al evento!'), findsAtLeastNWidgets(1));

      // Tocar botón listo en resumen
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
    },
  );
}
