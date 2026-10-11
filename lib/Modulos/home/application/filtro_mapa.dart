/// Las cosas que el mapa de Home puede tener dibujadas.
enum CapaMapa { rutas, alertas, pois, eventos }

/// El filtro de los chips de arriba del mapa: "Todo", o una sola capa.
///
/// Decide que se dibuja en el mapa y entre que se busca. El cuadro "Cerca de
/// ti" y el aviso por voz de las alertas cercanas no dependen del filtro: un
/// peligro cerca se avisa aunque lo hayas ocultado.
enum FiltroMapa {
  todo(null),
  rutas(CapaMapa.rutas),
  alertas(CapaMapa.alertas),
  pois(CapaMapa.pois),
  eventos(CapaMapa.eventos);

  const FiltroMapa(this._capa);

  /// La unica capa que deja ver, o null si deja ver todas.
  final CapaMapa? _capa;

  /// Si con este filtro se ve [capa].
  bool muestra(CapaMapa capa) => _capa == null || _capa == capa;
}
