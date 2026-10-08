/// Un punto del mapa (el contrato con el backend es `{lat, lng}`).
class PuntoGeo {
  const PuntoGeo({required this.lat, required this.lng});

  factory PuntoGeo.fromJson(Map<String, dynamic> json) {
    return PuntoGeo(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  final double lat;
  final double lng;

  Map<String, double> toJson() => <String, double>{'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      other is PuntoGeo && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// Un trazo con nombre dibujado por la empresa: un area (poligono, el ultimo
/// punto se une al primero sin repetirlo) o un recorrido (linea).
class ZonaEvento {
  const ZonaEvento({required this.nombre, required this.puntos, this.eventoId});

  factory ZonaEvento.fromJson(Map<String, dynamic> json) {
    return ZonaEvento(
      nombre: json['nombre'] as String,
      puntos: (json['puntos'] as List<dynamic>)
          .map((dynamic p) => PuntoGeo.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  final String nombre;
  final List<PuntoGeo> puntos;

  /// El evento al que pertenece este trazo. No viaja al servidor (el trazo
  /// ya vive dentro de su evento): solo sirve para saber a que evento llevar a
  /// quien toca el trazo en el mapa. Lo llenan [Evento.areasRotuladas] y
  /// [Evento.recorridosRotulados].
  final int? eventoId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'nombre': nombre,
    'puntos': <Map<String, double>>[
      for (final PuntoGeo p in puntos) p.toJson(),
    ],
  };
}

/// Un evento publicado por una empresa: tiene fechas y al menos un area o un
/// recorrido dibujados en el mapa.
class Evento {
  const Evento({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.fechaInicio,
    required this.fechaFin,
    required this.areas,
    required this.recorridos,
    this.descripcion,
    this.creadoPorNombre,
    this.creadoPorId,
  });

  factory Evento.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? creador =
        json['creadoPor'] as Map<String, dynamic>?;
    List<ZonaEvento> zonas(String clave) =>
        ((json[clave] as List<dynamic>?) ?? const <dynamic>[])
            .map((dynamic z) => ZonaEvento.fromJson(z as Map<String, dynamic>))
            .toList();
    return Evento(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      categoria: json['categoria'] as String,
      fechaInicio: DateTime.parse(json['fechaInicio'] as String),
      fechaFin: DateTime.parse(json['fechaFin'] as String),
      areas: zonas('areas'),
      recorridos: zonas('recorridos'),
      creadoPorNombre: creador?['nombreUser'] as String?,
      creadoPorId: creador?['id'] as int?,
    );
  }

  final int id;
  final String nombre;
  final String? descripcion;

  /// Clave de la lista cerrada (`benefico`, `caminata`, ..., `otro`).
  final String categoria;

  /// Instantes absolutos; se muestran en la hora local del dispositivo.
  final DateTime fechaInicio;
  final DateTime fechaFin;

  final List<ZonaEvento> areas;
  final List<ZonaEvento> recorridos;

  /// Nombre comercial de la empresa que lo publica.
  final String? creadoPorNombre;
  final int? creadoPorId;

  /// Las areas y los recorridos para dibujarlos en un mapa: cada uno lleva el
  /// nombre del EVENTO (no su nombre interno, "Area 1" / "Recorrido 1"), porque
  /// es lo que se escribe junto al pin.
  List<ZonaEvento> get areasRotuladas => _conNombreDelEvento(areas);
  List<ZonaEvento> get recorridosRotulados => _conNombreDelEvento(recorridos);

  List<ZonaEvento> _conNombreDelEvento(List<ZonaEvento> zonas) => <ZonaEvento>[
    for (final ZonaEvento z in zonas)
      ZonaEvento(nombre: nombre, puntos: z.puntos, eventoId: id),
  ];

  /// Todos los puntos de todos los trazos (para encuadrar la camara).
  List<PuntoGeo> get todosLosPuntos => <PuntoGeo>[
    for (final ZonaEvento z in areas) ...z.puntos,
    for (final ZonaEvento z in recorridos) ...z.puntos,
  ];

  bool haComenzado(DateTime ahora) => !ahora.isBefore(fechaInicio);

  bool haTerminado(DateTime ahora) => ahora.isAfter(fechaFin);

  bool enCurso(DateTime ahora) => haComenzado(ahora) && !haTerminado(ahora);
}
