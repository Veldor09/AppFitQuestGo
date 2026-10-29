import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/mapa/mapbox_directions_service.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';

/// Lo que se pinta para guiar a alguien hasta un destino: la calle en verde
/// lima y puntitos en los tramos donde no hay calle.
class TrazoGuia {
  const TrazoGuia({required this.calle, required this.puntos});

  final List<PosicionGps> calle;
  final List<PosicionGps> puntos;
}

const double _espaciadoPuntitosM = 7;
const double _minPuntitosM = 4;
const double _minFinCalleADestinoM = 8;
const double _minUsuarioACalleM = 5;

List<PosicionGps> puntitosEntre(PosicionGps desde, PosicionGps hasta) {
  final double dist = distanciaMetros(
    desde.lat,
    desde.lng,
    hasta.lat,
    hasta.lng,
  );
  if (dist < _minPuntitosM) return <PosicionGps>[];
  final int pasos = (dist / _espaciadoPuntitosM).round().clamp(1, 100);
  return <PosicionGps>[
    for (int i = 1; i <= pasos; i++)
      (
        lat: desde.lat + (i / (pasos + 1)) * (hasta.lat - desde.lat),
        lng: desde.lng + (i / (pasos + 1)) * (hasta.lng - desde.lng),
      ),
  ];
}

/// [destino] es el punto real al que se quiere llegar, no donde termina la
/// calle: la calle de Mapbox casi nunca llega hasta un parque o un sendero.
TrazoGuia trazoGuia({
  required RutaVial camino,
  required PosicionGps destino,
  PosicionGps? usuario,
}) {
  if (camino.esLineaRecta || camino.puntos.length < 2) {
    final PosicionGps desde =
        usuario ?? (camino.puntos.isNotEmpty ? camino.puntos.first : destino);
    return TrazoGuia(
      calle: const <PosicionGps>[],
      puntos: puntitosEntre(desde, destino),
    );
  }

  final List<PosicionGps> calle = camino.puntos;
  final List<PosicionGps> puntos = <PosicionGps>[];

  final PosicionGps finCalle = calle.last;
  if (distanciaMetros(finCalle.lat, finCalle.lng, destino.lat, destino.lng) >
      _minFinCalleADestinoM) {
    puntos.addAll(puntitosEntre(finCalle, destino));
  }

  if (usuario != null) {
    final PosicionGps inicioCalle = calle.first;
    if (distanciaMetros(
          usuario.lat,
          usuario.lng,
          inicioCalle.lat,
          inicioCalle.lng,
        ) >
        _minUsuarioACalleM) {
      puntos.addAll(puntitosEntre(usuario, inicioCalle));
    }
  }
  return TrazoGuia(calle: calle, puntos: puntos);
}

List<CircleAnnotationOptions> opcionesPuntitos(List<PosicionGps> puntos) {
  return <CircleAnnotationOptions>[
    for (final PosicionGps p in puntos)
      CircleAnnotationOptions(
        geometry: Point(coordinates: Position(p.lng, p.lat)),
        circleColor: FqColors.volt.toARGB32(),
        circleRadius: 4.5,
        circleStrokeColor: FqColors.night.toARGB32(),
        circleStrokeWidth: 1.5,
      ),
  ];
}

/// Borra lo anterior y pinta [trazo]; con `null` solo limpia.
Future<void> dibujarGuiaVerde({
  required PolylineAnnotationManager? lineas,
  required CircleAnnotationManager? puntos,
  required TrazoGuia? trazo,
}) async {
  await lineas?.deleteAll();
  await puntos?.deleteAll();
  if (trazo == null) return;
  if (trazo.calle.length >= 2 && lineas != null) {
    await lineas.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: <Position>[
            for (final PosicionGps p in trazo.calle) Position(p.lng, p.lat),
          ],
        ),
        lineColor: FqColors.volt.toARGB32(),
        lineWidth: 6,
      ),
    );
  }
  if (trazo.puntos.isNotEmpty && puntos != null) {
    await puntos.createMulti(opcionesPuntitos(trazo.puntos));
  }
}
