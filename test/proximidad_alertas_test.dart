import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/alertas/application/proximidad_alertas.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';

const double _lat = 9.9281;
const double _lng = -84.0907;

/// Posiciones a `grados` de latitud al norte de la alerta de prueba
/// (0.0005 ~ 56 m, 0.0009 ~ 100 m, 0.0014 ~ 156 m, 0.01 ~ 1.1 km).
PosicionGps _alNorte(double grados) => (lat: _lat + grados, lng: _lng);

Alerta _alerta({
  int id = 1,
  double lat = _lat,
  double lng = _lng,
  String estado = 'Activa',
  int? creadoPorId = 99,
  String? miVoto,
  String tipo = 'Bache',
}) {
  return Alerta(
    id: id,
    tipo: tipo,
    gravedad: 'media',
    lat: lat,
    lng: lng,
    estado: estado,
    creadoPorId: creadoPorId,
    miVoto: miVoto,
  );
}

void main() {
  group('alertaParaAvisar', () {
    Alerta? elegir(
      List<Alerta> alertas, {
      PosicionGps? en,
      int? usuarioId = 1,
      Set<int> yaAvisadas = const <int>{},
    }) {
      final PosicionGps pos = en ?? _alNorte(0.0005);
      return alertaParaAvisar(
        lat: pos.lat,
        lng: pos.lng,
        alertas: alertas,
        usuarioId: usuarioId,
        yaAvisadas: yaAvisadas,
      );
    }

    test('devuelve la alerta si esta a menos de 100 m', () {
      expect(elegir(<Alerta>[_alerta()])?.id, 1);
    });

    test('ignora una alerta a mas de 100 m', () {
      expect(elegir(<Alerta>[_alerta()], en: _alNorte(0.0014)), isNull);
    });

    test('elige la mas cercana cuando hay varias dentro del radio', () {
      final Alerta lejos = _alerta(id: 1, lat: _lat + 0.0006);
      final Alerta cerca = _alerta(id: 2, lat: _lat + 0.0001);
      expect(elegir(<Alerta>[lejos, cerca], en: _alNorte(0))?.id, 2);
    });

    test('ignora las alertas propias', () {
      expect(elegir(<Alerta>[_alerta(creadoPorId: 1)], usuarioId: 1), isNull);
    });

    test('sin usuario conocido no excluye ninguna por autoria', () {
      expect(elegir(<Alerta>[_alerta(creadoPorId: 1)], usuarioId: null)?.id, 1);
    });

    test('ignora las que ya votaste', () {
      expect(elegir(<Alerta>[_alerta(miVoto: 'confirmar')]), isNull);
    });

    test('ignora las ya avisadas en esta sesion', () {
      expect(elegir(<Alerta>[_alerta()], yaAvisadas: <int>{1}), isNull);
    });

    test('ignora las que no estan activas', () {
      expect(elegir(<Alerta>[_alerta(estado: 'Resuelta')]), isNull);
    });

    test('sin alertas devuelve null', () {
      expect(elegir(<Alerta>[]), isNull);
    });
  });

  group('ProximidadAlertas', () {
    late StreamController<PosicionGps> gps;
    late List<({Alerta alerta, int metros})> avisos;
    late ProximidadAlertas proximidad;

    setUp(() {
      gps = StreamController<PosicionGps>();
      avisos = <({Alerta alerta, int metros})>[];
      proximidad = ProximidadAlertas(
        posiciones: gps.stream,
        usuarioId: () => 1,
        alAvisar: (Alerta alerta, int metros) =>
            avisos.add((alerta: alerta, metros: metros)),
      )..iniciar();
    });

    tearDown(() async {
      proximidad.dispose();
      await gps.close();
    });

    /// Entrega una posicion y deja correr el stream.
    Future<void> mover(PosicionGps pos) async {
      gps.add(pos);
      await Future<void>.delayed(Duration.zero);
    }

    test('no avisa mientras estas lejos', () async {
      proximidad.actualizarAlertas(<Alerta>[_alerta()]);
      await mover(_alNorte(0.01));

      expect(proximidad.alertaCercana, isNull);
      expect(avisos, isEmpty);
    });

    test('expone la posicion actual y avisa cada vez que cambia', () async {
      final List<PosicionGps?> vistas = <PosicionGps?>[];
      expect(proximidad.posicion.value, isNull);
      proximidad.posicion.addListener(
        () => vistas.add(proximidad.posicion.value),
      );

      await mover(_alNorte(0.01));
      await mover(_alNorte(0.02));

      expect(vistas, <PosicionGps>[_alNorte(0.01), _alNorte(0.02)]);
      expect(proximidad.posicion.value, _alNorte(0.02));
    });

    test('avisa una sola vez al entrar al radio', () async {
      proximidad.actualizarAlertas(<Alerta>[_alerta(tipo: 'Arbol caido')]);
      await mover(_alNorte(0.01));
      await mover(_alNorte(0.0005));
      await mover(_alNorte(0.0004));
      await mover(_alNorte(0.0003));

      expect(proximidad.alertaCercana?.tipo, 'Arbol caido');
      expect(avisos, hasLength(1));
      expect(avisos.single.alerta.id, 1);
      expect(avisos.single.metros, inInclusiveRange(50, 62));
    });

    test('si las alertas llegan despues del GPS, tambien avisa', () async {
      await mover(_alNorte(0.0005));
      expect(avisos, isEmpty);

      proximidad.actualizarAlertas(<Alerta>[_alerta()]);

      expect(avisos, hasLength(1));
    });

    test('descartar cierra el aviso y no lo repite en la sesion', () async {
      proximidad.actualizarAlertas(<Alerta>[_alerta()]);
      await mover(_alNorte(0.0005));
      proximidad.descartar();
      await mover(_alNorte(0.0004));

      expect(proximidad.alertaCercana, isNull);
      expect(avisos, hasLength(1));
    });

    test('al descartar, avisa la siguiente alerta cercana', () async {
      proximidad.actualizarAlertas(<Alerta>[
        _alerta(id: 1, lat: _lat + 0.0001),
        _alerta(id: 2, lat: _lat + 0.0003),
      ]);
      await mover(_alNorte(0));
      expect(proximidad.alertaCercana?.id, 1);

      proximidad.descartar();

      expect(proximidad.alertaCercana?.id, 2);
      expect(avisos.map((a) => a.alerta.id), <int>[1, 2]);
    });

    test('un solo aviso a la vez aunque haya dos alertas dentro del radio', () async {
      proximidad.actualizarAlertas(<Alerta>[
        _alerta(id: 1, lat: _lat + 0.0001),
        _alerta(id: 2, lat: _lat + 0.0003),
      ]);
      await mover(_alNorte(0));
      await mover(_alNorte(0.0001));

      expect(avisos, hasLength(1));
    });

    test('no avisa de tus propias alertas ni de las que ya votaste', () async {
      proximidad.actualizarAlertas(<Alerta>[
        _alerta(id: 1, creadoPorId: 1),
        _alerta(id: 2, miVoto: 'desmentir'),
      ]);
      await mover(_alNorte(0.0002));

      expect(avisos, isEmpty);
      expect(proximidad.alertaCercana, isNull);
    });

    test('el aviso se retira si te alejas mas de 150 m', () async {
      proximidad.actualizarAlertas(<Alerta>[_alerta()]);
      await mover(_alNorte(0.0005));
      expect(proximidad.alertaCercana, isNotNull);

      await mover(_alNorte(0.0012)); // ~133 m: aun puedes votar
      expect(proximidad.alertaCercana, isNotNull);

      await mover(_alNorte(0.0014)); // ~156 m: el servidor ya lo rechazaria
      expect(proximidad.alertaCercana, isNull);
    });

    test('el aviso se retira si la alerta desaparece de la lista', () async {
      proximidad.actualizarAlertas(<Alerta>[_alerta()]);
      await mover(_alNorte(0.0005));
      expect(proximidad.alertaCercana, isNotNull);

      proximidad.actualizarAlertas(<Alerta>[]);

      expect(proximidad.alertaCercana, isNull);
    });

    test('expone la ultima posicion para validar el voto', () async {
      expect(proximidad.ultimaPosicion, isNull);
      await mover(_alNorte(0.0005));
      expect(proximidad.ultimaPosicion, _alNorte(0.0005));
    });

    test('un error del stream (sin permiso) no rompe nada', () async {
      gps.addError(StateError('sin permiso'));
      await Future<void>.delayed(Duration.zero);

      proximidad.actualizarAlertas(<Alerta>[_alerta()]);
      expect(proximidad.alertaCercana, isNull);
    });

    group('alPrimeraPosicion', () {
      late StreamController<PosicionGps> otro;
      late List<PosicionGps> primeras;
      late ProximidadAlertas conAviso;

      setUp(() {
        otro = StreamController<PosicionGps>();
        primeras = <PosicionGps>[];
        conAviso = ProximidadAlertas(
          posiciones: otro.stream,
          usuarioId: () => 1,
          alAvisar: (Alerta alerta, int metros) {},
          alPrimeraPosicion: primeras.add,
        )..iniciar();
      });

      tearDown(() async {
        conAviso.dispose();
        await otro.close();
      });

      test('avisa de la primera posicion del GPS', () async {
        otro.add(_alNorte(0.01));
        await Future<void>.delayed(Duration.zero);

        expect(primeras, <PosicionGps>[_alNorte(0.01)]);
      });

      test('solo de la primera: las siguientes no se repiten', () async {
        otro.add(_alNorte(0.01));
        otro.add(_alNorte(0.02));
        otro.add(_alNorte(0.03));
        await Future<void>.delayed(Duration.zero);

        expect(primeras, hasLength(1));
        expect(conAviso.ultimaPosicion, _alNorte(0.03));
      });

      test('ya tiene la posicion guardada cuando avisa', () async {
        PosicionGps? vista;
        final StreamController<PosicionGps> tercero =
            StreamController<PosicionGps>();
        addTearDown(tercero.close);
        late final ProximidadAlertas p;
        p = ProximidadAlertas(
          posiciones: tercero.stream,
          usuarioId: () => 1,
          alAvisar: (Alerta alerta, int metros) {},
          alPrimeraPosicion: (PosicionGps _) => vista = p.ultimaPosicion,
        )..iniciar();
        addTearDown(p.dispose);

        tercero.add(_alNorte(0.01));
        await Future<void>.delayed(Duration.zero);

        expect(vista, _alNorte(0.01));
      });

      test('sin GPS no avisa de nada', () async {
        await Future<void>.delayed(Duration.zero);
        expect(primeras, isEmpty);
      });
    });

    test('dispose deja de escuchar el GPS', () async {
      final StreamController<PosicionGps> otro =
          StreamController<PosicionGps>();
      addTearDown(otro.close);
      final ProximidadAlertas efimera = ProximidadAlertas(
        posiciones: otro.stream,
        usuarioId: () => 1,
        alAvisar: (Alerta alerta, int metros) {},
      )..iniciar();
      expect(otro.hasListener, isTrue);

      efimera.dispose();

      expect(otro.hasListener, isFalse);
    });
  });
}
