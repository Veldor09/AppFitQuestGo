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
      nombre: json['nombre'] as String,
      email: json['email'] as String,
      rol: json['rol'] as int,
    );
  }

  final int id;
  final String nombre;
  final String email;
  final int rol;
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
