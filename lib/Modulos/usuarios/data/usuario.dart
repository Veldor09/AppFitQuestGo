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

  /// Nombre del rol; usa la relacion cargada o el catalogo local como respaldo.
  String get nombreRol =>
      rol?.nombreRol ?? rolesDisponibles[idrol] ?? 'Rol $idrol';

  /// Iniciales para el avatar de la fila / detalle.
  String get iniciales {
    final List<String> partes = nombreUser
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) {
      final String u = partes.first;
      return u.substring(0, u.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (partes.first.substring(0, 1) + partes[1].substring(0, 1))
        .toUpperCase();
  }
}

/// Catalogo de roles del backend (`RoleId`). El id 3 es Admin.
const Map<int, String> rolesDisponibles = <int, String>{
  1: 'UserNormal',
  2: 'Empresa',
  3: 'Admin',
};
