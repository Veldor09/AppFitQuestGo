import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/mapa/pin_anotacion.dart';
import 'package:fit_quest_go/core/mapa/pin_icono.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';

/// Mapa Mapbox con el trazo de una ruta dibujado encima: linea azul, punto
/// verde al inicio y rojo al final, con la camara ajustada para que quepa todo.
/// Se usa en el resumen de una grabacion y en el detalle de una ruta.
///
/// Con menos de 2 puntos no hay trazo que mostrar y en su lugar sale un aviso.
class MapaTrazoRuta extends StatefulWidget {
  const MapaTrazoRuta({super.key, required this.puntos});

  final List<PuntoRuta> puntos;

  @override
  State<MapaTrazoRuta> createState() => _MapaTrazoRutaState();
}

class _MapaTrazoRutaState extends State<MapaTrazoRuta> {
  static const String _accessToken = String.fromEnvironment('ACCESS_TOKEN');

  MapboxMap? _mapa;
  PolylineAnnotationManager? _lineas;
  PointAnnotationManager? _iconos;

  /// Camara con la que arranca el mapa, antes de ajustarla al trazo completo.
  /// Tiene que ser la MISMA instancia en cada `build`: `MapWidget` la compara
  /// por identidad y, si cambia, vuelve a mover la camara a ella; cualquier
  /// `setState` de la pantalla que lo contiene deshacia el ajuste al trazo.
  late final CameraViewportState _viewportInicial = CameraViewportState(
    center: Point(
      coordinates: Position(widget.puntos.first.lng, widget.puntos.first.lat),
    ),
    zoom: 14,
  );

  @override
  void didUpdateWidget(covariant MapaTrazoRuta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.puntos, widget.puntos)) _dibujar();
  }

  Future<void> _onMapCreated(MapboxMap mapa) async {
    _mapa = mapa;
    _lineas = await mapa.annotations.createPolylineAnnotationManager();
    final PointAnnotationManager iconos = await mapa.annotations
        .createPointAnnotationManager();
    await prepararPines(iconos);
    _iconos = iconos;
    await _dibujar();
  }

  Future<void> _dibujar() async {
    // Antes de cualquier await: el context no se usa despues de una espera.
    final double densidad = MediaQuery.devicePixelRatioOf(context);
    final MapboxMap? mapa = _mapa;
    final PolylineAnnotationManager? lineas = _lineas;
    final PointAnnotationManager? iconos = _iconos;
    final List<PuntoRuta> puntos = widget.puntos;
    if (mapa == null || lineas == null || iconos == null || puntos.length < 2) {
      return;
    }
    await lineas.deleteAll();
    await iconos.deleteAll();
    await lineas.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: <Position>[
            for (final PuntoRuta p in puntos) Position(p.lng, p.lat),
          ],
        ),
        lineColor: FqColors.river.toARGB32(),
        lineWidth: 5,
      ),
    );
    // Salida y llegada: una gota con "play" y otra con la meta.
    await iconos.createMulti(<PointAnnotationOptions>[
      opcionesDePin(
        lat: puntos.first.lat,
        lng: puntos.first.lng,
        imagen: await imagenPin(TipoPin.rutaInicio),
        densidad: densidad,
      ),
      opcionesDePin(
        lat: puntos.last.lat,
        lng: puntos.last.lng,
        imagen: await imagenPin(TipoPin.rutaFin),
        densidad: densidad,
      ),
    ]);
    final CameraOptions camara = await mapa.cameraForCoordinatesPadding(
      <Point>[
        for (final PuntoRuta p in puntos)
          Point(coordinates: Position(p.lng, p.lat)),
      ],
      CameraOptions(),
      MbxEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
      17, // tope de zoom: una ruta cortita no se acerca hasta perder contexto
      null,
    );
    await mapa.setCamera(camara);
  }

  @override
  Widget build(BuildContext context) {
    final List<PuntoRuta> puntos = widget.puntos;
    if (puntos.length < 2) {
      return _Aviso(AppLocalizations.of(context)!.detalleRutaSinTrazo);
    }
    if (_accessToken.isEmpty) {
      return const _Aviso(
        'Mapbox necesita ACCESS_TOKEN.\nInicia con --dart-define=ACCESS_TOKEN=pk…',
      );
    }
    return MapWidget(
      key: const ValueKey<String>('mapa-trazo-ruta'),
      viewport: _viewportInicial,
      onMapCreated: _onMapCreated,
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFE8EEE5),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FqColors.muted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
