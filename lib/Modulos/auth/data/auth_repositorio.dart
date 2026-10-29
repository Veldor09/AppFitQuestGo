import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:fit_quest_go/core/almacen_tokens.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/db/app_database.dart';
import 'package:fit_quest_go/core/db/daos/perfil_cache_dao.dart';
import 'package:fit_quest_go/core/push/servicio_push.dart';
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

  /// Consulta si el usuario tiene credenciales guardadas para iniciar sesión con huella.
  Future<bool> tieneCredencialBiometrica() async {
    return await _tokens.tieneCredencialBiometrica();
  }

  /// Retorna el correo asociado a la biometría (para mostrar en la pantalla de login).
  Future<String?> obtenerEmailBiometrico() async {
    return await _tokens.leerEmailBiometrico();
  }

  /// Retorna el nombre del usuario asociado a la biometría.
  Future<String?> obtenerNombreBiometrico() async {
    return await _tokens.leerNombreBiometrico();
  }

  /// Guarda de forma segura las credenciales para futuros inicios de sesión con huella.
  Future<void> guardarCredencialBiometrica({
    required String email,
    required String contrasena,
    String? nombre,
  }) async {
    await _tokens.guardarCredencialBiometrica(
      email: email,
      password: contrasena,
      nombre: nombre ?? _usuario?.nombre,
    );
    notifyListeners();
  }

  /// Desactiva y elimina las credenciales biométricas guardadas.
  Future<void> borrarCredencialBiometrica() async {
    await _tokens.borrarCredencialBiometrica();
    notifyListeners();
  }

  /// Inicia sesión utilizando las credenciales seguras asociadas a la huella digital.
  Future<void> iniciarSesionConBiometria() async {
    final cred = await _tokens.leerCredencialBiometrica();
    if (cred == null) {
      throw Exception('No hay credenciales guardadas para inicio biométrico.');
    }
    await iniciarSesion(
      email: cred.email,
      contrasena: cred.password,
    );
  }

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
    // Este telefono deja de recibir avisos de la cuenta. Va antes de borrar los
    // tokens (hace falta la sesion) y sin esperar de mas si no hay red.
    try {
      await ServicioPush.instancia.quitar().timeout(const Duration(seconds: 3));
    } catch (_) {}
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
