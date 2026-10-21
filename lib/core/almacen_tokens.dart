import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AlmacenTokens {
  AlmacenTokens([FlutterSecureStorage? almacen])
    : _almacen =
          almacen ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
          );

  final FlutterSecureStorage _almacen;

  static const String _kAccess = 'access_token';
  static const String _kRefresh = 'refresh_token';
  static const String _kUsuario = 'usuario_sesion';

  Future<void> guardar({
    required String access,
    required String refresh,
  }) async {
    try {
      await _almacen.write(key: _kAccess, value: access);
      await _almacen.write(key: _kRefresh, value: refresh);
    } catch (_) {}
  }

  Future<void> guardarUsuarioSesion(String usuarioJson) async {
    try {
      await _almacen.write(key: _kUsuario, value: usuarioJson);
    } catch (_) {}
  }

  Future<String?> leerUsuarioSesion() async {
    try {
      return await _almacen.read(key: _kUsuario);
    } catch (_) {
      return null;
    }
  }

  Future<void> guardarAccess(String access) async {
    try {
      await _almacen.write(key: _kAccess, value: access);
    } catch (_) {}
  }

  Future<String?> leerAccess() async {
    try {
      return await _almacen.read(key: _kAccess);
    } catch (_) {
      return null;
    }
  }

  Future<String?> leerRefresh() async {
    try {
      return await _almacen.read(key: _kRefresh);
    } catch (_) {
      return null;
    }
  }

  Future<void> limpiar() async {
    try {
      await _almacen.delete(key: _kAccess);
      await _almacen.delete(key: _kRefresh);
      await _almacen.delete(key: _kUsuario);
    } catch (_) {}
  }
}
