import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fit_quest_go/core/almacen_tokens.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_repositorio.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';

/// Monta [home] en una app de pruebas en español, con el host de notificaciones
/// (los avisos de exito / error se leen con `find.text`) y, si se da, la sesion.
Future<void> montarApp(
  WidgetTester tester,
  Widget home, {
  AuthRepositorio? auth,
}) async {
  tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
  tester.platformDispatcher.localeTestValue = const Locale('es');
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);

  final Widget app = MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (BuildContext context, Widget? child) =>
        NotificacionesHost(child: child ?? const SizedBox.shrink()),
    home: home,
  );
  await tester.pumpWidget(
    auth == null ? app : AuthScope(auth: auth, child: app),
  );
}

/// Sesion falsa: no toca la red ni el almacen de tokens.
class AuthFalso extends AuthRepositorio {
  AuthFalso({UsuarioSesion? usuario}) {
    _usuario = usuario;
  }

  UsuarioSesion? _usuario;
  final List<Map<String, Object?>> empresasRegistradas =
      <Map<String, Object?>>[];
  Object? errorAlRegistrar;
  int cierres = 0;

  @override
  UsuarioSesion? get usuario => _usuario;

  @override
  bool get autenticado => _usuario != null;

  @override
  Future<void> registrarEmpresa({
    required String nombreComercial,
    required String email,
    required String contrasena,
    required bool aceptaTerminos,
    String? telefono,
  }) async {
    if (errorAlRegistrar != null) throw errorAlRegistrar!;
    empresasRegistradas.add(<String, Object?>{
      'nombreComercial': nombreComercial,
      'email': email,
      'contrasena': contrasena,
      'aceptaTerminos': aceptaTerminos,
      'telefono': telefono,
    });
    _usuario = UsuarioSesion(
      id: 1,
      nombre: nombreComercial,
      email: email,
      rol: RolUsuario.empresa,
    );
    notifyListeners();
  }

  @override
  void actualizarNombre(String nombre) {
    final UsuarioSesion? actual = _usuario;
    if (actual == null) return;
    _usuario = UsuarioSesion(
      id: actual.id,
      nombre: nombre,
      email: actual.email,
      rol: actual.rol,
    );
    notifyListeners();
  }

  @override
  Future<void> cerrarSesion() async {
    cierres++;
    _usuario = null;
    notifyListeners();
  }
}

class SinTokens extends AlmacenTokens {
  @override
  Future<void> guardar({
    required String access,
    required String refresh,
  }) async {}

  @override
  Future<void> limpiar() async {}

  @override
  Future<String?> leerAccess() => Future<String?>.value(null);

  @override
  Future<String?> leerRefresh() => Future<String?>.value(null);
}

/// Una peticion que recibio el servidor falso.
class Peticion {
  Peticion(this.metodo, this.ruta, this.cuerpo);

  final String metodo;
  final String ruta;
  final Map<String, dynamic>? cuerpo;

  @override
  String toString() => '$metodo $ruta';
}

/// ApiClient contra un servidor falso. [responder] recibe la peticion y
/// devuelve el cuerpo JSON y el estado (por defecto 200).
ApiClient apiFalso(
  List<Peticion> registro,
  ({Object? cuerpo, int estado}) Function(Peticion) responder,
) {
  return ApiClient(
    client: MockClient((http.Request req) async {
      // Un cuerpo que no es JSON (p. ej. la foto, multipart) se registra sin cuerpo.
      Map<String, dynamic>? cuerpo;
      try {
        cuerpo = req.body.isEmpty
            ? null
            : jsonDecode(req.body) as Map<String, dynamic>;
      } catch (_) {
        cuerpo = null;
      }
      final Peticion p = Peticion(req.method, req.url.path, cuerpo);
      registro.add(p);
      final ({Object? cuerpo, int estado}) r = responder(p);
      return http.Response(
        r.cuerpo == null ? '' : jsonEncode(r.cuerpo),
        r.estado,
        headers: <String, String>{'content-type': 'application/json'},
      );
    }),
    baseUrl: 'http://test',
    tokens: SinTokens(),
  );
}
