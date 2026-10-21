/// Que se califica (el segmento de la ruta `/calificaciones/:tipo/:id`).
enum TipoCalificable {
  ruta('ruta'),
  nodo('nodo'),
  evento('evento');

  const TipoCalificable(this.clave);

  final String clave;
}

/// Sentido de la calificacion: pulgar arriba o abajo.
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

/// Por que quien consulta no puede calificar. El servidor lo manda como clave;
/// la pantalla lo traduce.
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

/// Cuantos pulgares tiene algo, el tuyo y si puedes calificar. Para un evento
/// trae ademas el resumen de cada una de sus areas (en [areas]).
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

  /// Lo que calificaste tu, o null.
  final ValorCalificacion? mia;
  final bool puedeCalificar;
  final MotivoSinCalificar? motivo;

  /// Solo en el resumen de un evento: un resumen por area, en el orden de
  /// `Evento.areas`.
  final List<ResumenCalificacion> areas;

  int get total => arriba + abajo;
}
