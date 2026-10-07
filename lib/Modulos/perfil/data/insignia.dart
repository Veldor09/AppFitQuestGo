/// Insignia del catálogo del backend, con el estado para un usuario concreto.
class Insignia {
  const Insignia({
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.emoji,
    required this.desbloqueada,
    this.fechaObtenida,
    this.progreso,
    this.meta,
  });

  factory Insignia.fromJson(Map<String, dynamic> json) {
    return Insignia(
      codigo: (json['codigo'] as String?) ?? '',
      nombre: (json['nombre'] as String?) ?? '',
      descripcion: (json['descripcion'] as String?) ?? '',
      emoji: (json['emoji'] as String?) ?? '🏅',
      desbloqueada: (json['desbloqueada'] as bool?) ?? false,
      fechaObtenida: DateTime.tryParse(
        (json['fechaObtenida'] ?? '').toString(),
      )?.toLocal(),
      progreso: (json['progreso'] as num?)?.toDouble(),
      meta: (json['meta'] as num?)?.toDouble(),
    );
  }

  final String codigo;
  final String nombre;
  final String descripcion;
  final String emoji;
  final bool desbloqueada;
  final DateTime? fechaObtenida;

  /// Avance actual hacia la meta (p. ej. km recorridos). Opcional.
  final double? progreso;

  /// Valor que hay que alcanzar (p. ej. 10 km). Opcional.
  final double? meta;
}
