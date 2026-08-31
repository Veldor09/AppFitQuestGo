import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

class UsuariosApi {
  UsuariosApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Usuario>> list() async {
    final dynamic data = await _client.get('/usuarios');
    return (data as List<dynamic>)
        .map((e) => Usuario.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Usuario> getById(int id) async {
    final dynamic data = await _client.get('/usuarios/$id');
    return Usuario.fromJson(data as Map<String, dynamic>);
  }

  Future<Usuario> create({
    required String nombreUser,
    required String emailUser,
    required String passwordUserHash,
    required int idrol,
  }) async {
    final dynamic data = await _client.post('/usuarios', {
      'nombreUser': nombreUser,
      'emailUser': emailUser,
      'passwordUserHash': passwordUserHash,
      'idrol': idrol,
    });
    return Usuario.fromJson(data as Map<String, dynamic>);
  }

  Future<Usuario> update(int id, Map<String, dynamic> changes) async {
    final dynamic data = await _client.put('/usuarios/$id', changes);
    return Usuario.fromJson(data as Map<String, dynamic>);
  }

  Future<void> remove(int id) => _client.delete('/usuarios/$id');
}
