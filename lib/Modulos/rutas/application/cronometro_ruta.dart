enum EstadoCronometro { inactivo, corriendo, pausado, finalizado }

/// Cronometro de una grabacion de ruta, con pausa: cuenta solo el tiempo en
/// movimiento, no el que estuvo pausado. No usa timers (solo lee el reloj
/// cuando se le pregunta), asi la pantalla decide cada cuanto se redibuja y
/// las pruebas controlan el reloj.
class CronometroRuta {
  CronometroRuta({DateTime Function()? ahora}) : _ahora = ahora ?? DateTime.now;

  final DateTime Function() _ahora;

  EstadoCronometro _estado = EstadoCronometro.inactivo;
  DateTime? _tramoDesde;
  Duration _acumulado = Duration.zero;

  EstadoCronometro get estado => _estado;

  /// Tiempo en movimiento acumulado hasta ahora.
  Duration get transcurrido {
    final DateTime? desde = _tramoDesde;
    if (_estado == EstadoCronometro.corriendo && desde != null) {
      return _acumulado + _ahora().difference(desde);
    }
    return _acumulado;
  }

  /// Arranca una sesion nueva desde cero.
  void iniciar() {
    _acumulado = Duration.zero;
    _tramoDesde = _ahora();
    _estado = EstadoCronometro.corriendo;
  }

  void pausar() {
    if (_estado != EstadoCronometro.corriendo) return;
    _acumulado = transcurrido;
    _tramoDesde = null;
    _estado = EstadoCronometro.pausado;
  }

  void reanudar() {
    if (_estado != EstadoCronometro.pausado) return;
    _tramoDesde = _ahora();
    _estado = EstadoCronometro.corriendo;
  }

  /// Congela el tiempo; la sesion queda finalizada hasta [reiniciar].
  void detener() {
    if (_estado != EstadoCronometro.corriendo &&
        _estado != EstadoCronometro.pausado) {
      return;
    }
    _acumulado = transcurrido;
    _tramoDesde = null;
    _estado = EstadoCronometro.finalizado;
  }

  void reiniciar() {
    _acumulado = Duration.zero;
    _tramoDesde = null;
    _estado = EstadoCronometro.inactivo;
  }
}
