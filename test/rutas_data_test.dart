import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fit_quest_go/core/almacen_tokens.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';

class _SinTokens extends AlmacenTokens {
  @override
  Future<String?> leerAccess() => Future<String?>.value(null);

  @override
  Future<String?> leerRefresh() => Future<String?>.value(null);
}

Map<String, dynamic> _json(Map<String, dynamic> extra) {
  return <String, dynamic>{
    'id': 1,
    'nombre': 'Vuelta',
    'dificultad': 'facil',
    'distanciaKm': '3.20',
    'puntos': <Map<String, double>>[
      <String, double>{'lat': 9.9, 'lng': -84.0},
    ],
    'estado': 'Privada',
    ...extra,
  };
}

void main() {
  group('Ruta.fromJson', () {
    test('lee las actividades como lista', () {
      final Ruta r = Ruta.fromJson(
        _json(<String, dynamic>{
          'actividades': <String>['running', 'ciclismo'],
        }),
      );
      expect(r.actividades, <String>['running', 'ciclismo']);
    });

    test('con un backend sin migrar (campo viejo "actividad") no se cae', () {
      final Ruta r = Ruta.fromJson(
        _json(<String, dynamic>{'actividad': 'Running'}),
      );
      expect(r.actividades, <String>['Running']);
    });

    test('sin ninguno de los dos queda vacia', () {
      expect(Ruta.fromJson(_json(<String, dynamic>{})).actividades, isEmpty);
    });
  });

  group('RutaApi.crear', () {
    test('envia la lista "actividades" y ya no "actividad"', () async {
      Map<String, dynamic>? cuerpo;
      final MockClient client = MockClient((http.Request req) async {
        cuerpo = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(
            _json(<String, dynamic>{
              'actividades': <String>['running', 'mtb'],
            }),
          ),
          201,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final RutaApi api = RutaApi(
        ApiClient(client: client, baseUrl: 'http://test', tokens: _SinTokens()),
      );

      final Ruta creada = await api.crear(
        nombre: 'Vuelta',
        actividades: <String>['running', 'mtb'],
        dificultad: 'facil',
        distanciaKm: 3.2,
        puntos: const <PuntoRuta>[
          PuntoRuta(lat: 9.9, lng: -84.0),
          PuntoRuta(lat: 9.91, lng: -84.01),
        ],
      );

      expect(cuerpo!['actividades'], <String>['running', 'mtb']);
      expect(cuerpo!.containsKey('actividad'), isFalse);
      expect(creada.actividades, <String>['running', 'mtb']);
    });
  });

  group('RutaApi.actualizar', () {
    test('envia PATCH /rutas/:id con los campos modificados', () async {
      String? metodo;
      String? urlPath;
      Map<String, dynamic>? cuerpo;

      final MockClient client = MockClient((http.Request req) async {
        metodo = req.method;
        urlPath = req.url.path;
        cuerpo = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(
            _json(<String, dynamic>{
              'id': 42,
              'nombre': 'Ruta Renovada',
              'actividades': <String>['hiking'],
              'dificultad': 'dificil',
            }),
          ),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final RutaApi api = RutaApi(
        ApiClient(client: client, baseUrl: 'http://test', tokens: _SinTokens()),
      );

      final Ruta actualizada = await api.actualizar(
        id: 42,
        nombre: 'Ruta Renovada',
        actividades: <String>['hiking'],
        dificultad: 'dificil',
      );

      expect(metodo, 'PATCH');
      expect(urlPath, '/rutas/42');
      expect(cuerpo!['nombre'], 'Ruta Renovada');
      expect(cuerpo!['dificultad'], 'dificil');
      expect(actualizada.id, 42);
      expect(actualizada.nombre, 'Ruta Renovada');
    });
  });
}
