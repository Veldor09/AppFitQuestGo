import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

class PerfilApi {
  PerfilApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Trae de la base de datos los datos completos de la cuenta actual.
  Future<Usuario> miPerfil() async {
    final dynamic data = await _client.get('/auth/perfil');
    return Usuario.fromJson(data as Map<String, dynamic>);
  }
}
