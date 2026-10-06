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

/// Estados de cuenta que expone el backend.
class EstadoUsuario {
  const EstadoUsuario._();
  static const String activado = 'Activado';
  static const String desactivado = 'Desactivado';
}

class Usuario {
  const Usuario({
    required this.id,
    required this.nombreUser,
    required this.emailUser,
    required this.idrol,
    this.estado = EstadoUsuario.activado,
    this.rol,
    this.intereses = const <String>[],
    this.actividades = const <String>[],
    this.unidad = 'km',
    this.notificaciones = true,
    this.visibilidad = 'publico',
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int,
      nombreUser: json['nombreUser'] as String,
      emailUser: json['emailUser'] as String,
      idrol: json['idrol'] as int,
      estado: (json['estado'] as String?) ?? EstadoUsuario.activado,
      rol: json['rol'] == null
          ? null
          : Rol.fromJson(json['rol'] as Map<String, dynamic>),
      intereses: _parseListString(json['intereses']),
      actividades: _parseListString(json['actividades']),
      unidad: (json['unidad'] as String?) ?? 'km',
      notificaciones: (json['notificaciones'] as bool?) ?? true,
      visibilidad: (json['visibilidad'] as String?) ?? 'publico',
    );
  }

  static List<String> _parseListString(dynamic val) {
    if (val == null) return const <String>[];
    if (val is List) {
      return val
          .where((dynamic e) => e != null)
          .map((dynamic e) => e.toString().trim())
          .where((String s) => s.isNotEmpty)
          .toList();
    }
    if (val is String) {
      final String trimmed = val.trim();
      if (trimmed.isEmpty || trimmed == '{}' || trimmed == '[]') {
        return const <String>[];
      }
      final String clean = trimmed.replaceAll(RegExp(r'^[\{\[]|[\}\]]$'), '');
      if (clean.isEmpty) return const <String>[];
      return clean
          .split(',')
          .map((String s) => s.trim().replaceAll(RegExp(r'^"|"$'), ''))
          .where((String s) => s.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  final int id;
  final String nombreUser;
  final String emailUser;
  final int idrol;
  final String estado;
  final Rol? rol;
  final List<String> intereses;
  final List<String> actividades;
  final String unidad;
  final bool notificaciones;
  final String visibilidad;


  bool get activo => estado == EstadoUsuario.activado;

  /// Etiqueta del rol en espanol para mostrar en la UI (Usuario / Empresa /
  /// Admin), independiente de como lo nombre el backend (`UserNormal`, ...).
  String get etiquetaRol {
    switch (idrol) {
      case 2:
        return 'Empresa';
      case 3:
        return 'Admin';
      default:
        return 'Usuario';
    }
  }

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

/// Catalogo de roles (`RoleId` del backend) con etiqueta en espanol para los
/// selectores. El id 3 es Admin.
const Map<int, String> rolesDisponibles = <int, String>{
  1: 'Usuario',
  2: 'Empresa',
  3: 'Admin',
};
