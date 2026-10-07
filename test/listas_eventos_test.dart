import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/empresa/presentation/mis_eventos_screen.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/evento_detalle_screen.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/eventos_screen.dart';

import 'helpers/montar.dart';

/// "Hoy" para las pruebas: mediodia del 1 de mayo de 2030, hora local.
final DateTime _ahora = DateTime(2030, 5, 1, 12);

const List<PuntoGeo> _triangulo = <PuntoGeo>[
  PuntoGeo(lat: 10, lng: -84),
  PuntoGeo(lat: 10.001, lng: -84),
  PuntoGeo(lat: 10.001, lng: -84.001),
];

Evento _evento(
  int id,
  String nombre, {
  required DateTime inicio,
  required DateTime fin,
  String categoria = 'caminata',
  String? empresa = 'Cafe El Roble',
  String? descripcion,
  int areas = 1,
  int recorridos = 0,
}) => Evento(
  id: id,
  nombre: nombre,
  descripcion: descripcion,
  categoria: categoria,
  fechaInicio: inicio,
  fechaFin: fin,
  areas: <ZonaEvento>[
    for (int i = 0; i < areas; i++)
      ZonaEvento(nombre: 'Area ${i + 1}', puntos: _triangulo),
  ],
  recorridos: <ZonaEvento>[
    for (int i = 0; i < recorridos; i++)
      ZonaEvento(
        nombre: 'Recorrido ${i + 1}',
        puntos: const <PuntoGeo>[
          PuntoGeo(lat: 10, lng: -84),
          PuntoGeo(lat: 10.1, lng: -84.1),
        ],
      ),
  ],
  creadoPorNombre: empresa,
);

final Evento _enCurso = _evento(
  1,
  'Carrera en marcha',
  inicio: DateTime(2030, 5, 1, 8),
  fin: DateTime(2030, 5, 1, 18),
  categoria: 'carrera',
);
final Evento _proximo = _evento(
  2,
  'Caminata benefica',
  inicio: DateTime(2030, 5, 10, 8),
  fin: DateTime(2030, 5, 10, 11),
  categoria: 'benefico',
  areas: 2,
  recorridos: 1,
);
final Evento _terminado = _evento(
  3,
  'Ciclismo del domingo',
  inicio: DateTime(2030, 4, 20, 8),
  fin: DateTime(2030, 4, 20, 11),
  categoria: 'ciclismo',
);

class _EventoApiFalsa extends EventoApi {
  _EventoApiFalsa({
    this.vigentes = const <Evento>[],
    this.propios = const <Evento>[],
  });

  List<Evento> vigentes;
  List<Evento> propios;
  Object? errorAlListar;
  Object? errorAlEliminar;
  int listados = 0;
  final List<int> eliminados = <int>[];

  @override
  Future<List<Evento>> listar() async {
    listados++;
    if (errorAlListar != null) throw errorAlListar!;
    return vigentes;
  }

  @override
  Future<List<Evento>> mios() async {
    listados++;
    if (errorAlListar != null) throw errorAlListar!;
    return propios;
  }

  @override
  Future<void> eliminar(int id) async {
    if (errorAlEliminar != null) throw errorAlEliminar!;
    eliminados.add(id);
    propios = <Evento>[
      for (final Evento e in propios)
        if (e.id != id) e,
    ];
  }
}

Widget _mapaFalso(BuildContext _) => const Text('mapa-falso');

