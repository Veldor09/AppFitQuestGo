import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/patrocinio/application/proximidad_destacados.dart';

import 'helpers/datos_mapa.dart';

const PosicionGps _aqui = (lat: latBase, lng: lngBase);

// Un grado de latitud son ~111 km: 0.003 ~ 334 m, 0.008 ~ 890 m, 0.02 ~ 2,2 km.
Nodo _a() => nodoDePrueba(id: 1, nombre: 'Soda A', lat: latBase + 0.003, destacado: true);
Nodo _b() => nodoDePrueba(id: 2, nombre: 'Taller B', lat: latBase + 0.008, destacado: true);
Nodo _c() => nodoDePrueba(id: 3, nombre: 'Tienda C', lat: latBase + 0.02, destacado: true);
Nodo _d() => nodoDePrueba(id: 4, nombre: 'Agua D', lat: latBase + 0.001);

void main() {
  group('destacadoMasCercano', () {
    test('elige el destacado mas cercano dentro del radio e ignora lo que no es destacado', () {
      final DestacadoCercano? r = destacadoMasCercano(
        lat: latBase,
        lng: lngBase,
        nodos: <Nodo>[_d(), _b(), _a(), _c()],
        eventos: const <Evento>[],
      );

      expect(r?.clave, 'nodo:1');
      expect(r?.nombre, 'Soda A');
      expect(r?.metros, closeTo(334, 5));
    });

    test('mas alla del radio no hay nada', () {
      expect(
        destacadoMasCercano(
          lat: latBase,
          lng: lngBase,
          nodos: <Nodo>[_c()],
          eventos: const <Evento>[],
        ),
        isNull,
      );
    });

    test('los excluidos se saltan', () {
      final DestacadoCercano? r = destacadoMasCercano(
        lat: latBase,
        lng: lngBase,
        nodos: <Nodo>[_a(), _b()],
        eventos: const <Evento>[],
        excluidos: <String>{'nodo:1'},
      );
      expect(r?.clave, 'nodo:2');
    });

    test('un evento cuenta por el punto mas cercano de sus trazos y puede ganar', () {
      final Evento e = eventoDePrueba(
        id: 7,
        nombre: 'Carrera',
        destacado: true,
        recorridos: const <ZonaEvento>[
          ZonaEvento(
            nombre: 'R',
            puntos: <PuntoGeo>[
              PuntoGeo(lat: latBase + 0.002, lng: lngBase),
              PuntoGeo(lat: latBase + 0.05, lng: lngBase),
            ],
          ),
        ],
      );

      final DestacadoCercano? r = destacadoMasCercano(
        lat: latBase,
        lng: lngBase,
        nodos: <Nodo>[_a()],
        eventos: <Evento>[e],
      );

      expect(r?.tipo, 'evento');
      expect(r?.id, 7);
      expect(r?.metros, closeTo(222, 5));
    });
  });

  group('ProximidadDestacados', () {
    ProximidadDestacados armar(List<Nodo> nodos) {
      final ProximidadDestacados p = ProximidadDestacados();
      p.actualizarDestacables(nodos, const <Evento>[]);
      return p;
    }

    test('sin posicion no hay aviso', () {
      expect(armar(<Nodo>[_a()]).cercano, isNull);
    });

    test('con dos dentro del radio avisa el mas cercano y, al cerrarlo, el siguiente; uno cerrado no vuelve', () {
      // Review Focus 4
      final ProximidadDestacados p = armar(<Nodo>[_a(), _b()]);
      int cambios = 0;
      p.addListener(() => cambios++);

      p.alMoverse(_aqui);
      expect(p.cercano?.id, 1);
      p.cerrar();
      expect(p.cercano?.id, 2);
      p.cerrar();
      expect(p.cercano, isNull);
      p.alMoverse((lat: latBase + 0.0001, lng: lngBase));
      expect(p.cercano, isNull);
      expect(cambios, greaterThan(0));
    });

    test('si te alejas sin cerrarlo se va, y al volver no se repite en la sesion', () {
      final ProximidadDestacados p = armar(<Nodo>[_a()]);

      p.alMoverse(_aqui);
      expect(p.cercano?.id, 1);
      p.alMoverse((lat: latBase + 0.05, lng: lngBase));
      expect(p.cercano, isNull);
      p.alMoverse(_aqui);
      expect(p.cercano, isNull);
    });

    test('lo que deja de ser destacado (vencio el plan) desaparece', () {
      final ProximidadDestacados p = armar(<Nodo>[_a()]);
      p.alMoverse(_aqui);
      expect(p.cercano?.id, 1);

      p.actualizarDestacables(<Nodo>[nodoDePrueba(id: 1, lat: latBase + 0.003)], const <Evento>[]);

      expect(p.cercano, isNull);
    });
  });
}
