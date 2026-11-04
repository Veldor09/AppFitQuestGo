import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/mapa/pin_anotacion.dart';
import 'package:fit_quest_go/core/mapa/pin_icono.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

/// Las rutas publicadas sobre el mapa de Home.
///
/// Para evitar la saturación visual del mapa ("efecto espagueti"), por defecto
/// dibuja ÚNICAMENTE los pines de salida/inicio de las rutas públicas.
/// Al seleccionar una ruta específica, [seleccionarRuta] dibuja su trazo en azul.
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
  PointAnnotation? _pinFinSeleccion;

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

  Future<void> quitar(MapboxMap mapa) async {
    liberar();
    for (final Object m in <Object>[_lineas, _iconos]) {
      try {
        await mapa.annotations.removeAnnotationManager(
          m as BaseAnnotationManager,
        );
      } catch (_) {}
    }
  }

  /// Borra todo y dibuja los pines de inicio de [rutas] para mantener el mapa despejado.
  Future<void> dibujar({
    required double densidad,
    required List<Ruta> rutas,
  }) async {
    await _lineas.deleteAll();
    await _iconos.deleteAll();
    _porLinea.clear();
    _porPin.clear();

    final List<Ruta> validas = <Ruta>[
      for (final Ruta r in rutas)
        if (r.puntos.length >= 2) r,
    ];
    if (validas.isEmpty) return;

    // Solo se dibujan los pines de inicio de las rutas para no saturar el mapa con líneas.
    final pines = await _iconos
        .createMulti(<PointAnnotationOptions>[
          for (final Ruta r in validas)
            opcionesDePin(
              lat: r.puntos.first.lat,
              lng: r.puntos.first.lng,
              imagen: await imagenPin(TipoPin.rutaInicio),
              densidad: densidad,
              etiqueta: r.nombre,
            ),
        ]);
    for (int i = 0; i < pines.length; i++) {
      final PointAnnotation? pin = pines[i];
      if (pin != null) _porPin[pin.id] = validas[i].id;
    }
  }

  /// Dibuja dinámicamente en el mapa el trazado de la ruta seleccionada en azul y el pin de final.
  Future<void> seleccionarRuta(Ruta ruta, {double densidad = 2.0}) async {
    await _lineas.deleteAll();
    _porLinea.clear();
    if (_pinFinSeleccion != null) {
      try {
        await _iconos.delete(_pinFinSeleccion!);
      } catch (_) {}
      _pinFinSeleccion = null;
    }
    if (ruta.puntos.length < 2) return;

    final linea = await _lineas.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: <Position>[
            for (final PuntoRuta p in ruta.puntos) Position(p.lng, p.lat),
          ],
        ),
        lineColor: FqColors.river.toARGB32(),
        lineWidth: 5,
      ),
    );
    _porLinea[linea.id] = ruta.id;

    // Pin de meta/fin de la ruta al seleccionarla
    final PuntoRuta fin = ruta.puntos.last;
    final PointAnnotation pinFin = await _iconos.create(
      opcionesDePin(
        lat: fin.lat,
        lng: fin.lng,
        imagen: await imagenPin(TipoPin.rutaFin),
        densidad: densidad,
      ),
    );
    _pinFinSeleccion = pinFin;
    _porPin[pinFin.id] = ruta.id;
  }

  /// Limpia el trazo resaltado y el pin de fin, devolviendo el mapa a su estado limpio y despejado.
  Future<void> limpiarSeleccion() async {
    await _lineas.deleteAll();
    _porLinea.clear();
    if (_pinFinSeleccion != null) {
      try {
        await _iconos.delete(_pinFinSeleccion!);
      } catch (_) {}
      _pinFinSeleccion = null;
    }
  }
}
