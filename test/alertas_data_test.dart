import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fit_quest_go/core/almacen_tokens.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';

class _SinTokens extends AlmacenTokens {
  @override
  Future<String?> leerAccess() => Future<String?>.value(null);

  @override
  Future<String?> leerRefresh() => Future<String?>.value(null);
}

Map<String, dynamic> _json({
  int id = 7,
  String estado = 'Activa',
  Object? creadoPor = const <String, dynamic>{'id': 3, 'nombreUser': 'Ana'},
  String? miVoto,
}) {
  return <String, dynamic>{
    'id': id,
    'tipo': 'Bache',
    'gravedad': 'media',
    'lat': 9.9281,
    'lng': -84.0907,
    'estado': estado,
    'descripcion': null,
    'creadoPor': creadoPor,
    'miVoto': miVoto,
  };
}

void main() {
  group('Alerta.fromJson', () {
    test('lee el id del creador y el voto propio', () {
      final Alerta a = Alerta.fromJson(_json(miVoto: 'confirmar'));
      expect(a.creadoPorId, 3);
      expect(a.creadoPorNombre, 'Ana');
      expect(a.miVoto, 'confirmar');
    });

    test('sin creador ni voto, ambos quedan en null', () {
      final Alerta a = Alerta.fromJson(_json(creadoPor: null));
      expect(a.creadoPorId, isNull);
      expect(a.miVoto, isNull);
    });
  });

  group('Alerta.tipoOtro', () {
    test('se lee cuando viene (tipo "otro")', () {
      final Alerta a = Alerta.fromJson(<String, dynamic>{
        ..._json(),
        'tipo': 'otro',
        'tipoOtro': 'Poste inclinado',
      });
      expect(a.tipo, 'otro');
      expect(a.tipoOtro, 'Poste inclinado');
    });

    test('es null para un tipo del catalogo', () {
      expect(Alerta.fromJson(_json()).tipoOtro, isNull);
    });
  });

  group('AlertaApi.reportar', () {
    Future<Map<String, dynamic>> enviar({
      required String tipo,
      String? tipoOtro,
    }) async {
      late Map<String, dynamic> cuerpo;
      final MockClient client = MockClient((http.Request req) async {
        cuerpo = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(_json()),
          201,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final AlertaApi api = AlertaApi(
        ApiClient(client: client, baseUrl: 'http://test', tokens: _SinTokens()),
      );
      await api.reportar(
        tipo: tipo,
        tipoOtro: tipoOtro,
        gravedad: 'media',
        lat: 9.9,
        lng: -84.0,
      );
      return cuerpo;
    }

    test('un tipo del catalogo viaja solo, sin tipoOtro', () async {
      final Map<String, dynamic> cuerpo = await enviar(tipo: 'bache');
      expect(cuerpo['tipo'], 'bache');
      expect(cuerpo.containsKey('tipoOtro'), isFalse);
    });

    test('"otro" lleva el texto recortado', () async {
      final Map<String, dynamic> cuerpo = await enviar(
        tipo: 'otro',
        tipoOtro: '  Poste inclinado ',
      );
      expect(cuerpo['tipo'], 'otro');
      expect(cuerpo['tipoOtro'], 'Poste inclinado');
    });

    test('un tipoOtro suelto (tipo del catalogo) se descarta', () async {
      final Map<String, dynamic> cuerpo = await enviar(
        tipo: 'bache',
        tipoOtro: 'ignorame',
      );
      expect(cuerpo.containsKey('tipoOtro'), isFalse);
    });
  });

  group('AlertaApi votos', () {
    late String metodo;
    late String ruta;
    late Map<String, dynamic>? cuerpo;
    late AlertaApi api;
    late int statusRespuesta;

    setUp(() {
      statusRespuesta = 200;
      final MockClient client = MockClient((http.Request req) async {
        metodo = req.method;
        ruta = req.url.path;
        cuerpo = req.body.isEmpty
            ? null
            : jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(
            statusRespuesta == 200
                ? _json(miVoto: 'confirmar')
                : <String, dynamic>{'message': 'Ya votaste esta alerta'},
          ),
          statusRespuesta,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      api = AlertaApi(
        ApiClient(client: client, baseUrl: 'http://test', tokens: _SinTokens()),
      );
    });

    test('confirmar envia la posicion de quien vota', () async {
      final Alerta a = await api.confirmar(7, lat: 9.93, lng: -84.09);

      expect(metodo, 'PATCH');
      expect(ruta, '/alertas/7/confirmar');
      expect(cuerpo, <String, dynamic>{'lat': 9.93, 'lng': -84.09});
      expect(a.miVoto, 'confirmar');
    });

    test('desmentir envia la posicion de quien vota', () async {
      await api.desmentir(7, lat: 9.93, lng: -84.09);

      expect(metodo, 'PATCH');
      expect(ruta, '/alertas/7/desmentir');
      expect(cuerpo, <String, dynamic>{'lat': 9.93, 'lng': -84.09});
    });

    test('un 409 llega como ApiException con su codigo', () async {
      statusRespuesta = 409;
      await expectLater(
        api.confirmar(7, lat: 9.93, lng: -84.09),
        throwsA(
          isA<ApiException>().having((ApiException e) => e.statusCode, 'status', 409),
        ),
      );
    });
  });
}
