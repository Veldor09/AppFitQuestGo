import 'package:flutter_test/flutter_test.dart';

import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/patrocinio/data/destacable.dart';

import 'helpers/montar.dart';

Map<String, dynamic> _nodoJson([
  Map<String, dynamic> extra = const <String, dynamic>{},
]) => <String, dynamic>{
  'id': 1,
  'nombre': 'Soda',
  'categoria': 'comercio',
  'lat': 9.9,
  'lng': -84.0,
  'estado': 'Aprobado',
  ...extra,
};

Map<String, dynamic> _eventoJson([
  Map<String, dynamic> extra = const <String, dynamic>{},
]) => <String, dynamic>{
  'id': 2,
  'nombre': 'Carrera',
  'categoria': 'benefico',
  'fechaInicio': '2030-05-01T14:00:00.000Z',
  'fechaFin': '2030-05-01T17:00:00.000Z',
  ...extra,
};

void main() {
  group('destacado en los modelos', () {
    test('sin los campos nuevos (backend viejo) quedan en falso', () {
      final Nodo n = Nodo.fromJson(_nodoJson());
      expect(n.destacado, isFalse);
      expect(n.destacarActivado, isFalse);
      final Evento e = Evento.fromJson(_eventoJson());
      expect(e.destacado, isFalse);
      expect(e.destacarActivado, isFalse);
    });

    test('con los campos nuevos los lee', () {
      final Nodo n = Nodo.fromJson(
        _nodoJson(<String, dynamic>{'destacado': true, 'destacarActivado': true}),
      );
      expect(n.destacado, isTrue);
      expect(n.destacarActivado, isTrue);
      final Evento e = Evento.fromJson(
        _eventoJson(<String, dynamic>{'destacado': true, 'destacarActivado': true}),
      );
      expect(e.destacado, isTrue);
      expect(e.destacarActivado, isTrue);
    });

    test('Nodo.conDestacado cambia solo esas dos banderas', () {
      final Nodo n = Nodo.fromJson(
        _nodoJson(<String, dynamic>{
          'patrocinado': true,
          'miVoto': 'confirmar',
          'creadoPor': <String, dynamic>{'id': 3, 'nombreUser': 'Ana'},
        }),
      );
      final Nodo c = n.conDestacado(destacarActivado: true, destacado: true);
      expect(c.destacarActivado, isTrue);
      expect(c.destacado, isTrue);
      expect(c.id, n.id);
      expect(c.nombre, n.nombre);
      expect(c.patrocinado, isTrue);
      expect(c.creadoPorId, 3);
      expect(c.miVoto, 'confirmar');
    });
  });

  group('destacar en la API', () {
    test('NodoApi.destacar hace PATCH /nodos/:id/destacar y lee el resultado', () async {
      final List<Peticion> registro = <Peticion>[];
      final NodoApi api = NodoApi(
        apiFalso(
          registro,
          (Peticion _) => (
            cuerpo: <String, dynamic>{
              'id': 5,
              'destacarActivado': true,
              'destacado': true,
            },
            estado: 200,
          ),
        ),
      );

      final ResultadoDestacar r = await api.destacar(5, destacar: true);

      expect(registro.single.metodo, 'PATCH');
      expect(registro.single.ruta, '/nodos/5/destacar');
      expect(registro.single.cuerpo, <String, dynamic>{'destacar': true});
      expect(r, (destacarActivado: true, destacado: true));
    });

    test('EventoApi.destacar hace PATCH /eventos/:id/destacar', () async {
      final List<Peticion> registro = <Peticion>[];
      final EventoApi api = EventoApi(
        apiFalso(
          registro,
          (Peticion _) => (
            cuerpo: <String, dynamic>{
              'id': 7,
              'destacarActivado': false,
              'destacado': false,
            },
            estado: 200,
          ),
        ),
      );

      final ResultadoDestacar r = await api.destacar(7, destacar: false);

      expect(registro.single.ruta, '/eventos/7/destacar');
      expect(registro.single.cuerpo, <String, dynamic>{'destacar': false});
      expect(r, (destacarActivado: false, destacado: false));
    });
  });

  group('que es destacable', () {
    Nodo nodo(String categoria, {bool patrocinado = false}) => Nodo.fromJson(
      _nodoJson(<String, dynamic>{
        'categoria': categoria,
        'patrocinado': patrocinado,
      }),
    );

    test('comercio, restaurante y taller, y cualquier local de empresa', () {
      for (final String c in <String>['comercio', 'restaurante', 'taller']) {
        expect(nodoDestacable(nodo(c)), isTrue, reason: c);
      }
      expect(nodoDestacable(nodo('agua', patrocinado: true)), isTrue);
    });

    test('el resto de las categorias no', () {
      expect(nodoDestacable(nodo('agua')), isFalse);
      expect(nodoDestacable(nodo('otro')), isFalse);
    });

    test('soloDestacados deja los destacados en su orden', () {
      final Nodo a = Nodo.fromJson(_nodoJson(<String, dynamic>{'id': 1, 'destacado': true}));
      final Nodo b = Nodo.fromJson(_nodoJson(<String, dynamic>{'id': 2}));
      final Nodo c = Nodo.fromJson(_nodoJson(<String, dynamic>{'id': 3, 'destacado': true}));

      expect(soloDestacados(<Nodo>[a, b, c]), <Nodo>[a, c]);
    });

    test('un evento terminado no se destaca', () {
      final Evento e = Evento.fromJson(_eventoJson());
      expect(eventoDestacable(e, DateTime.utc(2030, 5, 1, 16)), isTrue);
      expect(eventoDestacable(e, DateTime.utc(2030, 5, 2)), isFalse);
    });
  });
}
