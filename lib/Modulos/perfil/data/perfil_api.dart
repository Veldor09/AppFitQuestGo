import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/perfil/data/insignia.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';

class PerfilApi {
  PerfilApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Trae de la base de datos los datos completos de la cuenta actual.
  Future<Usuario> miPerfil() async {
    final dynamic data = await _client.get('/auth/perfil');
    return Usuario.fromJson(data as Map<String, dynamic>);
  }

  /// Actualiza los datos del perfil del usuario (nombre, correo, contrasena e intereses).
  Future<Usuario> actualizarPerfil({
    required int id,
    required String nombreUser,
    required String emailUser,
    String? nuevaContrasena,
    List<String>? intereses,
    List<String>? actividades,
    String? unidad,
    bool? notificaciones,
    String? visibilidad,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'nombreUser': nombreUser,
      'emailUser': emailUser,
    };
    if (nuevaContrasena != null && nuevaContrasena.trim().isNotEmpty) {
      body['passwordUserHash'] = nuevaContrasena.trim();
    }
    if (intereses != null) {
      body['intereses'] = intereses;
    }
    if (actividades != null) {
      body['actividades'] = actividades;
    }
    if (unidad != null) {
      body['unidad'] = unidad;
    }
    if (notificaciones != null) {
      body['notificaciones'] = notificaciones;
    }
    if (visibilidad != null) {
      body['visibilidad'] = visibilidad;
    }

    try {
      final dynamic data = await _client.put('/usuarios/$id', body);
      return Usuario.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      // Si /usuarios/:id esta restringido solo a admins o no existe, intentar /auth/perfil
      if (e.statusCode == 403 || e.statusCode == 404) {
        final dynamic data = await _client.put('/auth/perfil', body);
        return Usuario.fromJson(data as Map<String, dynamic>);
      }
      rethrow;
    }
  }
  /// PRF-01 / BDG-01 / NAV-07: Metricas acumuladas del usuario autenticado.
  Future<Map<String, dynamic>> estadisticasPropias() async {
    final dynamic data = await _client.get('/usuarios/yo/estadisticas');
    return Map<String, dynamic>.from(data as Map);
  }

  /// BDG-01: catalogo de insignias con el estado (desbloqueada o no) del
  /// usuario autenticado.
  Future<List<Insignia>> misInsignias() => _insignias('/insignias/mias');

  /// Insignias de otro usuario (perfil publico).
  Future<List<Insignia>> insigniasDeUsuario(int idUsuario) =>
      _insignias('/usuarios/$idUsuario/insignias');

  Future<List<Insignia>> _insignias(String path) async {
    final dynamic data = await _client.get(path);
    return (data as List<dynamic>)
        .map((dynamic e) => Insignia.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
