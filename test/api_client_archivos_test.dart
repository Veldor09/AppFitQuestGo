import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fit_quest_go/core/almacen_tokens.dart';
import 'package:fit_quest_go/core/api/api_client.dart';

/// Tokens en memoria, para ver la renovacion automatica ante un 401.
class _TokensEnMemoria extends AlmacenTokens {
  _TokensEnMemoria({this._access, this._refresh});

  String? _access;
  String? _refresh;

  @override
  Future<String?> leerAccess() async => _access;

  @override
  Future<String?> leerRefresh() async => _refresh;

  @override
  Future<void> guardar({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> limpiar() async {
    _access = null;
    _refresh = null;
  }
}

void main() {
  final Uint8List bytes = Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 9, 8, 7]);

  group('ApiClient.subirArchivo', () {
    test('arma un multipart con el archivo y las cabeceras de la app', () async {
      late http.Request recibida;
      final ApiClient api = ApiClient(
        client: MockClient((http.Request req) async {
          recibida = req;
          return http.Response(
            jsonEncode(<String, dynamic>{'ok': true}),
            201,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
        baseUrl: 'http://test',
        tokens: _TokensEnMemoria(access: 'tok'),
      );

      final dynamic resp = await api.subirArchivo(
        '/nodos/5/foto',
        campo: 'foto',
        bytes: bytes,
        nombreArchivo: 'foto.jpg',
      );

      expect(resp, <String, dynamic>{'ok': true});
      expect(recibida.method, 'POST');
      expect(recibida.url.toString(), 'http://test/nodos/5/foto');
      expect(recibida.headers['Authorization'], 'Bearer tok');
      expect(recibida.headers['X-Cliente-Movil'], '1');
      expect(recibida.headers['content-type'], startsWith('multipart/form-data'));
      final String cuerpo = latin1.decode(recibida.bodyBytes);
      expect(cuerpo, contains('name="foto"'));
      expect(cuerpo, contains('filename="foto.jpg"'));
      // Los bytes del archivo viajan tal cual dentro del cuerpo.
      expect(recibida.bodyBytes.length, greaterThan(bytes.length));
      expect(cuerpo, contains(latin1.decode(bytes)));
    });

    test('un error del servidor llega como ApiException con su mensaje', () async {
      final ApiClient api = ApiClient(
        client: MockClient((http.Request req) async => http.Response(
          jsonEncode(<String, dynamic>{'message': 'La foto debe ser JPEG, PNG o WebP'}),
          400,
          headers: <String, String>{'content-type': 'application/json'},
        )),
        baseUrl: 'http://test',
        tokens: _TokensEnMemoria(access: 'tok'),
      );

      await expectLater(
        api.subirArchivo('/nodos/5/foto', campo: 'foto', bytes: bytes, nombreArchivo: 'x.jpg'),
        throwsA(
          isA<ApiException>()
              .having((ApiException e) => e.statusCode, 'status', 400)
              .having((ApiException e) => e.message, 'message', contains('JPEG')),
        ),
      );
    });

    test('ante un 401 renueva el token y reintenta una vez', () async {
      final List<String> llamadas = <String>[];
      final _TokensEnMemoria tokens = _TokensEnMemoria(access: 'viejo', refresh: 'r1');
      final ApiClient api = ApiClient(
        client: MockClient((http.Request req) async {
          llamadas.add('${req.method} ${req.url.path} ${req.headers['Authorization']}');
          if (req.url.path == '/auth/renovar') {
            return http.Response(
              jsonEncode(<String, dynamic>{'accessToken': 'nuevo', 'refreshToken': 'r2'}),
              200,
              headers: <String, String>{'content-type': 'application/json'},
            );
          }
          if (req.headers['Authorization'] == 'Bearer viejo') {
            return http.Response('{"message":"expiro"}', 401);
          }
          return http.Response(
            jsonEncode(<String, dynamic>{'ok': true}),
            201,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }),
        baseUrl: 'http://test',
        tokens: tokens,
      );

      final dynamic resp = await api.subirArchivo(
        '/nodos/5/foto',
        campo: 'foto',
        bytes: bytes,
        nombreArchivo: 'foto.jpg',
      );

      expect(resp, <String, dynamic>{'ok': true});
      expect(llamadas, <String>[
        'POST /nodos/5/foto Bearer viejo',
        'POST /auth/renovar null',
        'POST /nodos/5/foto Bearer nuevo',
      ]);
    });
  });

  group('ApiClient.getBytes', () {
    test('devuelve los bytes tal cual y manda el token', () async {
      late http.Request recibida;
      final ApiClient api = ApiClient(
        client: MockClient((http.Request req) async {
          recibida = req;
          return http.Response.bytes(bytes, 200);
        }),
        baseUrl: 'http://test',
        tokens: _TokensEnMemoria(access: 'tok'),
      );

      expect(await api.getBytes('/nodos/5/foto'), bytes);
      expect(recibida.method, 'GET');
      expect(recibida.headers['Authorization'], 'Bearer tok');
    });

    test('un 404 lanza ApiException', () async {
      final ApiClient api = ApiClient(
        client: MockClient((http.Request req) async => http.Response(
          jsonEncode(<String, dynamic>{'message': 'sin foto'}),
          404,
          headers: <String, String>{'content-type': 'application/json'},
        )),
        baseUrl: 'http://test',
        tokens: _TokensEnMemoria(access: 'tok'),
      );

      await expectLater(
        api.getBytes('/nodos/5/foto'),
        throwsA(
          isA<ApiException>().having((ApiException e) => e.statusCode, 'status', 404),
        ),
      );
    });
  });
}
