enum TipoCalificable {
  ruta('ruta'),
  nodo('nodo'),
  evento('evento');

  const TipoCalificable(this.clave);

  final String clave;
}

enum ValorCalificacion {
  arriba('arriba'),
  abajo('abajo');

  const ValorCalificacion(this.clave);

  final String clave;

  static ValorCalificacion? deClave(Object? clave) {
    for (final ValorCalificacion v in ValorCalificacion.values) {
      if (v.clave == clave) return v;
    }
    return null;
  }
}

enum MotivoSinCalificar {
  sinRecorrido('sin_recorrido'),
  propio('propio'),
  noDisponible('no_disponible');

  const MotivoSinCalificar(this.clave);

  final String clave;

  static MotivoSinCalificar? deClave(Object? clave) {
    for (final MotivoSinCalificar m in MotivoSinCalificar.values) {
      if (m.clave == clave) return m;
    }
    return null;
  }
}

class ResumenCalificacion {
  const ResumenCalificacion({
    this.arriba = 0,
    this.abajo = 0,
    this.mia,
    this.puedeCalificar = true,
    this.motivo,
    this.areas = const <ResumenCalificacion>[],
  });

  factory ResumenCalificacion.fromJson(Map<String, dynamic> json) {
    final List<dynamic> areas = json['areas'] as List<dynamic>? ?? <dynamic>[];
    return ResumenCalificacion(
      arriba: json['arriba'] as int? ?? 0,
      abajo: json['abajo'] as int? ?? 0,
      mia: ValorCalificacion.deClave(json['mia']),
      puedeCalificar: json['puedeCalificar'] as bool? ?? true,
      motivo: MotivoSinCalificar.deClave(json['motivo']),
      areas: <ResumenCalificacion>[
        for (final dynamic a in areas)
          ResumenCalificacion.fromJson(a as Map<String, dynamic>),
      ],
    );
  }

  final int arriba;
  final int abajo;

  final ValorCalificacion? mia;
  final bool puedeCalificar;
  final MotivoSinCalificar? motivo;

  final List<ResumenCalificacion> areas;

  int get total => arriba + abajo;
}
