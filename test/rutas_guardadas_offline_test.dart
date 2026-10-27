import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/db/daos/rutas_offline_dao.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/rutas_screen.dart';

import 'helpers/montar.dart';

class _RutaApiOfflineFalsa extends RutaApi {
  bool debeFallar = true;
  List<Ruta> remotas = <Ruta>[];

  @override
  Future<List<Ruta>> explorar({
    String? actividad,
    String? dificultad,
    String? query,
  }) async {
    if (debeFallar) throw Exception('Network error: Sin conexión');
    return <Ruta>[];
  }

  @override
  Future<List<Ruta>> misRutas() async {
    if (debeFallar) throw Exception('Network error: Sin conexión');
    return <Ruta>[];
  }

  @override
  Future<List<Ruta>> favoritas() async {
    if (debeFallar) {
      throw Exception('Network error: Sin conexión');
    }
    return remotas;
  }

  @override
  Future<Set<int>> favoritasIds() async {
    if (debeFallar) {
      throw Exception('Network error: Sin conexión');
    }
    return remotas.map((Ruta r) => r.id).toSet();
  }
}

class _RutasOfflineDaoFalso extends RutasOfflineDao {
  _RutasOfflineDaoFalso([List<Ruta>? iniciales])
      : rutas = iniciales != null ? List<Ruta>.from(iniciales) : <Ruta>[];

  final List<Ruta> rutas;

  @override
  Future<List<Ruta>> listar() async => List<Ruta>.from(rutas);

  @override
  Future<bool> estaGuardada(int idRemoto) async =>
      rutas.any((Ruta r) => r.id == idRemoto);
}

void main() {
  testWidgets(
    'RutasScreen en pestaña Guardadas sin internet muestra las rutas descargadas para offline',
    (WidgetTester tester) async {
      final _RutaApiOfflineFalsa api = _RutaApiOfflineFalsa()..debeFallar = true;
      final _RutasOfflineDaoFalso dao = _RutasOfflineDaoFalso(<Ruta>[
        const Ruta(
          id: 50,
          nombre: 'Sendero Los Robles Offline',
          actividades: <String>['senderismo'],
          dificultad: 'facil',
          distanciaKm: 4.2,
          puntos: <PuntoRuta>[
            PuntoRuta(lat: 9.93, lng: -84.08),
            PuntoRuta(lat: 9.94, lng: -84.09),
          ],
          estado: 'Publicada',
        ),
      ]);

      await montarApp(
        tester,
        RutasScreen(
          api: api,
          offlineDao: dao,
          initialTab: 2, // Pestaña Guardadas
          showBackButton: true,
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el banner offline
      expect(
        find.textContaining('Modo sin conexión: mostrando rutas guardadas'),
        findsOneWidget,
      );

      // Debe mostrar la ruta descargada offline
      expect(find.text('Sendero Los Robles Offline'), findsOneWidget);
    },
  );

  testWidgets(
    'RutasScreen en pestaña Guardadas sin internet y sin descargas muestra vacío sin rutas',
    (WidgetTester tester) async {
      final _RutaApiOfflineFalsa api = _RutaApiOfflineFalsa()..debeFallar = true;
      final _RutasOfflineDaoFalso dao = _RutasOfflineDaoFalso(<Ruta>[]);

      await montarApp(
        tester,
        RutasScreen(
          api: api,
          offlineDao: dao,
          initialTab: 2, // Pestaña Guardadas
          showBackButton: true,
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el estado vacío indicando que no hay rutas descargadas
      expect(find.text('Sin rutas guardadas'), findsOneWidget);
      expect(
        find.text('No tienes rutas descargadas para consultar sin conexión.'),
        findsOneWidget,
      );

      // No debe haber ninguna tarjeta de ruta
      expect(find.byType(ListView), findsNothing);
    },
  );

  testWidgets(
    'RutasScreen en pestaña Guardadas con internet muestra las rutas remotas de la cuenta',
    (WidgetTester tester) async {
      final _RutaApiOfflineFalsa api = _RutaApiOfflineFalsa()
        ..debeFallar = false
        ..remotas = <Ruta>[
          const Ruta(
            id: 99,
            nombre: 'Ruta Favorita en la Nube',
            actividades: <String>['ciclismo'],
            dificultad: 'moderada',
            distanciaKm: 12.0,
            puntos: <PuntoRuta>[
              PuntoRuta(lat: 9.93, lng: -84.08),
              PuntoRuta(lat: 9.95, lng: -84.10),
            ],
            estado: 'Publicada',
          ),
        ];
      final _RutasOfflineDaoFalso dao = _RutasOfflineDaoFalso(<Ruta>[]);

      await montarApp(
        tester,
        RutasScreen(
          api: api,
          offlineDao: dao,
          initialTab: 2,
          showBackButton: true,
        ),
      );
      await tester.pumpAndSettle();

      // No debe mostrar banner offline
      expect(
        find.textContaining('Modo sin conexión: mostrando rutas guardadas'),
        findsNothing,
      );

      // Debe mostrar la ruta remota
      expect(find.text('Ruta Favorita en la Nube'), findsOneWidget);
    },
  );
}
