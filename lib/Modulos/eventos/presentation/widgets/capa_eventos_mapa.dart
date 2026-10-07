import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/catalogos/categorias_evento.dart';
import 'package:fit_quest_go/core/geo/centroide.dart';
import 'package:fit_quest_go/core/mapa/pin_anotacion.dart';
import 'package:fit_quest_go/core/mapa/pin_icono.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';

/// Lo que se dibuja de los eventos sobre un mapa Mapbox: las areas rellenas,
/// los recorridos como linea y, encima, los pines con forma de gota con el
/// nombre de cada trazo (una bandera en el centro de cada area, y un caminante
/// al inicio y una meta al final de cada recorrido).
///
/// La usan el mapa de la empresa, el detalle de un evento y el mapa del
/// deportista, para que los eventos se vean igual en todos lados.
class CapaEventosMapa {
  CapaEventosMapa._(this.poligonos, this.lineas, this.iconos);

  /// Crea las capas sobre [mapa]. Los poligonos van primero, luego las lineas y
  /// al final los iconos: asi cada cosa queda por encima de la anterior.
  static Future<CapaEventosMapa> crear(MapboxMap mapa) async {
    final PolygonAnnotationManager poligonos = await mapa.annotations
        .createPolygonAnnotationManager();
    final PolylineAnnotationManager lineas = await mapa.annotations
        .createPolylineAnnotationManager();
    final PointAnnotationManager iconos = await mapa.annotations
        .createPointAnnotationManager();
    await prepararPines(iconos);
    return CapaEventosMapa._(poligonos, lineas, iconos);
  }

  final PolygonAnnotationManager poligonos;

  /// Tambien lo usa quien dibuja con el dedo, para la linea que sigue al dedo.
  final PolylineAnnotationManager lineas;
  final PointAnnotationManager iconos;

  /// Borra todo y lo vuelve a dibujar. Lo "secundario" (de otras empresas) va
  /// primero y en gris, para que quede por debajo de lo propio.
  ///
  /// [pines] son los locales (nodos de abastecimiento) como pines sueltos, sin
  /// nombre. [densidad] es el `devicePixelRatio` de la pantalla.
  Future<void> dibujar({
    required double densidad,
    List<ZonaEvento> areas = const <ZonaEvento>[],
    List<ZonaEvento> recorridos = const <ZonaEvento>[],
    List<ZonaEvento> areasSecundarias = const <ZonaEvento>[],
    List<ZonaEvento> recorridosSecundarios = const <ZonaEvento>[],
    List<PuntoGeo> pines = const <PuntoGeo>[],
  }) async {
    await poligonos.deleteAll();
    await lineas.deleteAll();
    await iconos.deleteAll();

    // Copias: las listas pueden cambiar mientras se espera a Mapbox.
    final List<ZonaEvento> a = List<ZonaEvento>.of(areas);
    final List<ZonaEvento> r = List<ZonaEvento>.of(recorridos);
    final List<ZonaEvento> aSec = List<ZonaEvento>.of(areasSecundarias);
    final List<ZonaEvento> rSec = List<ZonaEvento>.of(recorridosSecundarios);
    final List<PuntoGeo> p = List<PuntoGeo>.of(pines);

    await _relleno(aSec, colorSecundarioEvento, 0.18);
    await _trazo(rSec, colorSecundarioEvento, 4);
    await _relleno(a, colorAreaEvento, 0.28);
    await _trazo(r, colorRecorridoEvento, 5);

    final List<PointAnnotationOptions> pinesDe = <PointAnnotationOptions>[
      ...await _pinesDeZonas(aSec, rSec, true, densidad),
      ...await _pinesDeZonas(a, r, false, densidad),
      if (p.isNotEmpty)
        for (final PuntoGeo punto in p)
          opcionesDePin(
            lat: punto.lat,
            lng: punto.lng,
            imagen: await imagenPin(TipoPin.local),
            densidad: densidad,
          ),
    ];
    if (pinesDe.isNotEmpty) await iconos.createMulti(pinesDe);
  }

  Future<void> _relleno(
    List<ZonaEvento> zonas,
    Color color,
    double opacidad,
  ) async {
    final List<PolygonAnnotationOptions> opciones = <PolygonAnnotationOptions>[
      for (final ZonaEvento z in zonas)
        if (z.puntos.length >= 3)
          PolygonAnnotationOptions(
            geometry: Polygon(coordinates: <List<Position>>[_anillo(z.puntos)]),
            fillColor: color.toARGB32(),
            fillOpacity: opacidad,
            fillOutlineColor: color.toARGB32(),
          ),
    ];
    if (opciones.isNotEmpty) await poligonos.createMulti(opciones);
  }

  Future<void> _trazo(List<ZonaEvento> zonas, Color color, double ancho) async {
    final List<PolylineAnnotationOptions> opciones =
        <PolylineAnnotationOptions>[
          for (final ZonaEvento z in zonas)
            if (z.puntos.length >= 2)
              PolylineAnnotationOptions(
                geometry: LineString(coordinates: _posiciones(z.puntos)),
                lineColor: color.toARGB32(),
                lineWidth: ancho,
              ),
        ];
    if (opciones.isNotEmpty) await lineas.createMulti(opciones);
  }

  /// Los pines de las zonas: la bandera del area (con su nombre) en el centro, y
  /// el caminante del recorrido (con su nombre) al inicio y la meta al final.
  Future<List<PointAnnotationOptions>> _pinesDeZonas(
    List<ZonaEvento> areas,
    List<ZonaEvento> recorridos,
    bool secundario,
    double densidad,
  ) async {
    final List<PointAnnotationOptions> opciones = <PointAnnotationOptions>[];
    for (final ZonaEvento z in areas) {
      if (z.puntos.length < 3) continue;
      final PuntoGeo centro = centroideDe(z.puntos);
      final Uint8List imagen = await imagenPin(
        TipoPin.area,
        secundario: secundario,
      );
      opciones.add(
        opcionesDePin(
          lat: centro.lat,
          lng: centro.lng,
          imagen: imagen,
          densidad: densidad,
          etiqueta: z.nombre,
          secundario: secundario,
        ),
      );
    }
    for (final ZonaEvento z in recorridos) {
      if (z.puntos.length < 2) continue;
      opciones.add(
        opcionesDePin(
          lat: z.puntos.first.lat,
          lng: z.puntos.first.lng,
          imagen: await imagenPin(
            TipoPin.recorridoInicio,
            secundario: secundario,
          ),
          densidad: densidad,
          etiqueta: z.nombre,
          secundario: secundario,
        ),
      );
      // La meta no lleva nombre: ya lo lleva el inicio.
      opciones.add(
        opcionesDePin(
          lat: z.puntos.last.lat,
          lng: z.puntos.last.lng,
          imagen: await imagenPin(TipoPin.recorridoFin, secundario: secundario),
          densidad: densidad,
        ),
      );
    }
    return opciones;
  }

  List<Position> _posiciones(List<PuntoGeo> puntos) => <Position>[
    for (final PuntoGeo p in puntos) Position(p.lng, p.lat),
  ];

  /// Un poligono de GeoJSON repite el primer punto al final para cerrarse.
  List<Position> _anillo(List<PuntoGeo> puntos) {
    final List<Position> anillo = _posiciones(puntos);
    return <Position>[...anillo, anillo.first];
  }
}
