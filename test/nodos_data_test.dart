import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fit_quest_go/core/almacen_tokens.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

class _SinTokens extends AlmacenTokens {
  @override
  Future<String?> leerAccess() => Future<String?>.value(null);

  @override
  Future<String?> leerRefresh() => Future<String?>.value(null);
}

Map<String, dynamic> _json([Map<String, dynamic> extra = const <String, dynamic>{}]) {
  return <String, dynamic>{
    'id': 5,
    'nombre': 'Fuente',
    'categoria': 'agua',
    'lat': 9.9,
    'lng': -84.0,
    'estado': 'Pendiente',
    'descripcion': null,
    'creadoPor': <String, dynamic>{'id': 3, 'nombreUser': 'Ana'},
    ...extra,
  };
}

NodoApi _api(MockClientHandler handler) {
  return NodoApi(
    ApiClient(
      client: MockClient(handler),
      baseUrl: 'http://test',
      tokens: _SinTokens(),
    ),
  );
}

Future<http.Response> Function(http.Request) _responderJson(
  Object cuerpo, [
  int status = 200,
]) {
  return (http.Request req) async => http.Response(
    jsonEncode(cuerpo),
    status,
    headers: <String, String>{'content-type': 'application/json'},
  );
}

void main() {
  group('Nodo.fromJson', () {
    test('lee categoriaOtro y conFoto', () {
      final Nodo n = Nodo.fromJson(
        _json(<String, dynamic>{
          'categoria': 'otro',
          'categoriaOtro': 'Zona de picnic',
          'conFoto': true,
        }),
      );
      expect(n.categoria, 'otro');
      expect(n.categoriaOtro, 'Zona de picnic');
      expect(n.conFoto, isTrue);
    });

    test('sin esos campos (backend sin migrar) usa null / false', () {
      final Nodo n = Nodo.fromJson(_json());
      expect(n.categoriaOtro, isNull);
      expect(n.conFoto, isFalse);
    });

    test('lee quien lo propuso (id), el recuento de votos y mi voto', () {
      final Nodo n = Nodo.fromJson(
        _json(<String, dynamic>{
          'estado': 'Aprobado',
          'confirmaciones': 3,
          'obsoletos': 1,
          'miVoto': 'confirmar',
        }),
      );
      expect(n.creadoPorId, 3);
      expect(n.confirmaciones, 3);
      expect(n.obsoletos, 1);
      expect(n.miVoto, 'confirmar');
    });

    test('sin votos (cola del admin) usa 0 y null', () {
      final Nodo n = Nodo.fromJson(_json());
      expect(n.confirmaciones, 0);
      expect(n.obsoletos, 0);
      expect(n.miVoto, isNull);
    });
  });

  group('NodoApi votos', () {
    Future<http.Request> votar(
      Future<Nodo> Function(NodoApi api) accion,
    ) async {
      late http.Request recibida;
      final NodoApi api = _api((http.Request req) async {
        recibida = req;
        return _responderJson(
          _json(<String, dynamic>{'estado': 'Aprobado', 'miVoto': 'confirmar'}),
        )(req);
      });
      await accion(api);
      return recibida;
    }

    test('confirmar manda tu posicion a PATCH /nodos/:id/confirmar', () async {
      final http.Request req = await votar(
        (NodoApi api) => api.confirmar(5, lat: 9.93, lng: -84.09),
      );

      expect(req.method, 'PATCH');
      expect(req.url.path, '/nodos/5/confirmar');
      expect(jsonDecode(req.body), <String, dynamic>{'lat': 9.93, 'lng': -84.09});
    });

    test('marcarObsoleto manda tu posicion a PATCH /nodos/:id/obsoleto', () async {
      final http.Request req = await votar(
        (NodoApi api) => api.marcarObsoleto(5, lat: 9.93, lng: -84.09),
      );

      expect(req.method, 'PATCH');
      expect(req.url.path, '/nodos/5/obsoleto');
      expect(jsonDecode(req.body), <String, dynamic>{'lat': 9.93, 'lng': -84.09});
    });

    test('devuelve el nodo con tu voto', () async {
      final NodoApi api = _api(
        _responderJson(_json(<String, dynamic>{
          'estado': 'Aprobado',
          'confirmaciones': 1,
          'miVoto': 'confirmar',
        })),
      );

      final Nodo n = await api.confirmar(5, lat: 9.93, lng: -84.09);

      expect(n.miVoto, 'confirmar');
      expect(n.confirmaciones, 1);
    });

    test('un 409 sube como ApiException con su status', () async {
      final NodoApi api = _api(
        _responderJson(<String, dynamic>{'message': 'Ya votaste este punto'}, 409),
      );

      await expectLater(
        api.marcarObsoleto(5, lat: 9.93, lng: -84.09),
        throwsA(
          isA<ApiException>().having((ApiException e) => e.statusCode, 'status', 409),
        ),
      );
    });
  });

  group('NodoApi.proponer', () {
    Future<Map<String, dynamic>> enviar({
      required String categoria,
      String? categoriaOtro,
    }) async {
      late Map<String, dynamic> cuerpo;
      final NodoApi api = _api((http.Request req) async {
        cuerpo = jsonDecode(req.body) as Map<String, dynamic>;
        return _responderJson(_json(), 201)(req);
      });
      await api.proponer(
        nombre: 'Fuente',
        categoria: categoria,
        categoriaOtro: categoriaOtro,
        lat: 9.9,
        lng: -84.0,
      );
      return cuerpo;
    }

    test('una categoria del catalogo viaja sola', () async {
      final Map<String, dynamic> cuerpo = await enviar(categoria: 'agua');
      expect(cuerpo['categoria'], 'agua');
      expect(cuerpo.containsKey('categoriaOtro'), isFalse);
    });

    test('"otro" lleva el texto recortado', () async {
      final Map<String, dynamic> cuerpo = await enviar(
        categoria: 'otro',
        categoriaOtro: ' Zona de picnic ',
      );
      expect(cuerpo['categoriaOtro'], 'Zona de picnic');
    });

    test('un categoriaOtro suelto se descarta', () async {
      final Map<String, dynamic> cuerpo = await enviar(
        categoria: 'agua',
        categoriaOtro: 'ignorame',
      );
      expect(cuerpo.containsKey('categoriaOtro'), isFalse);
    });
  });

  group('NodoApi fotos', () {
    final Uint8List foto = Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 1, 2, 3]);

    test('subirFoto manda un multipart al nodo y devuelve el nodo', () async {
      late http.Request recibida;
      final NodoApi api = _api((http.Request req) async {
        recibida = req;
        return _responderJson(_json(<String, dynamic>{'conFoto': true}), 201)(req);
      });

      final Nodo nodo = await api.subirFoto(5, foto);

      expect(recibida.method, 'POST');
      expect(recibida.url.path, '/nodos/5/foto');
      expect(recibida.headers['content-type'], startsWith('multipart/form-data'));
      final String cuerpo = latin1.decode(recibida.bodyBytes);
      expect(cuerpo, contains('name="foto"'));
      expect(cuerpo, contains('filename="foto.jpg"'));
      expect(nodo.conFoto, isTrue);
    });

    test('foto devuelve los bytes de la imagen', () async {
      final NodoApi api = _api((http.Request req) async {
        expect(req.method, 'GET');
        expect(req.url.path, '/nodos/5/foto');
        return http.Response.bytes(foto, 200, headers: <String, String>{
          'content-type': 'image/jpeg',
        });
      });

      expect(await api.foto(5), foto);
    });

    test('foto de un nodo sin foto lanza ApiException 404', () async {
      final NodoApi api = _api(_responderJson(<String, dynamic>{
        'message': 'El nodo 5 no tiene foto',
      }, 404));

      await expectLater(
        api.foto(5),
        throwsA(
          isA<ApiException>().having((ApiException e) => e.statusCode, 'status', 404),
        ),
      );
    });
  });
}
