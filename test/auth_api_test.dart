import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fit_quest_go/core/almacen_tokens.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_api.dart';

class _MockAlmacenTokens extends AlmacenTokens {
  @override
  Future<String?> leerAccess() => Future<String?>.value(null);

  @override
  Future<String?> leerRefresh() => Future<String?>.value(null);
}

void main() {
  test('registrar() envia aceptaTerminos en el cuerpo', () async {
    Map<String, dynamic>? cuerpoRecibido;
    final MockClient client = MockClient((http.Request req) async {
      cuerpoRecibido = jsonDecode(req.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'usuario': <String, dynamic>{
            'id': 1,
            'nombre': 'Ana',
            'email': 'ana@x.co',
            'rol': 1,
          },
          'accessToken': 'a',
          'refreshToken': 'r',
        }),
        201,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final AuthApi api = AuthApi(ApiClient(
      client: client,
      baseUrl: 'http://test',
      tokens: _MockAlmacenTokens(),
    ));

    await api.registrar(
      nombre: 'Ana',
      email: 'ana@x.co',
      contrasena: 'contrasena123',
      aceptaTerminos: true,
    );

    expect(cuerpoRecibido, isNotNull);
    expect(cuerpoRecibido!['aceptaTerminos'], true);
  });
}
