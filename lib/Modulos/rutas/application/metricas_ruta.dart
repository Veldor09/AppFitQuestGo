import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

/// Debajo de esta distancia el ritmo no es confiable (el ruido del GPS parado
/// da "ritmos" absurdos), asi que no se muestra.
const double _distanciaMinimaParaRitmoKm = 0.02;

/// Largo del trazo en km: suma de los tramos entre puntos consecutivos.
double distanciaTrazoKm(List<PuntoRuta> puntos) {
  double metros = 0;
  for (int i = 0; i < puntos.length - 1; i++) {
    metros += distanciaMetros(
      puntos[i].lat,
      puntos[i].lng,
      puntos[i + 1].lat,
      puntos[i + 1].lng,
    );
  }
  return metros / 1000;
}

/// Tiempo que toma cada km al ritmo medio de la sesion, o null si todavia no
/// hay datos confiables (casi sin distancia o sin tiempo).
Duration? ritmoPorKm(Duration tiempo, double distanciaKm) {
  if (distanciaKm < _distanciaMinimaParaRitmoKm || tiempo <= Duration.zero) {
    return null;
  }
  return Duration(seconds: (tiempo.inSeconds / distanciaKm).round());
}

/// `mm:ss`, o `h:mm:ss` desde la hora.
String formatoDuracion(Duration d) {
  final int horas = d.inHours;
  final String mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final String ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return horas > 0 ? '$horas:$mm:$ss' : '$mm:$ss';
}

/// `m:ss` por km; `--:--` mientras no haya ritmo. Los minutos no pasan a horas
/// (un ritmo de 75:30 es lento, pero sigue siendo "75 min por km").
String formatoRitmo(Duration? ritmo) {
  if (ritmo == null) return '--:--';
  final String ss = ritmo.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${ritmo.inMinutes}:$ss';
}
