class Rol {
  const Rol({required this.idrol, required this.nombreRol});

  factory Rol.fromJson(Map<String, dynamic> json) {
    return Rol(
      idrol: json['idrol'] as int,
      nombreRol: json['nombreRol'] as String,
    );
  }

  final int idrol;
  final String nombreRol;
}

class Usuario {
  const Usuario({
    required this.id,
    required this.nombreUser,
    required this.emailUser,
    required this.idrol,
    this.rol,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int,
      nombreUser: json['nombreUser'] as String,
      emailUser: json['emailUser'] as String,
      idrol: json['idrol'] as int,
      rol: json['rol'] == null
          ? null
          : Rol.fromJson(json['rol'] as Map<String, dynamic>),
    );
  }

  final int id;
  final String nombreUser;
  final String emailUser;
  final int idrol;
  final Rol? rol;
}

const Map<int, String> rolesDisponibles = {
  1: 'UserNormal',
  2: 'Empresa',
  3: 'Admin',
};
