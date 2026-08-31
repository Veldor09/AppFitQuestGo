import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AlmacenTokens {
  AlmacenTokens([FlutterSecureStorage? almacen])
    : _almacen = almacen ?? const FlutterSecureStorage();

  final FlutterSecureStorage _almacen;

  static const String _kAccess = 'access_token';
  static const String _kRefresh = 'refresh_token';

  Future<void> guardar({
    required String access,
    required String refresh,
  }) async {
    await _almacen.write(key: _kAccess, value: access);
    await _almacen.write(key: _kRefresh, value: refresh);
  }

  Future<void> guardarAccess(String access) {
    return _almacen.write(key: _kAccess, value: access);
  }

  Future<String?> leerAccess() => _almacen.read(key: _kAccess);

  Future<String?> leerRefresh() => _almacen.read(key: _kRefresh);

  Future<void> limpiar() async {
    await _almacen.delete(key: _kAccess);
    await _almacen.delete(key: _kRefresh);
  }
}
