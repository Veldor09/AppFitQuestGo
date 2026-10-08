import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

/// Hasta donde una ruta cuenta como "cerca de ti" en el cuadro de Home.
const double radioRutasCercanasMetros = 10000;

/// Hasta donde una alerta cuenta como "cerca de ti" en el cuadro de Home.
const double radioAlertasCercanasMetros = 5000;

/// La ruta mas cercana y a cuantos metros pasa.
class RutaCercana {
  const RutaCercana(this.ruta, this.metros);

  final Ruta ruta;
  final double metros;
}

/// La alerta mas cercana y a cuantos metros esta.
class AlertaCercana {
  const AlertaCercana(this.alerta, this.metros);

  final Alerta alerta;
  final double metros;
}

/// Distancia (m) de ([lat], [lng]) al punto mas cercano del trazo de [ruta], o
/// null si la ruta no tiene trazo. Se mide a los puntos del trazo (no a los
/// tramos entre ellos): un trazo de GPS tiene un punto cada pocos metros.
double? distanciaARuta(double lat, double lng, Ruta ruta) {
  double? menor;
  for (final PuntoRuta p in ruta.puntos) {
    final double d = distanciaMetros(lat, lng, p.lat, p.lng);
    if (menor == null || d < menor) menor = d;
  }
  return menor;
}

/// La ruta cuyo trazo pasa mas cerca de ([lat], [lng]), si pasa a [radioMetros]
/// o menos. La distancia es al punto mas cercano del trazo, no a su inicio: lo
/// que importa es cuanto hay que caminar para llegar a ella.
RutaCercana? rutaMasCercana({
  required double lat,
  required double lng,
  required Iterable<Ruta> rutas,
  double radioMetros = radioRutasCercanasMetros,
}) {
  RutaCercana? elegida;
  for (final Ruta ruta in rutas) {
    final double? d = distanciaARuta(lat, lng, ruta);
    if (d == null || d > radioMetros) continue;
    if (elegida == null || d < elegida.metros) elegida = RutaCercana(ruta, d);
  }
  return elegida;
}

/// La alerta activa mas cercana a ([lat], [lng]), si esta a [radioMetros] o
/// menos. Cuentan tambien las que reporto la propia persona: es lo que hay
/// cerca.
AlertaCercana? alertaMasCercana({
  required double lat,
  required double lng,
  required Iterable<Alerta> alertas,
  double radioMetros = radioAlertasCercanasMetros,
}) {
  AlertaCercana? elegida;
  for (final Alerta alerta in alertas) {
    if (!alerta.estaActiva) continue;
    final double d = distanciaMetros(lat, lng, alerta.lat, alerta.lng);
    if (d > radioMetros) continue;
    if (elegida == null || d < elegida.metros) {
      elegida = AlertaCercana(alerta, d);
    }
  }
  return elegida;
}
