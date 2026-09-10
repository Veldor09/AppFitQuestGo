class PuntoRuta {
  const PuntoRuta({required this.lat, required this.lng});

  factory PuntoRuta.fromJson(Map<String, dynamic> json) {
    return PuntoRuta(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  final double lat;
  final double lng;
}

class Ruta {
  const Ruta({
    required this.id,
    required this.nombre,
    required this.actividad,
    required this.dificultad,
    required this.distanciaKm,
    required this.puntos,
    required this.estado,
    this.creadoPorNombre,
  });

  factory Ruta.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? creador =
        json['creadoPor'] as Map<String, dynamic>?;
    // `distanciaKm` es `decimal` en Postgres: pg lo serializa como texto para
    // no perder precision, asi que puede llegar como String o num.
    final dynamic distancia = json['distanciaKm'];
    return Ruta(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      actividad: json['actividad'] as String,
      dificultad: json['dificultad'] as String,
      distanciaKm: distancia is String
          ? double.parse(distancia)
          : (distancia as num).toDouble(),
      puntos: (json['puntos'] as List<dynamic>)
          .map((dynamic p) => PuntoRuta.fromJson(p as Map<String, dynamic>))
          .toList(),
      estado: json['estado'] as String,
      creadoPorNombre: creador?['nombreUser'] as String?,
    );
  }

  final int id;
  final String nombre;
  final String actividad;
  final String dificultad;
  final double distanciaKm;
  final List<PuntoRuta> puntos;
  final String estado;
  final String? creadoPorNombre;
}
