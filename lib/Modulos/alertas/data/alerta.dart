class Alerta {
  const Alerta({
    required this.id,
    required this.tipo,
    required this.gravedad,
    required this.lat,
    required this.lng,
    required this.estado,
    this.descripcion,
    this.creadoPorNombre,
  });

  factory Alerta.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? creador =
        json['creadoPor'] as Map<String, dynamic>?;
    return Alerta(
      id: json['id'] as int,
      tipo: json['tipo'] as String,
      gravedad: json['gravedad'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      estado: json['estado'] as String,
      descripcion: json['descripcion'] as String?,
      creadoPorNombre: creador?['nombreUser'] as String?,
    );
  }

  final int id;
  final String tipo;
  final String gravedad;
  final double lat;
  final double lng;
  final String estado;
  final String? descripcion;
  final String? creadoPorNombre;
}
