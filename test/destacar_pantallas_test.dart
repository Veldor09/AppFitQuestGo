import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/mis_eventos_screen.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/mis_nodos_screen.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/ficha_evento.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/ficha_nodo.dart';
import 'package:fit_quest_go/Modulos/patrocinio/data/destacable.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/interruptor_destacar.dart';
import 'helpers/calificacion_falsa.dart';

import 'helpers/montar.dart';

const ValueKey<String> _claveInterruptor = ValueKey<String>('interruptor-destacar');
const ValueKey<String> _claveEtiqueta = ValueKey<String>('etiqueta-destacado');

class _NodoApiFalsa extends NodoApi {
  _NodoApiFalsa({this.propios = const <Nodo>[]});

  final List<Nodo> propios;
  final List<({int id, bool destacar})> llamadas = <({int id, bool destacar})>[];

  @override
  Future<List<Nodo>> misNodos() async => propios;

  @override
  Future<ResultadoDestacar> destacar(int id, {required bool destacar}) async {
    llamadas.add((id: id, destacar: destacar));
    return (destacarActivado: destacar, destacado: destacar);
  }
}

class _EventoApiFalsa extends EventoApi {
  _EventoApiFalsa(this.propios);

  final List<Evento> propios;

  @override
  Future<List<Evento>> mios() async => propios;
}

Nodo _nodo({
  int id = 9,
  String categoria = 'comercio',
  bool patrocinado = false,
  bool destacado = false,
  bool destacarActivado = false,
  int? creadoPorId = 3,
}) => Nodo(
  id: id,
  nombre: 'Soda $id',
  categoria: categoria,
  lat: 9.93,
  lng: -84.09,
  estado: 'Aprobado',
  creadoPorId: creadoPorId,
  patrocinado: patrocinado,
  destacado: destacado,
  destacarActivado: destacarActivado,
);

Evento _evento(int id, DateTime inicio, DateTime fin, {bool destacado = false}) =>
    Evento(
      id: id,
      nombre: 'Evento $id',
      categoria: 'caminata',
      fechaInicio: inicio,
      fechaFin: fin,
      areas: const <ZonaEvento>[
        ZonaEvento(
          nombre: 'Area 1',
          puntos: <PuntoGeo>[
            PuntoGeo(lat: 10, lng: -84),
            PuntoGeo(lat: 10.001, lng: -84),
            PuntoGeo(lat: 10.001, lng: -84.001),
          ],
        ),
      ],
      recorridos: const <ZonaEvento>[],
      destacado: destacado,
    );

final DateTime _ahora = DateTime(2030, 5, 1, 12);

