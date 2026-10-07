import 'dart:typed_data';

import 'package:fit_quest_go/core/api/api_client.dart';

/// Los datos de la cuenta de una empresa tal como los guarda el servidor.
class PerfilEmpresa {
  const PerfilEmpresa({
    required this.id,
    required this.nombre,
    required this.email,
    this.telefono,
  });

  /// Acepta las dos formas del backend: `GET /auth/perfil` (`nombreUser`,
  /// `emailUser`) y `PATCH /auth/perfil-empresa` (`nombre`, `email`).
  factory PerfilEmpresa.fromJson(Map<String, dynamic> json) {
    return PerfilEmpresa(
      id: json['id'] as int,
      nombre: (json['nombreUser'] ?? json['nombre']) as String,
      email: (json['emailUser'] ?? json['email']) as String,
      telefono: json['telefono'] as String?,
    );
  }

  final int id;

  /// El nombre comercial.
  final String nombre;
  final String email;
  final String? telefono;
}

/// Cuenta de la empresa: sus datos y su foto de perfil.
class EmpresaApi {
  EmpresaApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<PerfilEmpresa> miPerfil() async {
    final dynamic data = await _client.get('/auth/perfil');
    return PerfilEmpresa.fromJson(data as Map<String, dynamic>);
  }

  /// Cambia el nombre comercial y el telefono. Un telefono vacio lo borra.
  Future<PerfilEmpresa> actualizar({
    required String nombreComercial,
    required String telefono,
  }) async {
    final dynamic data = await _client.patch('/auth/perfil-empresa', {
      'nombreComercial': nombreComercial.trim(),
      'telefono': telefono.trim(),
    });
    return PerfilEmpresa.fromJson(data as Map<String, dynamic>);
  }

  /// Sube la foto de perfil (JPEG, PNG o WebP, hasta 3 MB).
  Future<void> subirFoto(Uint8List bytes) async {
    await _client.subirArchivo(
      '/auth/perfil/foto',
      campo: 'foto',
      bytes: bytes,
      nombreArchivo: 'foto.jpg',
    );
  }

  /// Los bytes de la foto de perfil, o null si la cuenta no tiene (404).
  Future<Uint8List?> foto() async {
    try {
      return await _client.getBytes('/auth/perfil/foto');
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> quitarFoto() async {
    await _client.delete('/auth/perfil/foto');
  }
}
