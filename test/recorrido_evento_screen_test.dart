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

  testWidgets(
    'RecorridoEventoScreen con ruta: acerca al inicio, inicia recorrido, consume tramo y finaliza al llegar a la meta',
    (WidgetTester tester) async {
      final StreamController<PosicionGps> gps =
          StreamController<PosicionGps>.broadcast();
      addTearDown(gps.close);

      final _DirectionsFalso directions = _DirectionsFalso();
      final _AvisoVozFalso voz = _AvisoVozFalso();
      final Evento ev = Evento(
        id: 15,
        nombre: 'Carrera 5K San José',
        categoria: 'carrera',
        fechaInicio: DateTime(2030, 6, 1, 7),
        fechaFin: DateTime(2030, 6, 1, 10),
        areas: const <ZonaEvento>[],
        recorridos: const <ZonaEvento>[
          ZonaEvento(
            nombre: 'Recorrido 5K',
            puntos: <PuntoGeo>[
              PuntoGeo(lat: 10.0, lng: -85.000),
              PuntoGeo(lat: 10.0, lng: -84.995),
              PuntoGeo(lat: 10.0, lng: -84.990),
            ],
          ),
        ],
        creadoPorNombre: 'Organización 5K',
      );

      await montarApp(
        tester,
        RecorridoEventoScreen(
          evento: ev,
          accessToken: '',
          directions: directions,
          voz: voz,
          posiciones: () => gps.stream,
        ),
      );
      await tester.pump();

      expect(find.text('Carrera 5K San José'), findsOneWidget);

      // Posición lejos (~11 km al oeste): fase de acercamiento al inicio
      gps.add((lat: 10.0, lng: -85.10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Rumbo al inicio'), findsOneWidget);
      expect(find.text('Empezar recorrido'), findsOneWidget);

      // Llega al inicio del recorrido
      gps.add((lat: 10.0, lng: -85.0001));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('En ruta'), findsOneWidget);
      expect(find.text('Finalizar recorrido'), findsOneWidget);
      expect(voz.dichos.last, contains('Comienza el recorrido'));

      // Avanza por el recorrido
      gps.add((lat: 10.0, lng: -84.9960));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('En ruta'), findsOneWidget);

      // Se desvía ~60m
      gps.add((lat: 10.0006, lng: -84.9960));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Fuera de ruta'), findsOneWidget);
      expect(voz.dichos.last, contains('desviado'));

      // Regresa a la ruta
      gps.add((lat: 10.0, lng: -84.9960));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('En ruta'), findsOneWidget);

      // Llega a la meta (-84.990)
      gps.add((lat: 10.0, lng: -84.9901));
      await tester.pumpAndSettle();

      expect(voz.dichos.last, contains('completado el recorrido'));
      expect(find.text('¡Has completado el recorrido!'), findsOneWidget);
      expect(find.text('Listo'), findsOneWidget);

      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'RecorridoEventoScreen: si el camino de aproximación cruza la mitad del recorrido, NO se monta a la ruta prematuramente',
    (WidgetTester tester) async {
      final StreamController<PosicionGps> gps =
          StreamController<PosicionGps>.broadcast();
      addTearDown(gps.close);

      final _DirectionsFalso directions = _DirectionsFalso();
      final _AvisoVozFalso voz = _AvisoVozFalso();
      final Evento ev = Evento(
        id: 16,
        nombre: 'Maratón de San José',
        categoria: 'carrera',
        fechaInicio: DateTime(2030, 7, 1, 6),
        fechaFin: DateTime(2030, 7, 1, 12),
        areas: const <ZonaEvento>[],
        recorridos: const <ZonaEvento>[
          ZonaEvento(
            nombre: 'Ruta 10K',
            puntos: <PuntoGeo>[
              PuntoGeo(lat: 9.930, lng: -84.080), // Inicio
              PuntoGeo(lat: 9.940, lng: -84.080), // Mitad (~1.1 km al norte)
              PuntoGeo(lat: 9.950, lng: -84.080), // Fin
            ],
          ),
        ],
        creadoPorNombre: 'Federación de Atletismo',
      );

      await montarApp(
        tester,
        RecorridoEventoScreen(
          evento: ev,
          accessToken: '',
          directions: directions,
          voz: voz,
          posiciones: () => gps.stream,
        ),
      );
      await tester.pump();

      // Usuario está a ~1.1 km del inicio, pero exactamente encima del punto medio de la ruta (9.940, -84.080)
      gps.add((lat: 9.940, lng: -84.0801));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Debe mantenerse en fase de aproximación ("Rumbo al inicio") y NO en ruta
      expect(find.textContaining('Rumbo al inicio'), findsOneWidget);
      expect(find.text('Empezar recorrido'), findsOneWidget);
      expect(find.text('Pausar'), findsNothing);
      expect(find.text('Finalizar recorrido'), findsNothing);
      expect(
        voz.dichos.any((String d) => d.contains('Comienza el recorrido')),
        isFalse,
      );

      // Ahora el usuario llega al punto inicial (9.930, -84.080)
      gps.add((lat: 9.9301, lng: -84.0801));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Ahora sí se debe activar la ruta y mostrar Pausar y Finalizar
      expect(find.textContaining('En ruta'), findsOneWidget);
      expect(find.text('Pausar'), findsOneWidget);
      expect(find.text('Finalizar recorrido'), findsOneWidget);
      expect(
        voz.dichos.any((String d) => d.contains('Comienza el recorrido')),
        isTrue,
      );
    },
  );

  testWidgets(
    'RecorridoEventoScreen: pulsar Empezar recorrido inicia de inmediato y permite Pausar/Reanudar y Finalizar',
    (WidgetTester tester) async {
      final StreamController<PosicionGps> gps =
          StreamController<PosicionGps>.broadcast();
      addTearDown(gps.close);

      final _DirectionsFalso directions = _DirectionsFalso();
      final _AvisoVozFalso voz = _AvisoVozFalso();
      final Evento ev = Evento(
        id: 17,
        nombre: 'Ciclopaseo Familiar',
        categoria: 'ciclismo',
        fechaInicio: DateTime(2030, 8, 1, 9),
        fechaFin: DateTime(2030, 8, 1, 12),
        areas: const <ZonaEvento>[],
        recorridos: const <ZonaEvento>[
          ZonaEvento(
            nombre: 'Paseo 8K',
            puntos: <PuntoGeo>[
              PuntoGeo(lat: 9.930, lng: -84.080),
              PuntoGeo(lat: 9.940, lng: -84.080),
            ],
          ),
        ],
      );

      await montarApp(
        tester,
        RecorridoEventoScreen(
          evento: ev,
          accessToken: '',
          directions: directions,
          voz: voz,
          posiciones: () => gps.stream,
        ),
      );
      await tester.pump();

      gps.add((lat: 9.910, lng: -84.080));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final Finder btnEmpezar = find.text('Empezar recorrido');
      expect(btnEmpezar, findsOneWidget);

      await tester.tap(btnEmpezar);
      await tester.pump();

      // Debe mostrar Pausar y Finalizar recorrido
      expect(find.text('Pausar'), findsOneWidget);
      expect(find.text('Finalizar recorrido'), findsOneWidget);

      // Probar pausa
      await tester.tap(find.text('Pausar'));
      await tester.pump();
      expect(find.text('Reanudar'), findsOneWidget);

      // Probar reanudar
      await tester.tap(find.text('Reanudar'));
      await tester.pump();
      expect(find.text('Pausar'), findsOneWidget);

      // Probar finalizar con confirmación
      await tester.tap(find.text('Finalizar recorrido'));
      await tester.pumpAndSettle();

      expect(find.text('¿Quieres terminar tu recorrido del evento?'), findsOneWidget);
      // Confirmar
      await tester.tap(find.text('Finalizar'));
      await tester.pumpAndSettle();

      expect(find.text('¡Has completado el recorrido!'), findsOneWidget);
      expect(find.text('Listo'), findsOneWidget);
    },
  );
}


