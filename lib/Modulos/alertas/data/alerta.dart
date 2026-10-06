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
    this.creadoPorId,
    this.miVoto,
    this.tipoOtro,
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
      creadoPorId: creador?['id'] as int?,
      miVoto: json['miVoto'] as String?,
      tipoOtro: json['tipoOtro'] as String?,
    );
  }

  final int id;

  /// Clave de la lista cerrada de tipos (`arbol_caido`, `bache`, ..., `otro`).
  final String tipo;
  final String gravedad;
  final double lat;
  final double lng;
  final String estado;
  final String? descripcion;
  final String? creadoPorNombre;

  /// Quien la reporto: la app no avisa de las alertas propias.
  final int? creadoPorId;

  /// Voto de quien consulta (`confirmar` / `desmentir`), o null si aun no voto.
  final String? miVoto;

  /// Solo cuando `tipo` es `otro`: lo que escribio quien reporto.
  final String? tipoOtro;

  bool get estaActiva => estado == 'Activa';
}
