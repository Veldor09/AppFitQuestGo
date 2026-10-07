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
    this.categoriaOtro,
    this.conFoto = false,
    this.creadoPorId,
    this.confirmaciones = 0,
    this.obsoletos = 0,
    this.miVoto,
    this.beneficio,
    this.patrocinado = false,
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
      categoriaOtro: json['categoriaOtro'] as String?,
      conFoto: json['conFoto'] as bool? ?? false,
      creadoPorId: creador?['id'] as int?,
      confirmaciones: json['confirmaciones'] as int? ?? 0,
      obsoletos: json['obsoletos'] as int? ?? 0,
      miVoto: json['miVoto'] as String?,
      beneficio: json['beneficio'] as String?,
      patrocinado: json['patrocinado'] as bool? ?? false,
    );
  }

  final int id;
  final String nombre;

  /// Clave de la lista cerrada de categorias (`agua`, `mirador`, ..., `otro`).
  final String categoria;
  final double lat;
  final double lng;
  final String estado;
  final String? descripcion;
  final String? creadoPorNombre;

  /// Solo cuando `categoria` es `otro`: lo que escribio quien lo propuso.
  final String? categoriaOtro;

  /// Hay una foto en el servidor (`GET /nodos/:id/foto`).
  final bool conFoto;

  /// Quien lo propuso: no puede votar su propio punto.
  final int? creadoPorId;

  /// Votos de "sigue ahi" y de "ya no existe" (solo vienen en el mapa).
  final int confirmaciones;
  final int obsoletos;

  /// Voto de quien consulta (`confirmar` / `obsoleto`), o null si aun no voto.
  final String? miVoto;

  /// Cupon o beneficio que ofrece el comercio (solo en nodos patrocinados).
  final String? beneficio;

  /// Nodo de Abastecimiento de una empresa: sale al mapa sin moderacion.
  final bool patrocinado;
}
