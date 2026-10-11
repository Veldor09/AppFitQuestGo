/// Evita que dos dibujos de la misma capa del mapa se mezclen.
///
/// Dibujar es borrar todo y crear todo de nuevo, con esperas a Mapbox en
/// medio: si llegan dos pedidos seguidos (el refresco periodico y un toque en
/// un filtro) y corren a la vez, cada uno borra lo del otro a medias y la capa
/// queda con cosas repetidas. Aqui corre uno solo; lo que se pida mientras
/// tanto se junta en UN dibujo mas, al terminar, ya con los datos mas nuevos.
class RedibujoUnico {
  RedibujoUnico(this._dibujar);

  final Future<void> Function() _dibujar;
  bool _enCurso = false;
  bool _pendiente = false;

  /// Pide un dibujo. Si ya hay uno en curso, no espera: lo marca para repetirlo
  /// al terminar.
  Future<void> pedir() async {
    if (_enCurso) {
      _pendiente = true;
      return;
    }
    _enCurso = true;
    try {
      do {
        _pendiente = false;
        try {
          await _dibujar();
        } catch (_) {
          // Dibujar es "lo mejor posible": si Mapbox falla, el proximo
          // refresco lo vuelve a intentar. Que no deje la cola trabada.
        }
      } while (_pendiente);
    } finally {
      _enCurso = false;
    }
  }
}
