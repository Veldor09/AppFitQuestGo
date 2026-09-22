import 'package:flutter/foundation.dart';

import 'package:fit_quest_go/core/almacen_tokens.dart';
import 'package:fit_quest_go/Modulos/auth/data/auth_api.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';

class AuthRepositorio extends ChangeNotifier {
  AuthRepositorio({AuthApi? api, AlmacenTokens? tokens})
    : _api = api ?? AuthApi(),
      _tokens = tokens ?? AlmacenTokens();

  final AuthApi _api;
  final AlmacenTokens _tokens;

  UsuarioSesion? _usuario;

  UsuarioSesion? get usuario => _usuario;

  bool get autenticado => _usuario != null;

  Future<void> cargarSesionGuardada() async {
    final String? access = await _tokens.leerAccess();
    if (access == null) return;
    try {
      _usuario = await _api.obtenerPerfil();
      notifyListeners();
    } catch (_) {
      await _tokens.limpiar();
    }
  }

  Future<void> registrar({
    required String nombre,
    required String email,
    required String contrasena,
    required bool aceptaTerminos,
  }) async {
    final Sesion sesion = await _api.registrar(
      nombre: nombre,
      email: email,
      contrasena: contrasena,
      aceptaTerminos: aceptaTerminos,
    );
    await _persistir(sesion);
  }

  Future<void> iniciarSesion({
    required String email,
    required String contrasena,
  }) async {
    final Sesion sesion = await _api.iniciarSesion(
      email: email,
      contrasena: contrasena,
    );
    await _persistir(sesion);
  }

  Future<void> cerrarSesion() async {
    final String? refresh = await _tokens.leerRefresh();
    try {
      await _api.cerrarSesion(refresh);
    } catch (_) {}
    await _tokens.limpiar();
    _usuario = null;
    notifyListeners();
  }

  Future<void> _persistir(Sesion sesion) async {
    await _tokens.guardar(
      access: sesion.accessToken,
      refresh: sesion.refreshToken,
    );
    _usuario = sesion.usuario;
    notifyListeners();
  }
}
