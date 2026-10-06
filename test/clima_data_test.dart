import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fit_quest_go/core/almacen_tokens.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/clima/data/alerta_clima.dart';
import 'package:fit_quest_go/Modulos/clima/data/clima_api.dart';

class _SinTokens extends AlmacenTokens {
  @override
  Future<String?> leerAccess() => Future<String?>.value(null);

  @override
  Future<String?> leerRefresh() => Future<String?>.value(null);
}

ClimaApi _api(MockClientHandler handler) {
  return ClimaApi(
    ApiClient(
      client: MockClient(handler),
      baseUrl: 'http://test',
      tokens: _SinTokens(),
    ),
  );
}

Future<http.Response> _json(Object cuerpo, [int status = 200]) async {
  return http.Response(
    jsonEncode(cuerpo),
    status,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

void main() {
  group('AlertaClima.desdeJson', () {
    test('lee tipo, nivel, en cuantas horas y el valor', () {
      final AlertaClima? a = AlertaClima.desdeJson(<String, dynamic>{
        'tipo': 'calor',
        'nivel': 'peligro',
        'enHoras': 0,
        'valor': 41.5,
      });

      expect(a, isNotNull);
      expect(a!.tipo, TipoClima.calor);
      expect(a.nivel, NivelClima.peligro);
      expect(a.enHoras, 0);
      expect(a.valor, 41.5);
      expect(a.esPeligro, isTrue);
    });

    test('el valor puede ser entero o faltar (tormenta)', () {
      final AlertaClima? lluvia = AlertaClima.desdeJson(<String, dynamic>{
        'tipo': 'lluvia',
        'nivel': 'precaucion',
        'enHoras': 1,
        'valor': 12,
      });
      final AlertaClima? tormenta = AlertaClima.desdeJson(<String, dynamic>{
        'tipo': 'tormenta',
        'nivel': 'peligro',
        'enHoras': 2,
        'valor': null,
      });

      expect(lluvia!.valor, 12.0);
      expect(lluvia.esPeligro, isFalse);
      expect(tormenta!.valor, isNull);
    });

    test('un tipo o nivel que esta app no conoce se ignora (null)', () {
      expect(
        AlertaClima.desdeJson(<String, dynamic>{
          'tipo': 'granizo',
          'nivel': 'peligro',
          'enHoras': 0,
        }),
        isNull,
      );
      expect(
        AlertaClima.desdeJson(<String, dynamic>{
          'tipo': 'lluvia',
          'nivel': 'catastrofe',
          'enHoras': 0,
        }),
        isNull,
      );
    });
  });

  group('ClimaApi.alertas', () {
    test('pide las alertas de la zona con lat y lng', () async {
      late http.Request recibida;
      final ClimaApi api = _api((http.Request req) {
        recibida = req;
        return _json(<String, dynamic>{
          'alertas': <Object>[],
          'fuente': 'Open-Meteo',
          'actualizadoEn': '2026-10-06T12:00:00.000Z',
        });
      });

      await api.alertas(lat: 9.9281, lng: -84.0907);

      expect(recibida.method, 'GET');
      expect(recibida.url.path, '/clima/alertas');
      expect(recibida.url.queryParameters, <String, String>{
        'lat': '9.9281',
        'lng': '-84.0907',
      });
    });

    test('devuelve las alertas, en el orden del servidor, y la fuente', () async {
      final ClimaApi api = _api(
        (http.Request _) => _json(<String, dynamic>{
          'alertas': <Map<String, dynamic>>[
            <String, dynamic>{'tipo': 'tormenta', 'nivel': 'peligro', 'enHoras': 2, 'valor': null},
            <String, dynamic>{'tipo': 'lluvia', 'nivel': 'precaucion', 'enHoras': 1, 'valor': 12},
          ],
          'fuente': 'Open-Meteo',
          'actualizadoEn': '2026-10-06T12:00:00.000Z',
        }),
      );

      final RespuestaClima r = await api.alertas(lat: 9.93, lng: -84.09);

      expect(r.alertas.map((AlertaClima a) => a.tipo), <TipoClima>[
        TipoClima.tormenta,
        TipoClima.lluvia,
      ]);
      expect(r.fuente, 'Open-Meteo');
    });

    test('descarta las alertas de un tipo desconocido sin fallar', () async {
      final ClimaApi api = _api(
        (http.Request _) => _json(<String, dynamic>{
          'alertas': <Map<String, dynamic>>[
            <String, dynamic>{'tipo': 'granizo', 'nivel': 'peligro', 'enHoras': 0},
            <String, dynamic>{'tipo': 'calor', 'nivel': 'precaucion', 'enHoras': 0, 'valor': 36},
          ],
          'fuente': 'Open-Meteo',
        }),
      );

      final RespuestaClima r = await api.alertas(lat: 9.93, lng: -84.09);

      expect(r.alertas.single.tipo, TipoClima.calor);
    });

    test('un 503 (proveedor caido) sube como ApiException', () async {
      final ClimaApi api = _api(
        (http.Request _) => _json(<String, dynamic>{'message': 'no disponible'}, 503),
      );

      await expectLater(
        api.alertas(lat: 9.93, lng: -84.09),
        throwsA(
          isA<ApiException>().having((ApiException e) => e.statusCode, 'status', 503),
        ),
      );
    });
  });
}
