import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations_es.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/home/application/busqueda_mapa.dart';
import 'package:fit_quest_go/Modulos/home/application/filtro_mapa.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

import 'helpers/datos_mapa.dart';

final AppLocalizations _l10n = AppLocalizationsEs();

List<ResultadoBusqueda> _buscar(
  String consulta, {
  FiltroMapa filtro = FiltroMapa.todo,
  List<Nodo> nodos = const <Nodo>[],
  List<Ruta> rutas = const <Ruta>[],
  List<Alerta> alertas = const <Alerta>[],
  List<Evento> eventos = const <Evento>[],
  PosicionGps? posicion,
  int limite = 8,
}) {
  return buscarEnMapa(
    consulta: consulta,
    filtro: filtro,
    l10n: _l10n,
    nodos: nodos,
    rutas: rutas,
    alertas: alertas,
    eventos: eventos,
    posicion: posicion,
    limite: limite,
  );
}

List<String> _titulos(List<ResultadoBusqueda> r) =>
    r.map((ResultadoBusqueda e) => e.titulo).toList();

void main() {
  group('buscarEnMapa · que coincide', () {
    test('una consulta vacia o de puros espacios no devuelve nada', () {
      final List<Nodo> nodos = <Nodo>[nodoDePrueba(nombre: 'Fuente')];

      expect(_buscar('', nodos: nodos), isEmpty);
      expect(_buscar('   ', nodos: nodos), isEmpty);
    });

    test('un punto de interes se encuentra por nombre, sin importar mayusculas ni tildes', () {
      final List<Nodo> nodos = <Nodo>[
        nodoDePrueba(id: 1, nombre: 'Café Río'),
        nodoDePrueba(id: 2, nombre: 'Fuente'),
      ];

      for (final String consulta in <String>['cafe', 'CAFÉ', 'cafe rio', 'río']) {
        expect(_titulos(_buscar(consulta, nodos: nodos)), <String>['Café Río'], reason: consulta);
      }
    });

    test('un punto de interes se encuentra por su categoria y la muestra como detalle', () {
      final List<ResultadoBusqueda> r = _buscar(
        'agua',
        nodos: <Nodo>[nodoDePrueba(nombre: 'Llave del parque', categoria: 'agua')],
      );

      expect(r, hasLength(1));
      expect(r.single.tipo, TipoResultado.poi);
      expect(r.single.titulo, 'Llave del parque');
      expect(r.single.detalle, 'Agua');
    });

    test('con la categoria "otro" se busca por lo que escribio quien lo propuso', () {
      final List<ResultadoBusqueda> r = _buscar(
        'hamaca',
        nodos: <Nodo>[
          nodoDePrueba(nombre: 'Rincon', categoria: 'otro', categoriaOtro: 'Hamacas'),
        ],
      );

      expect(_titulos(r), <String>['Rincon']);
      expect(r.single.detalle, 'Hamacas');
    });

    test('un punto de interes se encuentra por su descripcion', () {
      final List<ResultadoBusqueda> r = _buscar(
        'bicicletas',
        nodos: <Nodo>[
          nodoDePrueba(nombre: 'Taller Sur', descripcion: 'Repara bicicletas y llantas'),
        ],
      );

      expect(_titulos(r), <String>['Taller Sur']);
    });

    test('una ruta se encuentra por nombre y por actividad', () {
      final List<Ruta> rutas = <Ruta>[
        rutaDePrueba(
          id: 1,
          nombre: 'Sendero del Rio',
          actividades: const <String>['running', 'ciclismo'],
        ),
        rutaDePrueba(id: 2, nombre: 'Anillo', actividades: const <String>['caminata']),
      ];

      expect(_titulos(_buscar('sendero', rutas: rutas)), <String>['Sendero del Rio']);
      expect(_titulos(_buscar('ciclismo', rutas: rutas)), <String>['Sendero del Rio']);
    });

    test('de una ruta muestra sus actividades y su largo', () {
      final ResultadoBusqueda r = _buscar(
        'sendero',
        rutas: <Ruta>[
          rutaDePrueba(
            nombre: 'Sendero del Rio',
            actividades: const <String>['running', 'ciclismo'],
            distanciaKm: 5,
          ),
        ],
      ).single;

      expect(r.tipo, TipoResultado.ruta);
      expect(r.detalle, 'Running, Ciclismo · 5,0 km');
    });

    test('una alerta se encuentra por su tipo traducido y por su descripcion', () {
      final List<Alerta> alertas = <Alerta>[
        alertaDePrueba(id: 1, tipo: 'bache', gravedad: 'alta'),
        alertaDePrueba(id: 2, tipo: 'perro', descripcion: 'Ladra mucho cerca del puente'),
      ];

      final List<ResultadoBusqueda> porTipo = _buscar('bache', alertas: alertas);
      expect(porTipo, hasLength(1));
      expect(porTipo.single.tipo, TipoResultado.alerta);
      expect(porTipo.single.titulo, 'Bache');
      expect(porTipo.single.detalle, 'Gravedad Alta');
      expect((porTipo.single.origen as Alerta).id, 1);

      expect(_titulos(_buscar('puente', alertas: alertas)), <String>['Perro bravo']);
    });

    test('con el tipo "otro" se busca por lo que escribio quien reporto', () {
      final List<ResultadoBusqueda> r = _buscar(
        'poste',
        alertas: <Alerta>[alertaDePrueba(tipo: 'otro', tipoOtro: 'Poste inclinado')],
      );

      expect(_titulos(r), <String>['Poste inclinado']);
    });

    test('solo se buscan las alertas activas', () {
      final List<Alerta> alertas = <Alerta>[
        alertaDePrueba(id: 1, tipo: 'bache', estado: 'Resuelta'),
        alertaDePrueba(id: 2, tipo: 'bache', estado: 'Expirada'),
        alertaDePrueba(id: 3, tipo: 'bache'),
      ];

      final List<ResultadoBusqueda> r = _buscar('bache', alertas: alertas);

      expect(r.map((ResultadoBusqueda e) => (e.origen as Alerta).id), <int>[3]);
    });

    test('un evento se encuentra por nombre, por categoria y por la empresa que lo organiza', () {
      final List<Evento> eventos = <Evento>[
        eventoDePrueba(nombre: 'Gran fondo', categoria: 'ciclismo', empresa: 'Sport CR'),
      ];

      expect(_titulos(_buscar('fondo', eventos: eventos)), <String>['Gran fondo']);
      expect(_titulos(_buscar('ciclismo', eventos: eventos)), <String>['Gran fondo']);
      expect(_titulos(_buscar('sport', eventos: eventos)), <String>['Gran fondo']);
    });

    test('de un evento muestra su categoria y la empresa', () {
      final ResultadoBusqueda r = _buscar(
        'fondo',
        eventos: <Evento>[
          eventoDePrueba(nombre: 'Gran fondo', categoria: 'ciclismo', empresa: 'Sport CR'),
        ],
      ).single;

      expect(r.tipo, TipoResultado.evento);
      expect(r.detalle, 'Ciclismo · Sport CR');
    });

    test('un evento sin empresa muestra solo su categoria', () {
      final ResultadoBusqueda r = _buscar(
        'fondo',
        eventos: <Evento>[eventoDePrueba(nombre: 'Gran fondo', categoria: 'ciclismo')],
      ).single;

      expect(r.detalle, 'Ciclismo');
    });

    test('con varias palabras todas tienen que aparecer', () {
      final List<Nodo> nodos = <Nodo>[
        nodoDePrueba(id: 1, nombre: 'Fuente del parque'),
        nodoDePrueba(id: 2, nombre: 'Parque norte'),
      ];

      expect(_titulos(_buscar('parque fuente', nodos: nodos)), <String>['Fuente del parque']);
      expect(_buscar('parque cascada', nodos: nodos), isEmpty);
    });

    test('si nada coincide devuelve una lista vacia', () {
      expect(
        _buscar('zzz', nodos: <Nodo>[nodoDePrueba()], rutas: <Ruta>[rutaDePrueba()]),
        isEmpty,
      );
    });
  });

  group('buscarEnMapa · filtro', () {
    final List<Nodo> nodos = <Nodo>[nodoDePrueba(nombre: 'Parque norte')];
    final List<Ruta> rutas = <Ruta>[rutaDePrueba(nombre: 'Parque norte')];
    final List<Alerta> alertas = <Alerta>[
      alertaDePrueba(tipo: 'otro', tipoOtro: 'Parque norte cerrado'),
    ];
    final List<Evento> eventos = <Evento>[eventoDePrueba(nombre: 'Parque norte vivo')];

    Set<TipoResultado> tipos(FiltroMapa filtro) => _buscar(
      'parque',
      filtro: filtro,
      nodos: nodos,
      rutas: rutas,
      alertas: alertas,
      eventos: eventos,
    ).map((ResultadoBusqueda r) => r.tipo).toSet();

    test('con Todo busca en todo', () {
      expect(tipos(FiltroMapa.todo), TipoResultado.values.toSet());
    });

    test('cada filtro busca solo en lo suyo', () {
      expect(tipos(FiltroMapa.rutas), <TipoResultado>{TipoResultado.ruta});
      expect(tipos(FiltroMapa.alertas), <TipoResultado>{TipoResultado.alerta});
      expect(tipos(FiltroMapa.pois), <TipoResultado>{TipoResultado.poi});
      expect(tipos(FiltroMapa.eventos), <TipoResultado>{TipoResultado.evento});
    });
  });

  group('buscarEnMapa · orden y distancia', () {
    test('primero los que empiezan con la consulta, luego los que la contienen y al final los otros campos', () {
      final List<Nodo> nodos = <Nodo>[
        nodoDePrueba(id: 1, nombre: 'Llave', descripcion: 'cerca de la fuente'),
        nodoDePrueba(id: 2, nombre: 'La fuente de agua'),
        nodoDePrueba(id: 3, nombre: 'Fuente norte'),
      ];

      expect(
        _titulos(_buscar('fuente', nodos: nodos)),
        <String>['Fuente norte', 'La fuente de agua', 'Llave'],
      );
    });

    test('a igual coincidencia sale primero lo mas cercano, aunque su nombre vaya despues en el alfabeto', () {
      final List<Nodo> nodos = <Nodo>[
        nodoDePrueba(id: 1, nombre: 'Fuente a', lat: latBase + 0.01),
        nodoDePrueba(id: 2, nombre: 'Fuente b', lat: latBase + 0.001),
      ];

      final List<ResultadoBusqueda> r = _buscar(
        'fuente',
        nodos: nodos,
        posicion: (lat: latBase, lng: lngBase),
      );

      expect(_titulos(r), <String>['Fuente b', 'Fuente a']);
    });

    test('sin posicion los empatados salen por orden alfabetico', () {
      final List<Nodo> nodos = <Nodo>[
        nodoDePrueba(id: 1, nombre: 'Fuente b'),
        nodoDePrueba(id: 2, nombre: 'Fuente a'),
      ];

      expect(_titulos(_buscar('fuente', nodos: nodos)), <String>['Fuente a', 'Fuente b']);
    });

    test('con posicion dice a cuantos metros esta; sin ella no', () {
      final List<Nodo> nodos = <Nodo>[nodoDePrueba(lat: latBase + 0.001)];

      final ResultadoBusqueda con = _buscar(
        'fuente',
        nodos: nodos,
        posicion: (lat: latBase, lng: lngBase),
      ).single;
      final ResultadoBusqueda sin = _buscar('fuente', nodos: nodos).single;

      expect(con.metros, closeTo(111, 2));
      expect(sin.metros, isNull);
    });

    test('la distancia a una ruta es al punto mas cercano de su trazo', () {
      final Ruta ruta = rutaDePrueba(
        puntos: const <PuntoRuta>[
          PuntoRuta(lat: latBase + 0.05, lng: lngBase),
          PuntoRuta(lat: latBase + 0.002, lng: lngBase),
        ],
      );

      final ResultadoBusqueda r = _buscar(
        'sendero',
        rutas: <Ruta>[ruta],
        posicion: (lat: latBase, lng: lngBase),
      ).single;

      expect(r.metros, closeTo(222, 3));
    });

    test('un punto trae sus coordenadas para centrar el mapa', () {
      final ResultadoBusqueda r = _buscar(
        'fuente',
        nodos: <Nodo>[nodoDePrueba(lat: 9.95, lng: -84.1)],
      ).single;

      expect(r.lat, 9.95);
      expect(r.lng, -84.1);
    });

    test('no devuelve mas que el limite', () {
      final List<Nodo> nodos = <Nodo>[
        for (int i = 0; i < 20; i++) nodoDePrueba(id: i, nombre: 'Fuente $i'),
      ];

      expect(_buscar('fuente', nodos: nodos), hasLength(8));
      expect(_buscar('fuente', nodos: nodos, limite: 3), hasLength(3));
    });
  });
}
