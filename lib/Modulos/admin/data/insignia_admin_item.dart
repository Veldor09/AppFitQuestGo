
/// Modelo de datos para ADM-10: Gestión administrativa de insignias.
///
/// Representa una insignia recibida desde el backend NestJS.
class InsigniaAdminItem {
  const InsigniaAdminItem({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.emoji,
    required this.tipo,
    required this.metrica,
    required this.meta,
    required this.activa,
  });

  final int id;
  final String codigo;
  final String nombre;
  final String descripcion;
  final String emoji;
  final String tipo;
  final String? metrica;
  final double? meta;
  final bool activa;

  /// Convierte la respuesta JSON del backend en una insignia.
  factory InsigniaAdminItem.fromJson(Map<String, dynamic> json) {
    return InsigniaAdminItem(
      id: _leerEntero(json['id']),
      codigo: (json['codigo'] ?? '').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      descripcion: (json['descripcion'] ?? '').toString(),
      emoji: (json['emoji'] ?? '').toString(),
      tipo: (json['tipo'] ?? '').toString(),
      metrica: json['metrica']?.toString(),
      meta: _leerDecimal(json['meta']),
      activa: json['activa'] == true,
    );
  }

  /// Convierte una insignia en un mapa JSON.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'codigo': codigo,
      'nombre': nombre,
      'descripcion': descripcion,
      'emoji': emoji,
      'tipo': tipo,
      'metrica': metrica,
      'meta': meta,
      'activa': activa,
    };
  }

  /// Genera los datos necesarios para crear una insignia.
  ///
  /// El identificador es asignado por la base de datos.
  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'codigo': codigo.trim().toUpperCase(),
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'emoji': emoji.trim(),
      'tipo': tipo,
      'metrica': metrica,
      'meta': meta,
      'activa': activa,
    };
  }

  /// Genera los datos editables de una insignia existente.
  ///
  /// El código no se incluye porque es inmutable en el backend.
  Map<String, dynamic> toUpdateJson() {
    return <String, dynamic>{
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'emoji': emoji.trim(),
      'tipo': tipo,
      'metrica': metrica,
      'meta': meta,
      'activa': activa,
    };
  }

  /// Crea una copia modificando únicamente los campos indicados.
  InsigniaAdminItem copyWith({
    int? id,
    String? codigo,
    String? nombre,
    String? descripcion,
    String? emoji,
    String? tipo,
    String? metrica,
    double? meta,
    bool? activa,
  }) {
    return InsigniaAdminItem(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      emoji: emoji ?? this.emoji,
      tipo: tipo ?? this.tipo,
      metrica: metrica ?? this.metrica,
      meta: meta ?? this.meta,
      activa: activa ?? this.activa,
    );
  }

  /// Convierte valores numéricos de PostgreSQL a enteros.
  static int _leerEntero(dynamic valor) {
    if (valor is int) return valor;

    if (valor is num) return valor.toInt();

    return int.parse(valor.toString());
  }

  /// PostgreSQL puede devolver campos numeric como String.
  static double? _leerDecimal(dynamic valor) {
    if (valor == null) return null;

    if (valor is num) return valor.toDouble();

    return double.parse(valor.toString());
  }
}
