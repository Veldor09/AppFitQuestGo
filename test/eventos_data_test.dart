import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';

import 'helpers/montar.dart';

Map<String, dynamic> _json([
  Map<String, dynamic> extra = const <String, dynamic>{},
]) {
  return <String, dynamic>{
    'id': 3,
    'nombre': 'Caminata benefica',
    'descripcion': 'Por la escuela',
    'categoria': 'benefico',
    'fechaInicio': '2030-05-01T14:00:00.000Z',
    'fechaFin': '2030-05-01T17:00:00.000Z',
    'areas': <Map<String, dynamic>>[
      <String, dynamic>{
        'nombre': 'Salida',
        'puntos': <Map<String, double>>[
          <String, double>{'lat': 10, 'lng': -84},
          <String, double>{'lat': 10.001, 'lng': -84},
          <String, double>{'lat': 10.001, 'lng': -84.001},
        ],
      },
    ],
    'recorridos': <Map<String, dynamic>>[
      <String, dynamic>{
        'nombre': '5k',
        'puntos': <Map<String, double>>[
          <String, double>{'lat': 10, 'lng': -84},
          <String, double>{'lat': 10.002, 'lng': -84.002},
        ],
      },
    ],
    'creadoPor': <String, dynamic>{'id': 20, 'nombreUser': 'Cafe El Roble'},
    ...extra,
  };
}

EventoApi _api(List<Peticion> registro, [Object? cuerpo, int estado = 200]) {
  return EventoApi(
    apiFalso(
      registro,
      (Peticion _) => (cuerpo: cuerpo ?? <dynamic>[], estado: estado),
    ),
  );
}

