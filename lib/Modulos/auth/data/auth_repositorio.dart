import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:fit_quest_go/core/almacen_tokens.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/db/app_database.dart';
import 'package:fit_quest_go/core/db/daos/perfil_cache_dao.dart';
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

    // 1. Rehidratar inmediatamente la sesión local si existe
    final String? usuarioJson = await _tokens.leerUsuarioSesion();
    if (usuarioJson != null && usuarioJson.isNotEmpty) {
      try {
        _usuario = UsuarioSesion.fromJson(
          jsonDecode(usuarioJson) as Map<String, dynamic>,
        );
        notifyListeners();
      } catch (_) {}
    }

    // Respaldo secundario desde SQLite (perfil_cache) si no estaba en secure storage
    if (_usuario == null) {
      try {
        final cached = await PerfilCacheDao().leerUltimoUsuario();
        if (cached != null) {
          _usuario = UsuarioSesion(
            id: cached.id,
            nombre: cached.nombreUser,
            email: cached.emailUser,
            rol: cached.idrol,
          );
          notifyListeners();
        }
      } catch (_) {}
    }

    // 2. Intentar validar / refrescar con el backend en segundo plano
    try {
      final UsuarioSesion remoto = await _api.obtenerPerfil();
      _usuario = remoto;
      await _tokens.guardarUsuarioSesion(jsonEncode(remoto.toJson()));
      notifyListeners();
    } on ApiException catch (e) {
      // Únicamente si el backend responde 401 Unauthorized se invalida la sesión
      if (e.statusCode == 401) {
        await _tokens.limpiar();
        _usuario = null;
        notifyListeners();
      }
    } catch (_) {
      // Error de red (sin conexión a internet, timeout, etc.):
      // Mantenemos la sesión activa en modo offline. ¡NO se borran los tokens!
    }
  }

  Future<void> registrar({
    required String nombre,
    required String email,
    required String contrasena,
    required bool aceptaTerminos,
    List<String>? intereses,
    List<String>? actividades,
  }) async {
    final Sesion sesion = await _api.registrar(
      nombre: nombre,
      email: email,
      contrasena: contrasena,
      aceptaTerminos: aceptaTerminos,
      intereses: intereses,
      actividades: actividades,
    );
    await _persistir(sesion);
  }

  Future<void> registrarEmpresa({
    required String nombreComercial,
    required String email,
    required String contrasena,
    required bool aceptaTerminos,
    String? telefono,
  }) async {
    final Sesion sesion = await _api.registrarEmpresa(
      nombreComercial: nombreComercial,
      email: email,
      contrasena: contrasena,
      aceptaTerminos: aceptaTerminos,
      telefono: telefono,
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

  /// Cambia el nombre que muestra la sesion (p. ej. al editar el nombre
  /// comercial de una empresa) sin tener que iniciar sesion de nuevo.
  void actualizarNombre(String nombre) {
    final UsuarioSesion? actual = _usuario;
    if (actual == null) return;
    _usuario = UsuarioSesion(
      id: actual.id,
      nombre: nombre,
      email: actual.email,
      rol: actual.rol,
    );
    _tokens.guardarUsuarioSesion(jsonEncode(_usuario!.toJson()));
    notifyListeners();
  }

  Future<void> cerrarSesion() async {
    final String? refresh = await _tokens.leerRefresh();
    try {
      await _api.cerrarSesion(refresh);
    } catch (_) {}
    await _tokens.limpiar();
    try {
      await AppDatabase.instancia.limpiarDatosUsuario();
    } catch (_) {}
    _usuario = null;
    notifyListeners();
  }

  Future<void> _persistir(Sesion sesion) async {
    await _tokens.guardar(
      access: sesion.accessToken,
      refresh: sesion.refreshToken,
    );
    await _tokens.guardarUsuarioSesion(jsonEncode(sesion.usuario.toJson()));
    _usuario = sesion.usuario;
    notifyListeners();
  }
}
