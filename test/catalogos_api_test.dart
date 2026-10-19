import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fit_quest_go/core/almacen_tokens.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogo_item.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogos_api.dart';

class AlmacenTokensPrueba extends AlmacenTokens {
  @override
  Future<String?> leerAccess() async => 'token-de-prueba';

  @override
  Future<String?> leerRefresh() async => null;
}

void main() {
  const String baseUrl = 'http://localhost:3001';

  CatalogosApi crearApi(
    Future<http.Response> Function(http.Request) responder,
  ) {
    final ApiClient cliente = ApiClient(
      client: MockClient(responder),
      baseUrl: baseUrl,
      tokens: AlmacenTokensPrueba(),
    );

    return CatalogosApi(cliente);
  }

  Map<String, dynamic> elemento({
    int id = 1,
    String catalogo = 'alertas',
    String clave = 'bache',
    String nombre = 'Bache',
    bool activo = true,
  }) {
    return <String, dynamic>{
      'id': id,
      'catalogo': catalogo,
      'clave': clave,
      'nombre': nombre,
      'activo': activo,
    };
  }

  http.Response respuesta(Object datos, [int estado = 200]) {
    return http.Response(
      jsonEncode(datos),
      estado,
      headers: <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    );
  }

  test('convierte correctamente un elemento JSON', () {
    final CatalogoItem item = CatalogoItem.fromJson(elemento(activo: false));

    expect(item.id, 1);
    expect(item.catalogo, 'alertas');
    expect(item.clave, 'bache');
    expect(item.nombre, 'Bache');
    expect(item.activo, isFalse);
  });

  test('consulta el resumen de catalogos', () async {
    final CatalogosApi api = crearApi((http.Request request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/catalogos');
      expect(request.headers['authorization'], 'Bearer token-de-prueba');

      return respuesta(<Map<String, dynamic>>[
        <String, dynamic>{'catalogo': 'alertas', 'total': 10},
        <String, dynamic>{'catalogo': 'nodos', 'total': 9},
      ]);
    });

    final List<Map<String, dynamic>> catalogos = await api.listarCatalogos();

    expect(catalogos, hasLength(2));
    expect(catalogos.first['catalogo'], 'alertas');
  });

  test('lista elementos activos e inactivos', () async {
    final CatalogosApi api = crearApi((http.Request request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/catalogos/alertas');

      return respuesta(<Map<String, dynamic>>[
        elemento(),
        elemento(id: 2, clave: 'derrumbe', nombre: 'Derrumbe', activo: false),
      ]);
    });

    final List<CatalogoItem> items = await api.listarItems('alertas');

    expect(items, hasLength(2));
    expect(items.first.activo, isTrue);
    expect(items.last.activo, isFalse);
  });

  test('consulta solamente elementos activos', () async {
    final CatalogosApi api = crearApi((http.Request request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/catalogos/alertas/activos');

      return respuesta(<Map<String, dynamic>>[elemento()]);
    });

    final List<CatalogoItem> items = await api.listarItemsActivos('alertas');

    expect(items, hasLength(1));
    expect(items.single.activo, isTrue);
  });

  test('crea un elemento con clave y nombre', () async {
    final CatalogosApi api = crearApi((http.Request request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/catalogos/alertas');

      final Map<String, dynamic> cuerpo =
          jsonDecode(request.body) as Map<String, dynamic>;

      expect(cuerpo['clave'], 'nuevo_tipo');
      expect(cuerpo['nombre'], 'Nuevo tipo');

      return respuesta(
        elemento(id: 30, clave: 'nuevo_tipo', nombre: 'Nuevo tipo'),
        201,
      );
    });

    final CatalogoItem creado = await api.crearItem(
      catalogo: 'alertas',
      clave: ' nuevo_tipo ',
      nombre: ' Nuevo tipo ',
    );

    expect(creado.id, 30);
    expect(creado.clave, 'nuevo_tipo');
    expect(creado.activo, isTrue);
  });

  test('edita nombre y estado de un elemento', () async {
    final CatalogosApi api = crearApi((http.Request request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/catalogos/alertas/5');

      final Map<String, dynamic> cuerpo =
          jsonDecode(request.body) as Map<String, dynamic>;

      expect(cuerpo['nombre'], 'Nombre actualizado');
      expect(cuerpo['activo'], isFalse);

      return respuesta(
        elemento(id: 5, nombre: 'Nombre actualizado', activo: false),
      );
    });

    final CatalogoItem editado = await api.editarItem(
      catalogo: 'alertas',
      id: 5,
      nombre: ' Nombre actualizado ',
      activo: false,
    );

    expect(editado.nombre, 'Nombre actualizado');
    expect(editado.activo, isFalse);
  });

  test('desactiva un elemento conservando su nombre', () async {
    final CatalogoItem original = CatalogoItem.fromJson(
      elemento(id: 8, nombre: 'Accidente'),
    );

    final CatalogosApi api = crearApi((http.Request request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/catalogos/alertas/8');

      final Map<String, dynamic> cuerpo =
          jsonDecode(request.body) as Map<String, dynamic>;

      expect(cuerpo['nombre'], 'Accidente');
      expect(cuerpo['activo'], isFalse);

      return respuesta(elemento(id: 8, nombre: 'Accidente', activo: false));
    });

    final CatalogoItem actualizado = await api.cambiarEstado(original);

    expect(actualizado.activo, isFalse);
  });

  test('reactiva un elemento inactivo', () async {
    final CatalogoItem original = CatalogoItem.fromJson(
      elemento(id: 9, activo: false),
    );

    final CatalogosApi api = crearApi((http.Request request) async {
      final Map<String, dynamic> cuerpo =
          jsonDecode(request.body) as Map<String, dynamic>;

      expect(request.method, 'PATCH');
      expect(request.url.path, '/catalogos/alertas/9');
      expect(cuerpo['activo'], isTrue);

      return respuesta(elemento(id: 9, activo: true));
    });

    final CatalogoItem actualizado = await api.cambiarEstado(original);

    expect(actualizado.activo, isTrue);
  });

  test('propaga los errores HTTP del backend', () async {
    final CatalogosApi api = crearApi((http.Request request) async {
      return respuesta(<String, dynamic>{
        'message': 'No tienes permiso para este recurso',
      }, 403);
    });

    expect(
      () => api.listarItems('alertas'),
      throwsA(
        isA<ApiException>()
            .having((ApiException error) => error.statusCode, 'statusCode', 403)
            .having(
              (ApiException error) => error.message,
              'message',
              'No tienes permiso para este recurso',
            ),
      ),
    );
  });

  test('conserva tildes y caracteres UTF-8 al enviar y recibir JSON', () async {
    const String texto = 'Información, Ubicación, Descripción, ñ y ü';

    final ApiClient cliente = ApiClient(
      client: MockClient((http.Request request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/prueba-utf8');

        final Map<String, dynamic> cuerpo =
            jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, dynamic>;

        expect(cuerpo['texto'], texto);
        expect(request.bodyBytes, contains(0xC3));

        return http.Response.bytes(
          utf8.encode(jsonEncode(<String, dynamic>{'texto': texto})),
          200,
          headers: <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        );
      }),
      baseUrl: baseUrl,
      tokens: AlmacenTokensPrueba(),
    );

    final dynamic resultado = await cliente.post(
      '/prueba-utf8',
      <String, dynamic>{'texto': texto},
    );

    expect(resultado['texto'], texto);
    cliente.close();
  });
}
