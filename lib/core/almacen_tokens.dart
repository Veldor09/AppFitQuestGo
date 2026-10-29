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
  static const String _kBiometria = 'biometria_habilitada';
  static const String _kBioEmail = 'bio_email';
  static const String _kBioPassword = 'bio_password';
  static const String _kBioNombre = 'bio_nombre';

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

  // --- Credenciales para inicio de sesión con biometría ---

  Future<void> guardarCredencialBiometrica({
    required String email,
    required String password,
    String? nombre,
  }) async {
    try {
      await _almacen.write(key: _kBiometria, value: '1');
      await _almacen.write(key: _kBioEmail, value: email);
      await _almacen.write(key: _kBioPassword, value: password);
      if (nombre != null && nombre.isNotEmpty) {
        await _almacen.write(key: _kBioNombre, value: nombre);
      }
    } catch (_) {}
  }

  Future<void> borrarCredencialBiometrica() async {
    try {
      await _almacen.delete(key: _kBiometria);
      await _almacen.delete(key: _kBioEmail);
      await _almacen.delete(key: _kBioPassword);
      await _almacen.delete(key: _kBioNombre);
    } catch (_) {}
  }

  Future<bool> tieneCredencialBiometrica() async {
    try {
      final String? habilitada = await _almacen.read(key: _kBiometria);
      final String? email = await _almacen.read(key: _kBioEmail);
      final String? password = await _almacen.read(key: _kBioPassword);
      return habilitada == '1' &&
          email != null &&
          email.isNotEmpty &&
          password != null &&
          password.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<({String email, String password, String? nombre})?>
  leerCredencialBiometrica() async {
    try {
      final String? habilitada = await _almacen.read(key: _kBiometria);
      if (habilitada != '1') return null;
      final String? email = await _almacen.read(key: _kBioEmail);
      final String? password = await _almacen.read(key: _kBioPassword);
      final String? nombre = await _almacen.read(key: _kBioNombre);
      if (email == null ||
          email.isEmpty ||
          password == null ||
          password.isEmpty) {
        return null;
      }
      return (email: email, password: password, nombre: nombre);
    } catch (_) {
      return null;
    }
  }

  Future<String?> leerEmailBiometrico() async {
    try {
      return await _almacen.read(key: _kBioEmail);
    } catch (_) {
      return null;
    }
  }

  Future<String?> leerNombreBiometrico() async {
    try {
      return await _almacen.read(key: _kBioNombre);
    } catch (_) {
      return null;
    }
  }

  /// Borra únicamente la sesión activa (tokens y usuario actual).
  /// Preserva la configuración de biometría para permitir futuros inicios con huella.
  Future<void> limpiar() async {
    try {
      await _almacen.delete(key: _kAccess);
      await _almacen.delete(key: _kRefresh);
      await _almacen.delete(key: _kUsuario);
    } catch (_) {}
  }
}
