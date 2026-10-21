import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fit_quest_go/core/almacen_tokens.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_api.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';

class _TokensEnMemoria extends AlmacenTokens {
  String? _access;
  String? _refresh;
  String? _usuarioJson;

  @override
  Future<void> guardar({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> guardarUsuarioSesion(String usuarioJson) async {
    _usuarioJson = usuarioJson;
  }

  @override
  Future<String?> leerUsuarioSesion() async => _usuarioJson;

  @override
  Future<String?> leerAccess() async => _access;

  @override
  Future<String?> leerRefresh() async => _refresh;

  @override
  Future<void> limpiar() async {
    _access = null;
    _refresh = null;
    _usuarioJson = null;
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('cargarSesionGuardada() en modo offline mantiene la sesion activa y no borra tokens', () async {
    final _TokensEnMemoria tokens = _TokensEnMemoria();
    await tokens.guardar(access: 'token_valido', refresh: 'refresh_valido');
    await tokens.guardarUsuarioSesion(
      jsonEncode(const UsuarioSesion(
        id: 42,
        nombre: 'Carlos Trek',
        email: 'carlos@fitquest.co',
        rol: 1,
      ).toJson()),
    );

    // Cliente que falla con error de red (sin conexion / datos apagados)
    final MockClient client = MockClient((http.Request req) async {
      throw http.ClientException('Network is unreachable');
    });
    final AuthApi api = AuthApi(ApiClient(client: client, baseUrl: 'http://test', tokens: tokens));
    final AuthRepositorio auth = AuthRepositorio(api: api, tokens: tokens);

    await auth.cargarSesionGuardada();

    // La sesion debe estar activa gracias a los datos locales
    expect(auth.autenticado, isTrue);
    expect(auth.usuario?.id, 42);
    expect(auth.usuario?.nombre, 'Carlos Trek');
    expect(auth.usuario?.email, 'carlos@fitquest.co');

    // Los tokens NO deben haber sido borrados
    expect(await tokens.leerAccess(), 'token_valido');
    expect(await tokens.leerRefresh(), 'refresh_valido');
  });

  test('cargarSesionGuardada() cuando el token expira (401) limpia los tokens', () async {
    final _TokensEnMemoria tokens = _TokensEnMemoria();
    await tokens.guardar(access: 'token_expirado', refresh: 'refresh_expirado');
    await tokens.guardarUsuarioSesion(
      jsonEncode(const UsuarioSesion(
        id: 42,
        nombre: 'Carlos Trek',
        email: 'carlos@fitquest.co',
        rol: 1,
      ).toJson()),
    );

    // Backend responde 401 Unauthorized
    final MockClient client = MockClient((http.Request req) async {
      return http.Response('{"message": "Token invalido"}', 401, headers: {'content-type': 'application/json'});
    });
    final AuthApi api = AuthApi(ApiClient(client: client, baseUrl: 'http://test', tokens: tokens));
    final AuthRepositorio auth = AuthRepositorio(api: api, tokens: tokens);

    await auth.cargarSesionGuardada();

    // Sesion limpiada porque el servidor invalido el token
    expect(auth.autenticado, isFalse);
    expect(auth.usuario, isNull);
    expect(await tokens.leerAccess(), isNull);
  });

  test('iniciarSesion() persiste tokens y usuario para futuros arranques offline', () async {
    final _TokensEnMemoria tokens = _TokensEnMemoria();
    final MockClient client = MockClient((http.Request req) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'usuario': <String, dynamic>{
            'id': 10,
            'nombre': 'Elena Corredora',
            'email': 'elena@fitquest.co',
            'rol': 1,
          },
          'accessToken': 'acc_123',
          'refreshToken': 'ref_123',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final AuthApi api = AuthApi(ApiClient(client: client, baseUrl: 'http://test', tokens: tokens));
    final AuthRepositorio auth = AuthRepositorio(api: api, tokens: tokens);

    await auth.iniciarSesion(email: 'elena@fitquest.co', contrasena: '123456');

    expect(auth.autenticado, isTrue);
    expect(await tokens.leerAccess(), 'acc_123');
    expect(await tokens.leerRefresh(), 'ref_123');
    expect(await tokens.leerUsuarioSesion(), isNotNull);
    final String? userJson = await tokens.leerUsuarioSesion();
    final Map<String, dynamic> mapa = jsonDecode(userJson!) as Map<String, dynamic>;
    expect(mapa['nombre'], 'Elena Corredora');
  });
}