void main() {
  group('EventosScreen (deportista)', () {
    testWidgets(
      'separa los que estan en curso de los proximos y oculta los terminados',
      (WidgetTester tester) async {
        final _EventoApiFalsa api = _EventoApiFalsa(
          vigentes: <Evento>[_proximo, _enCurso, _terminado],
        );
        await montarApp(tester, EventosScreen(api: api, ahora: () => _ahora));
        await tester.pumpAndSettle();

        expect(find.text('Eventos'), findsOneWidget);
        expect(find.text('En curso'), findsWidgets);
        expect(find.text('Proximos'), findsWidgets);
        expect(find.text('Carrera en marcha'), findsOneWidget);
        expect(find.text('Caminata benefica'), findsOneWidget);
        // La lista del servidor ya excluye los terminados; si llegara uno, no se pinta.
        expect(find.text('Ciclismo del domingo'), findsNothing);
      },
    );

    testWidgets('el que esta en curso aparece antes que el proximo', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa(
        vigentes: <Evento>[_proximo, _enCurso],
      );
      await montarApp(tester, EventosScreen(api: api, ahora: () => _ahora));
      await tester.pumpAndSettle();

      final double yEnCurso = tester
          .getTopLeft(find.text('Carrera en marcha'))
          .dy;
      final double yProximo = tester
          .getTopLeft(find.text('Caminata benefica'))
          .dy;
      expect(yEnCurso, lessThan(yProximo));
    });

    testWidgets(
      'cada tarjeta muestra la empresa, la categoria y cuantos trazos tiene',
      (WidgetTester tester) async {
        final _EventoApiFalsa api = _EventoApiFalsa(
          vigentes: <Evento>[_proximo],
        );
        await montarApp(tester, EventosScreen(api: api, ahora: () => _ahora));
        await tester.pumpAndSettle();

        expect(find.text('Benefico · Cafe El Roble'), findsOneWidget);
        expect(find.text('Areas: 2 - Recorridos: 1'), findsOneWidget);
      },
    );

    testWidgets('sin eventos muestra el estado vacio', (
      WidgetTester tester,
    ) async {
      await montarApp(
        tester,
        EventosScreen(api: _EventoApiFalsa(), ahora: () => _ahora),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aun no hay eventos'), findsOneWidget);
    });

    testWidgets('si falla la carga ofrece reintentar y recupera', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa(vigentes: <Evento>[_enCurso])
        ..errorAlListar = ApiException(500, 'caido');
      await montarApp(tester, EventosScreen(api: api, ahora: () => _ahora));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo cargar'), findsOneWidget);

      api.errorAlListar = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Carrera en marcha'), findsOneWidget);
      expect(find.text('No se pudo cargar'), findsNothing);
    });
  });

  group('EventoDetalleScreen', () {
    testWidgets('muestra quien lo organiza, las fechas y cada trazo', (
      WidgetTester tester,
    ) async {
      final Evento e = _evento(
        4,
        'Caminata benefica',
        inicio: DateTime(2030, 5, 10, 8),
        fin: DateTime(2030, 5, 10, 11),
        categoria: 'benefico',
        descripcion: 'Por la escuela del pueblo',
        areas: 2,
        recorridos: 1,
      );
      await montarApp(
        tester,
        EventoDetalleScreen(
          evento: e,
          ahora: () => _ahora,
          mapaBuilder: _mapaFalso,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Caminata benefica'), findsOneWidget);
      expect(find.text('mapa-falso'), findsOneWidget);
      expect(find.text('Organiza Cafe El Roble'), findsOneWidget);
      expect(find.text('Por la escuela del pueblo'), findsOneWidget);
      expect(find.text('Area 1'), findsOneWidget);
      expect(find.text('Area 2'), findsOneWidget);
      expect(find.text('Recorrido 1'), findsOneWidget);
      expect(find.text('Proximo'.toUpperCase()), findsOneWidget);
    });

    testWidgets('un evento en curso lo dice; sin empresa no inventa una', (
      WidgetTester tester,
    ) async {
      final Evento e = _evento(
        5,
        'Sin dueño',
        inicio: DateTime(2030, 5, 1, 8),
        fin: DateTime(2030, 5, 1, 18),
        empresa: null,
      );
      await montarApp(
        tester,
        EventoDetalleScreen(
          evento: e,
          ahora: () => _ahora,
          mapaBuilder: _mapaFalso,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('En curso'.toUpperCase()), findsOneWidget);
      expect(find.textContaining('Organiza'), findsNothing);
    });

    testWidgets('tocar un evento de la lista abre su detalle', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa(vigentes: <Evento>[_enCurso]);
      await montarApp(tester, EventosScreen(api: api, ahora: () => _ahora));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Carrera en marcha'));
      await tester.pumpAndSettle();

      expect(find.byType(EventoDetalleScreen), findsOneWidget);
    });
  });

  group('MisEventosScreen (empresa)', () {
    testWidgets(
      'lista los suyos con los vigentes primero y los terminados al final',
      (WidgetTester tester) async {
        final _EventoApiFalsa api = _EventoApiFalsa(
          propios: <Evento>[_terminado, _proximo, _enCurso],
        );
        await montarApp(
          tester,
          MisEventosScreen(api: api, ahora: () => _ahora),
        );
        await tester.pumpAndSettle();

        final double yEnCurso = tester
            .getTopLeft(find.text('Carrera en marcha'))
            .dy;
        final double yProximo = tester
            .getTopLeft(find.text('Caminata benefica'))
            .dy;
        final double yTerminado = tester
            .getTopLeft(find.text('Ciclismo del domingo'))
            .dy;
        expect(yEnCurso, lessThan(yProximo));
        expect(yProximo, lessThan(yTerminado));
        expect(find.text('TERMINADO'), findsOneWidget);
      },
    );

    testWidgets('sin eventos invita a crear el primero', (
      WidgetTester tester,
    ) async {
      await montarApp(
        tester,
        MisEventosScreen(api: _EventoApiFalsa(), ahora: () => _ahora),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aun no tienes eventos'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('nuevo-evento')),
        findsOneWidget,
      );
    });

    testWidgets('"Nuevo evento" abre el editor sin evento', (
      WidgetTester tester,
    ) async {
      Evento? recibido = _enCurso;
      await montarApp(
        tester,
        MisEventosScreen(
          api: _EventoApiFalsa(),
          ahora: () => _ahora,
          editorBuilder: (BuildContext _, Evento? e) {
            recibido = e;
            return const Scaffold(body: Text('editor-falso'));
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('nuevo-evento')));
      await tester.pumpAndSettle();

      expect(find.text('editor-falso'), findsOneWidget);
      expect(recibido, isNull);
    });

    testWidgets('tocar un evento abre el editor con ese evento', (
      WidgetTester tester,
    ) async {
      Evento? recibido;
      await montarApp(
        tester,
        MisEventosScreen(
          api: _EventoApiFalsa(propios: <Evento>[_proximo]),
          ahora: () => _ahora,
          editorBuilder: (BuildContext _, Evento? e) {
            recibido = e;
            return const Scaffold(body: Text('editor-falso'));
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Caminata benefica'));
      await tester.pumpAndSettle();

      expect(recibido?.id, 2);
    });

    testWidgets(
      'al volver del editor con un evento guardado recarga la lista',
      (WidgetTester tester) async {
        final _EventoApiFalsa api = _EventoApiFalsa();
        await montarApp(
          tester,
          MisEventosScreen(
            api: api,
            ahora: () => _ahora,
            editorBuilder: (BuildContext ctx, Evento? _) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(ctx).pop(_proximo),
                child: const Text('guardar-falso'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(api.listados, 1);

        api.propios = <Evento>[_proximo];
        await tester.tap(find.byKey(const ValueKey<String>('nuevo-evento')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('guardar-falso'));
        await tester.pumpAndSettle();

        expect(api.listados, 2);
        expect(find.text('Caminata benefica'), findsOneWidget);
      },
    );

    testWidgets('volver del editor sin guardar no recarga', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      await montarApp(
        tester,
        MisEventosScreen(
          api: api,
          ahora: () => _ahora,
          editorBuilder: (BuildContext ctx, Evento? _) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('cancelar-falso'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('nuevo-evento')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cancelar-falso'));
      await tester.pumpAndSettle();

      expect(api.listados, 1);
    });

    testWidgets('eliminar pide confirmacion y luego borra y recarga', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa(
        propios: <Evento>[_proximo, _enCurso],
      );
      await montarApp(tester, MisEventosScreen(api: api, ahora: () => _ahora));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('eliminar-evento-2')));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar evento'), findsOneWidget);
      expect(api.eliminados, isEmpty); // todavia no

      await tester.tap(
        find.byKey(const ValueKey<String>('confirmar-eliminar')),
      );
      await tester.pumpAndSettle();

      expect(api.eliminados, <int>[2]);
      expect(find.text('Caminata benefica'), findsNothing);
      expect(find.text('Carrera en marcha'), findsOneWidget);
      expect(find.text('Evento eliminado'), findsOneWidget);
    });

    testWidgets('cancelar la confirmacion no borra nada', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa(propios: <Evento>[_proximo]);
      await montarApp(tester, MisEventosScreen(api: api, ahora: () => _ahora));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('eliminar-evento-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.eliminados, isEmpty);
      expect(find.text('Caminata benefica'), findsOneWidget);
    });

    testWidgets('si el servidor rechaza el borrado muestra su mensaje', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa(propios: <Evento>[_proximo])
        ..errorAlEliminar = ApiException(403, 'Este evento no te pertenece');
      await montarApp(tester, MisEventosScreen(api: api, ahora: () => _ahora));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('eliminar-evento-2')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('confirmar-eliminar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Este evento no te pertenece'), findsOneWidget);
      expect(find.text('Caminata benefica'), findsOneWidget);
    });

    testWidgets('si falla la carga ofrece reintentar', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa(propios: <Evento>[_proximo])
        ..errorAlListar = ApiException(500, 'caido');
      await montarApp(tester, MisEventosScreen(api: api, ahora: () => _ahora));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo cargar'), findsOneWidget);

      api.errorAlListar = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Caminata benefica'), findsOneWidget);
    });
  });

  group('MisEventosScreen con señal compartida (mapa + lista)', () {
    testWidgets(
      'una señal de afuera (se creo un evento en el mapa) recarga la lista',
      (WidgetTester tester) async {
        final _EventoApiFalsa api = _EventoApiFalsa();
        final ValueNotifier<int> senal = ValueNotifier<int>(0);
        addTearDown(senal.dispose);
        await montarApp(
          tester,
          MisEventosScreen(api: api, ahora: () => _ahora, senal: senal),
        );
        await tester.pumpAndSettle();
        expect(find.text('Aun no tienes eventos'), findsOneWidget);

        api.propios = <Evento>[_proximo];
        senal.value++;
        await tester.pumpAndSettle();

        expect(find.text('Caminata benefica'), findsOneWidget);
        expect(api.listados, 2);
      },
    );

    testWidgets('guardar en el editor suma la señal y recarga una sola vez', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      final ValueNotifier<int> senal = ValueNotifier<int>(0);
      addTearDown(senal.dispose);
      await montarApp(
        tester,
        MisEventosScreen(
          api: api,
          ahora: () => _ahora,
          senal: senal,
          editorBuilder: (BuildContext ctx, Evento? _) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(ctx).pop(_proximo),
              child: const Text('guardar-falso'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('nuevo-evento')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('guardar-falso'));
      await tester.pumpAndSettle();

      expect(senal.value, 1);
      expect(api.listados, 2); // la carga inicial + la de la señal
    });

    testWidgets('borrar un evento tambien avisa a las demas pantallas', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa(propios: <Evento>[_proximo]);
      final ValueNotifier<int> senal = ValueNotifier<int>(0);
      addTearDown(senal.dispose);
      await montarApp(
        tester,
        MisEventosScreen(api: api, ahora: () => _ahora, senal: senal),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('eliminar-evento-2')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('confirmar-eliminar')),
      );
      await tester.pumpAndSettle();

      expect(senal.value, 1);
      expect(find.text('Caminata benefica'), findsNothing);
    });

    testWidgets('al salir de la pantalla deja de escuchar la señal', (
      WidgetTester tester,
    ) async {
      final _EventoApiFalsa api = _EventoApiFalsa();
      final ValueNotifier<int> senal = ValueNotifier<int>(0);
      addTearDown(senal.dispose);
      await montarApp(
        tester,
        MisEventosScreen(api: api, ahora: () => _ahora, senal: senal),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      senal.value++; // no debe romper aunque ya no haya pantalla

      expect(tester.takeException(), isNull);
    });
  });
}
