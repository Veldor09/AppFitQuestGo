/// Lo que la app avisa del clima de la zona.
enum TipoClima { lluvia, tormenta, calor }

enum NivelClima { precaucion, peligro }

/// Un aviso del clima de la zona: lluvia fuerte, tormenta electrica o calor
/// extremo, ahora o dentro de las proximas 3 horas.
class AlertaClima {
  const AlertaClima({
    required this.tipo,
    required this.nivel,
    required this.enHoras,
    this.valor,
  });

  /// Null si el servidor manda un tipo o un nivel que esta version de la app no
  /// conoce: se ignora ese aviso en lugar de romper los demas.
  static AlertaClima? desdeJson(Map<String, dynamic> json) {
    final TipoClima? tipo = _porNombre(TipoClima.values, json['tipo']);
    final NivelClima? nivel = _porNombre(NivelClima.values, json['nivel']);
    if (tipo == null || nivel == null) return null;
    return AlertaClima(
      tipo: tipo,
      nivel: nivel,
      enHoras: (json['enHoras'] as num?)?.toInt() ?? 0,
      valor: (json['valor'] as num?)?.toDouble(),
    );
  }

  final TipoClima tipo;
  final NivelClima nivel;

  /// 0 = ahora; 1..3 = dentro de tantas horas.
  final int enHoras;

  /// mm/h para la lluvia, °C de sensacion termica para el calor; null en la
  /// tormenta.
  final double? valor;

  bool get esPeligro => nivel == NivelClima.peligro;

  /// Identidad de lo que se le muestra a la persona: si la cierra, no se le
  /// vuelve a mostrar lo mismo, pero si el aviso sube de nivel si.
  String get clave => '${tipo.name}:${nivel.name}';
}

/// Respuesta de `GET /clima/alertas`.
class RespuestaClima {
  const RespuestaClima({required this.alertas, required this.fuente});

  /// Del mas grave al menos grave; a igual gravedad, el mas cercano primero.
  final List<AlertaClima> alertas;

  /// Quien aporta los datos (se muestra como credito).
  final String fuente;
}

T? _porNombre<T extends Enum>(List<T> valores, Object? nombre) {
  for (final T v in valores) {
    if (v.name == nombre) return v;
  }
  return null;
}
