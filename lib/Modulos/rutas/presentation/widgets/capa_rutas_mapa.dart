import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/mapa/pin_anotacion.dart';
import 'package:fit_quest_go/core/mapa/pin_icono.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

/// Las rutas publicadas sobre el mapa de Home: cada trazo como una linea verde
/// y, encima, el pin de salida con el nombre de la ruta (el mismo que ya usa
/// la pantalla de detalle).
///
/// Tocar una linea o su pin avisa con el id de la ruta ([alTocarRuta]), para
/// abrir su detalle. No hay que confundirlas con los recorridos de un evento,
/// que van en azul y con su propio pin.
class CapaRutasMapa {
  CapaRutasMapa._(this._lineas, this._iconos);

  /// Crea la capa sobre [mapa]. Hay que crearla antes de las capas que deben
  /// quedar encima (alertas y puntos de interes).
  static Future<CapaRutasMapa> crear(
    MapboxMap mapa, {
    void Function(int rutaId)? alTocarRuta,
  }) async {
    final PolylineAnnotationManager lineas = await mapa.annotations
        .createPolylineAnnotationManager();
    final PointAnnotationManager iconos = await mapa.annotations
        .createPointAnnotationManager();
    await prepararPines(iconos);
    final CapaRutasMapa capa = CapaRutasMapa._(lineas, iconos)
      ..alTocarRuta = alTocarRuta;
    capa._escuchas.addAll(<Cancelable>[
      lineas.tapEvents(
        onTap: (PolylineAnnotation a) => capa._tocar(capa._porLinea[a.id]),
      ),
      iconos.tapEvents(
        onTap: (PointAnnotation a) => capa._tocar(capa._porPin[a.id]),
      ),
    ]);
    return capa;
  }

  final PolylineAnnotationManager _lineas;
  final PointAnnotationManager _iconos;

  /// Se llama con el id de la ruta cuya linea o pin se toco.
  void Function(int rutaId)? alTocarRuta;

  // Que ruta es cada cosa dibujada (id de la anotacion -> id de la ruta).
  final Map<String, int> _porLinea = <String, int>{};
  final Map<String, int> _porPin = <String, int>{};
  final List<Cancelable> _escuchas = <Cancelable>[];

  void _tocar(int? rutaId) {
    if (rutaId != null) alTocarRuta?.call(rutaId);
  }

  /// Deja de escuchar los toques (al cerrarse el mapa).
  void liberar() {
    for (final Cancelable c in _escuchas) {
      c.cancel();
    }
    _escuchas.clear();
  }

  /// Borra todo y dibuja [rutas]. [densidad] es el `devicePixelRatio` de la
  /// pantalla. Una ruta con menos de 2 puntos no tiene trazo y se salta.
  Future<void> dibujar({
    required double densidad,
    required List<Ruta> rutas,
  }) async {
    await _lineas.deleteAll();
    await _iconos.deleteAll();
    _porLinea.clear();
    _porPin.clear();

    // Copia: la lista puede cambiar mientras se espera a Mapbox.
    final List<Ruta> validas = <Ruta>[
      for (final Ruta r in rutas)
        if (r.puntos.length >= 2) r,
    ];
    if (validas.isEmpty) return;

    final List<PolylineAnnotation?> lineas = await _lineas.createMulti(
      <PolylineAnnotationOptions>[
        for (final Ruta r in validas)
          PolylineAnnotationOptions(
            geometry: LineString(
              coordinates: <Position>[
                for (final PuntoRuta p in r.puntos) Position(p.lng, p.lat),
              ],
            ),
            lineColor: FqColors.trail.toARGB32(),
            lineWidth: 4,
          ),
      ],
    );
    for (int i = 0; i < lineas.length; i++) {
      final PolylineAnnotation? linea = lineas[i];
      if (linea != null) _porLinea[linea.id] = validas[i].id;
    }

    final List<PointAnnotation?> pines = await _iconos.createMulti(
      <PointAnnotationOptions>[
        for (final Ruta r in validas)
          opcionesDePin(
            lat: r.puntos.first.lat,
            lng: r.puntos.first.lng,
            imagen: await imagenPin(TipoPin.rutaInicio),
            densidad: densidad,
            etiqueta: r.nombre,
          ),
      ],
    );
    for (int i = 0; i < pines.length; i++) {
      final PointAnnotation? pin = pines[i];
      if (pin != null) _porPin[pin.id] = validas[i].id;
    }
  }
}
