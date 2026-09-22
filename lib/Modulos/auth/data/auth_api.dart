import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';

class AuthApi {
  AuthApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Sesion> registrar({
    required String nombre,
    required String email,
    required String contrasena,
    required bool aceptaTerminos,
  }) async {
    final dynamic data = await _client.post('/auth/registro', {
      'nombre': nombre,
      'email': email,
      'contrasena': contrasena,
      'aceptaTerminos': aceptaTerminos,
    });
    return Sesion.fromJson(data as Map<String, dynamic>);
  }

  Future<Sesion> iniciarSesion({
    required String email,
    required String contrasena,
  }) async {
    final dynamic data = await _client.post('/auth/inicio-sesion', {
      'email': email,
      'contrasena': contrasena,
    });
    return Sesion.fromJson(data as Map<String, dynamic>);
  }

  Future<UsuarioSesion> obtenerPerfil() async {
    final dynamic data = await _client.get('/auth/yo');
    return UsuarioSesion.fromJson(data as Map<String, dynamic>);
  }

  Future<void> cerrarSesion(String? refreshToken) async {
    await _client.post('/auth/cerrar-sesion', {'refreshToken': ?refreshToken});
  }

  Future<void> olvideContrasena({required String email}) async {
    await _client.post('/auth/olvide-contrasena', {'email': email});
  }

  Future<void> restablecerContrasena({
    required String email,
    required String codigo,
    required String nuevaContrasena,
  }) async {
    await _client.post('/auth/restablecer-contrasena', {
      'email': email,
      'codigo': codigo,
      'nuevaContrasena': nuevaContrasena,
    });
  }
}
