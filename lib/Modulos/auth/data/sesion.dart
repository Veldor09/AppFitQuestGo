/// Identificadores de rol tal como los define el backend (`RoleId`).
abstract final class RolUsuario {
  const RolUsuario._();

  static const int userNormal = 1;
  static const int empresa = 2;
  static const int admin = 3;

  static String etiqueta(int rol) {
    switch (rol) {
      case userNormal:
        return 'Usuario';
      case empresa:
        return 'Empresa';
      case admin:
        return 'Admin';
      default:
        return 'Rol $rol';
    }
  }
}

/// Usuario asociado a la sesion activa.
///
/// El backend devuelve dos formas distintas:
///  - `POST /auth/registro` y `/auth/inicio-sesion` -> incluye `nombre`.
///  - `GET /auth/yo` -> solo `{ id, email, rol }`.
/// Por eso [nombre] es tolerante a la ausencia del campo.
class UsuarioSesion {
  const UsuarioSesion({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
  });

  factory UsuarioSesion.fromJson(Map<String, dynamic> json) {
    return UsuarioSesion(
      id: json['id'] as int,
      nombre: (json['nombre'] as String?)?.trim() ?? '',
      email: json['email'] as String,
      rol: json['rol'] as int,
    );
  }

  final int id;
  final String nombre;
  final String email;
  final int rol;

  bool get esAdmin => rol == RolUsuario.admin;

  /// Cuenta de un comercio: publica eventos y nodos patrocinados.
  bool get esEmpresa => rol == RolUsuario.empresa;

  String get etiquetaRol => RolUsuario.etiqueta(rol);

  /// Iniciales para el avatar. Usa el nombre y, si no hay, el correo.
  String get iniciales {
    final String base = nombre.isNotEmpty ? nombre : email.split('@').first;
    final List<String> partes = base
        .trim()
        .split(RegExp(r'[\s._-]+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) {
      final String unico = partes.first;
      final int fin = unico.length >= 2 ? 2 : 1;
      return unico.substring(0, fin).toUpperCase();
    }
    return (partes.first.substring(0, 1) + partes[1].substring(0, 1))
        .toUpperCase();
  }
}

class Sesion {
  const Sesion({
    required this.accessToken,
    required this.refreshToken,
    required this.usuario,
  });

  factory Sesion.fromJson(Map<String, dynamic> json) {
    return Sesion(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      usuario: UsuarioSesion.fromJson(json['usuario'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final String refreshToken;
  final UsuarioSesion usuario;
}