void main() {
  usarCalificacionesFalsas();

  group('InterruptorDestacar', () {
    testWidgets('al tocarlo pide encender y queda encendido', (WidgetTester tester) async {
      bool? recibido;
      await montarApp(
        tester,
        Scaffold(
          body: InterruptorDestacar(
            activado: false,
            alCambiar: (bool v) async {
              recibido = v;
              return v;
            },
          ),
        ),
      );

      await tester.tap(find.byKey(_claveInterruptor));
      await tester.pumpAndSettle();

      expect(recibido, isTrue);
      expect(tester.widget<Switch>(find.byKey(_claveInterruptor)).value, isTrue);
      expect(find.text('Destacar en el mapa'), findsOneWidget);
    });

    testWidgets('si el servidor lo rechaza dice por que y vuelve a apagado', (
      WidgetTester tester,
    ) async {
      await montarApp(
        tester,
        Scaffold(
          body: InterruptorDestacar(
            activado: false,
            alCambiar: (bool v) async =>
                throw ApiException(403, 'DESTACAR_SIN_PLAN'),
          ),
        ),
      );

      await tester.tap(find.byKey(_claveInterruptor));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Necesitas un plan de patrocinio vigente para destacar.'),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(find.byKey(_claveInterruptor)).value, isFalse);
      await tester.pump(const Duration(seconds: 10));
    });

    test('mensajeErrorDestacar traduce cada codigo del servidor', () {
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('es'));
      expect(
        mensajeErrorDestacar(l10n, ApiException(403, 'DESTACAR_SIN_PLAN')),
        l10n.patrocinioSinPlan,
      );
      expect(
        mensajeErrorDestacar(l10n, ApiException(403, 'DESTACAR_TOPE')),
        l10n.patrocinioTope,
      );
      expect(
        mensajeErrorDestacar(l10n, ApiException(403, 'DESTACAR_NO_ELEGIBLE')),
        l10n.patrocinioNoElegible,
      );
      expect(
        mensajeErrorDestacar(l10n, ApiException(500, 'x')),
        l10n.patrocinioErrorDestacar,
      );
    });
  });

  group('FichaNodo', () {
    Future<void> abrir(
      WidgetTester tester,
      Nodo nodo,
      _NodoApiFalsa api, {
      int? usuarioId,
      ValueChanged<Nodo>? alDestacar,
    }) => montarApp(
      tester,
      Scaffold(
        body: FichaNodo(
          key: UniqueKey(),
          nodo: nodo,
          api: api,
          usuarioId: usuarioId,
          alDestacar: alDestacar,
        ),
      ),
    );

    testWidgets('el dueno de un comercio ve el interruptor', (WidgetTester tester) async {
      await abrir(tester, _nodo(), _NodoApiFalsa(), usuarioId: 3);
      expect(find.byKey(_claveInterruptor), findsOneWidget);
    });

    testWidgets('otra persona, o un punto que no se destaca, no lo ve', (
      WidgetTester tester,
    ) async {
      await abrir(tester, _nodo(), _NodoApiFalsa(), usuarioId: 4);
      expect(find.byKey(_claveInterruptor), findsNothing);

      await abrir(tester, _nodo(categoria: 'agua'), _NodoApiFalsa(), usuarioId: 3);
      expect(find.byKey(_claveInterruptor), findsNothing);
    });

    testWidgets('un punto destacado lleva la etiqueta "Destacado"', (
      WidgetTester tester,
    ) async {
      await abrir(tester, _nodo(destacado: true), _NodoApiFalsa(), usuarioId: 4);
      expect(find.byKey(_claveEtiqueta), findsOneWidget);
      await abrir(tester, _nodo(), _NodoApiFalsa(), usuarioId: 4);
      expect(find.byKey(_claveEtiqueta), findsNothing);
    });

    testWidgets('al encender llama al api, muestra la etiqueta y avisa con el punto nuevo', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa();
      Nodo? avisado;
      await abrir(
        tester,
        _nodo(),
        api,
        usuarioId: 3,
        alDestacar: (Nodo n) => avisado = n,
      );

      await tester.tap(find.byKey(_claveInterruptor));
      await tester.pumpAndSettle();

      expect(api.llamadas, <({int id, bool destacar})>[(id: 9, destacar: true)]);
      expect(find.byKey(_claveEtiqueta), findsOneWidget);
      expect(avisado?.destacado, isTrue);
      expect(avisado?.destacarActivado, isTrue);
    });
  });

  group('FichaEvento', () {
    testWidgets('lleva la etiqueta solo si esta destacado', (WidgetTester tester) async {
      final DateTime ini = DateTime(2030, 5, 2, 8);
      final DateTime fin = DateTime(2030, 5, 2, 12);
      await montarApp(
        tester,
        Scaffold(
          body: FichaEvento(
            evento: _evento(1, ini, fin, destacado: true),
            ahora: () => _ahora,
          ),
        ),
      );
      expect(find.byKey(_claveEtiqueta), findsOneWidget);

      await montarApp(
        tester,
        Scaffold(
          body: FichaEvento(evento: _evento(1, ini, fin), ahora: () => _ahora),
        ),
      );
      expect(find.byKey(_claveEtiqueta), findsNothing);
    });
  });

  group('listas del dueno', () {
    testWidgets('MisNodosScreen: el interruptor solo en lo que se puede destacar', (
      WidgetTester tester,
    ) async {
      final _NodoApiFalsa api = _NodoApiFalsa(
        propios: <Nodo>[
          _nodo(id: 1, patrocinado: true, categoria: 'agua'),
          _nodo(id: 2, categoria: 'agua'),
        ],
      );
      await montarApp(tester, MisNodosScreen(api: api));
      await tester.pumpAndSettle();

      expect(find.byKey(_claveInterruptor), findsOneWidget);
    });

    testWidgets('MisEventosScreen: el interruptor no sale en un evento terminado', (
      WidgetTester tester,
    ) async {
      final EventoApi api = _EventoApiFalsa(<Evento>[
        _evento(1, DateTime(2030, 5, 3, 8), DateTime(2030, 5, 3, 12)),
        _evento(2, DateTime(2030, 4, 1, 8), DateTime(2030, 4, 1, 12)),
      ]);
      await montarApp(tester, MisEventosScreen(api: api, ahora: () => _ahora));
      await tester.pumpAndSettle();

      expect(find.byKey(_claveInterruptor), findsOneWidget);
    });
  });
}
