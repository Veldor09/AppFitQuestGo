class Nodo {
  const Nodo({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.lat,
    required this.lng,
    required this.estado,
    this.descripcion,
    this.creadoPorNombre,
  });

  factory Nodo.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? creador =
        json['creadoPor'] as Map<String, dynamic>?;
    return Nodo(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      categoria: json['categoria'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      estado: json['estado'] as String,
      descripcion: json['descripcion'] as String?,
      creadoPorNombre: creador?['nombreUser'] as String?,
    );
  }

  final int id;
  final String nombre;
  final String categoria;
  final double lat;
  final double lng;
  final String estado;
  final String? descripcion;
  final String? creadoPorNombre;
}