void main() {
  group('Evento.fromJson', () {
    test('lee los datos, las fechas y los trazos', () {
      final Evento e = Evento.fromJson(_json());
      expect(e.id, 3);
      expect(e.nombre, 'Caminata benefica');
      expect(e.descripcion, 'Por la escuela');
      expect(e.categoria, 'benefico');
      expect(e.fechaInicio.toUtc(), DateTime.utc(2030, 5, 1, 14));
      expect(e.fechaFin.toUtc(), DateTime.utc(2030, 5, 1, 17));
      expect(e.areas.single.nombre, 'Salida');
      expect(e.areas.single.puntos, hasLength(3));
      expect(e.recorridos.single.puntos.last.lng, -84.002);
      expect(e.creadoPorNombre, 'Cafe El Roble');
      expect(e.creadoPorId, 20);
    });

    test('tolera areas y recorridos ausentes y descripcion nula', () {
      final Evento e = Evento.fromJson(
        _json(<String, dynamic>{
          'areas': null,
          'recorridos': null,
          'descripcion': null,
          'creadoPor': null,
        }),
      );
      expect(e.areas, isEmpty);
      expect(e.recorridos, isEmpty);
      expect(e.descripcion, isNull);
      expect(e.creadoPorNombre, isNull);
    });

    test('todosLosPuntos junta areas y recorridos', () {
      expect(Evento.fromJson(_json()).todosLosPuntos, hasLength(5));
    });
  });

  group('trazos rotulados con el nombre del evento', () {
    test(
      'cada area y cada recorrido lleva el nombre del evento, no el suyo',
      () {
        final Evento e = Evento.fromJson(_json());
        expect(e.areas.single.nombre, 'Salida'); // el interno no cambia
        expect(e.areasRotuladas.single.nombre, 'Caminata benefica');
        expect(e.recorridosRotulados.single.nombre, 'Caminata benefica');
      },
    );

    test('conservan los puntos y la cantidad de trazos', () {
      final Evento e = Evento.fromJson(_json());
      expect(e.areasRotuladas, hasLength(e.areas.length));
      expect(e.areasRotuladas.single.puntos, e.areas.single.puntos);
      expect(e.recorridosRotulados.single.puntos, e.recorridos.single.puntos);
    });

    test('un evento con varios trazos los rotula todos igual', () {
      final Evento e = Evento.fromJson(
        _json(<String, dynamic>{
          'areas': <Map<String, dynamic>>[
            <String, dynamic>{
              'nombre': 'A1',
              'puntos': <Map<String, double>>[
                <String, double>{'lat': 1, 'lng': 1},
                <String, double>{'lat': 2, 'lng': 2},
                <String, double>{'lat': 3, 'lng': 1},
              ],
            },
            <String, dynamic>{
              'nombre': 'A2',
              'puntos': <Map<String, double>>[
                <String, double>{'lat': 5, 'lng': 5},
                <String, double>{'lat': 6, 'lng': 6},
                <String, double>{'lat': 7, 'lng': 5},
              ],
            },
          ],
        }),
      );
      expect(e.areasRotuladas.map((z) => z.nombre), <String>[
        'Caminata benefica',
        'Caminata benefica',
      ]);
    });

    test(
      'cada trazo rotulado trae el id del evento (para abrirlo al tocarlo)',
      () {
        final Evento e = Evento.fromJson(_json());
        expect(e.areasRotuladas.single.eventoId, 3);
        expect(e.recorridosRotulados.single.eventoId, 3);
      },
    );

    test('el id del evento no viaja al servidor', () {
      final Evento e = Evento.fromJson(_json());
      expect(e.areasRotuladas.single.toJson().containsKey('eventoId'), isFalse);
    });

    test(
      'un trazo leido del servidor no trae id de evento hasta rotularlo',
      () {
        final Evento e = Evento.fromJson(_json());
        expect(e.areas.single.eventoId, isNull);
      },
    );

    test('sin trazos devuelve listas vacias', () {
      final Evento e = Evento.fromJson(
        _json(<String, dynamic>{'areas': null, 'recorridos': null}),
      );
      expect(e.areasRotuladas, isEmpty);
      expect(e.recorridosRotulados, isEmpty);
    });

    test(
      'devuelve listas nuevas en cada llamada, sin tocar las originales',
      () {
        final Evento e = Evento.fromJson(_json());
        expect(identical(e.areasRotuladas, e.areas), isFalse);
        expect(e.areas.single.nombre, 'Salida');
      },
    );
  });

  group('estado segun la fecha', () {
    final Evento e = Evento.fromJson(_json());

    test('antes de empezar es proximo', () {
      final DateTime antes = DateTime.utc(2030, 4, 30);
      expect(e.haComenzado(antes), isFalse);
      expect(e.enCurso(antes), isFalse);
      expect(e.haTerminado(antes), isFalse);
    });

    test('entre inicio y fin esta en curso (los limites cuentan)', () {
      expect(e.enCurso(DateTime.utc(2030, 5, 1, 14)), isTrue);
      expect(e.enCurso(DateTime.utc(2030, 5, 1, 15)), isTrue);
      expect(e.enCurso(DateTime.utc(2030, 5, 1, 17)), isTrue);
    });

    test('despues del fin esta terminado', () {
      final DateTime despues = DateTime.utc(2030, 5, 1, 17, 0, 1);
      expect(e.haTerminado(despues), isTrue);
      expect(e.enCurso(despues), isFalse);
    });
  });

  group('ZonaEvento.toJson', () {
    test('es lo que espera el backend', () {
      const ZonaEvento z = ZonaEvento(
        nombre: 'Salida',
        puntos: <PuntoGeo>[PuntoGeo(lat: 1, lng: 2), PuntoGeo(lat: 3, lng: 4)],
      );
      expect(z.toJson(), <String, dynamic>{
        'nombre': 'Salida',
        'puntos': <Map<String, double>>[
          <String, double>{'lat': 1, 'lng': 2},
          <String, double>{'lat': 3, 'lng': 4},
        ],
      });
    });
  });

  group('EventoApi', () {
    test('listar pide GET /eventos', () async {
      final List<Peticion> reg = <Peticion>[];
      final List<Evento> r = await _api(reg, <dynamic>[_json()]).listar();
      expect(reg.single.toString(), 'GET /eventos');
      expect(r.single.nombre, 'Caminata benefica');
    });

    test('mios pide GET /eventos/mios', () async {
      final List<Peticion> reg = <Peticion>[];
      await _api(reg).mios();
      expect(reg.single.toString(), 'GET /eventos/mios');
    });

    test('crear envia las fechas en UTC y los trazos', () async {
      final List<Peticion> reg = <Peticion>[];
      final Evento creado = await _api(reg, _json(), 201).crear(
        nombre: '  Caminata  ',
        descripcion: ' Por la escuela ',
        categoria: 'caminata',
        fechaInicio: DateTime.utc(2030, 5, 1, 14),
        fechaFin: DateTime.utc(2030, 5, 1, 17),
        areas: const <ZonaEvento>[
          ZonaEvento(
            nombre: 'Salida',
            puntos: <PuntoGeo>[
              PuntoGeo(lat: 10, lng: -84),
              PuntoGeo(lat: 10.1, lng: -84),
              PuntoGeo(lat: 10.1, lng: -84.1),
            ],
          ),
        ],
        recorridos: const <ZonaEvento>[],
      );
      expect(reg.single.toString(), 'POST /eventos');
      final Map<String, dynamic> c = reg.single.cuerpo!;
      expect(c['nombre'], 'Caminata');
      expect(c['descripcion'], 'Por la escuela');
      expect(c['categoria'], 'caminata');
      expect(c['fechaInicio'], '2030-05-01T14:00:00.000Z');
      expect(c['fechaFin'], '2030-05-01T17:00:00.000Z');
      expect((c['areas'] as List<dynamic>), hasLength(1));
      expect((c['recorridos'] as List<dynamic>), isEmpty);
      expect(creado.id, 3);
    });

    test('actualizar usa PATCH /eventos/:id', () async {
      final List<Peticion> reg = <Peticion>[];
      await _api(reg, _json()).actualizar(
        3,
        nombre: 'X',
        categoria: 'otro',
        fechaInicio: DateTime.utc(2030, 5, 1, 14),
        fechaFin: DateTime.utc(2030, 5, 1, 17),
        areas: const <ZonaEvento>[],
        recorridos: const <ZonaEvento>[],
      );
      expect(reg.single.toString(), 'PATCH /eventos/3');
    });

    test('eliminar usa DELETE /eventos/:id y acepta el 204 vacio', () async {
      final List<Peticion> reg = <Peticion>[];
      final EventoApi api = EventoApi(
        apiFalso(reg, (Peticion _) => (cuerpo: null, estado: 204)),
      );
      await api.eliminar(3);
      expect(reg.single.toString(), 'DELETE /eventos/3');
    });

    test(
      'un 400 del servidor llega como ApiException con su mensaje',
      () async {
        final List<Peticion> reg = <Peticion>[];
        final EventoApi api = _api(reg, <String, dynamic>{
          'message': 'La fecha de fin debe ser posterior',
        }, 400);
        await expectLater(
          api.crear(
            nombre: 'X',
            categoria: 'otro',
            fechaInicio: DateTime.utc(2030),
            fechaFin: DateTime.utc(2030),
            areas: const <ZonaEvento>[],
            recorridos: const <ZonaEvento>[],
          ),
          throwsA(
            isA<ApiException>()
                .having((ApiException e) => e.statusCode, 'status', 400)
                .having(
                  (ApiException e) => e.message,
                  'message',
                  contains('posterior'),
                ),
          ),
        );
      },
    );
  });
}
