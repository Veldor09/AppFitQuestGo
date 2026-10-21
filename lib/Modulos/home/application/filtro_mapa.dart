/// Las cosas que el mapa de Home puede tener dibujadas.
enum CapaMapa { rutas, alertas, pois, eventos }

/// El filtro de los chips de arriba del mapa: "Todo", "Nada", o una sola capa.
///
/// Decide que se dibuja en el mapa y entre que se busca. El cuadro "Cerca de
/// ti" y el aviso por voz de las alertas cercanas no dependen del filtro: un
/// peligro cerca se avisa aunque lo hayas ocultado.
enum FiltroMapa {
  todo,
  rutas,
  alertas,
  pois,
  eventos,
  nada;

  /// Si con este filtro se ve [capa].
  bool muestra(CapaMapa capa) {
    return switch (this) {
      FiltroMapa.todo => true,
      FiltroMapa.nada => false,
      FiltroMapa.rutas => capa == CapaMapa.rutas,
      FiltroMapa.alertas => capa == CapaMapa.alertas,
      FiltroMapa.pois => capa == CapaMapa.pois,
      FiltroMapa.eventos => capa == CapaMapa.eventos,
    };
  }
}
