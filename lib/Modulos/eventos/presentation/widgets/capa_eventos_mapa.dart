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
///
/// Si se da [alTocarEvento], tocar un area, un recorrido o cualquiera de sus
/// pines avisa con el id del evento al que pertenece (el de [ZonaEvento.eventoId]).
class CapaEventosMapa {
  CapaEventosMapa._(this.poligonos, this.lineas, this.iconos);

  /// Crea las capas sobre [mapa]. Los poligonos van primero, luego las lineas y
  /// al final los iconos: asi cada cosa queda por encima de la anterior.
  static Future<CapaEventosMapa> crear(
    MapboxMap mapa, {
    void Function(int eventoId)? alTocarEvento,
  }) async {
    final PolygonAnnotationManager poligonos = await mapa.annotations
        .createPolygonAnnotationManager();
    final PolylineAnnotationManager lineas = await mapa.annotations
        .createPolylineAnnotationManager();
    final PointAnnotationManager iconos = await mapa.annotations
        .createPointAnnotationManager();
    await prepararPines(iconos);
    final CapaEventosMapa capa = CapaEventosMapa._(poligonos, lineas, iconos)
      ..alTocarEvento = alTocarEvento;
    capa._escuchas.addAll(<Cancelable>[
      poligonos.tapEvents(
        onTap: (PolygonAnnotation a) => capa._tocar(capa._porPoligono[a.id]),
      ),
      lineas.tapEvents(
        onTap: (PolylineAnnotation a) => capa._tocar(capa._porLinea[a.id]),
      ),
      iconos.tapEvents(
        onTap: (PointAnnotation a) => capa._tocar(capa._porPin[a.id]),
      ),
    ]);
    return capa;
  }

  final PolygonAnnotationManager poligonos;

  /// Tambien lo usa quien dibuja con el dedo, para la linea que sigue al dedo.
  final PolylineAnnotationManager lineas;
  final PointAnnotationManager iconos;

  /// Se llama con el id del evento cuyo area, recorrido o pin se toco.
  void Function(int eventoId)? alTocarEvento;

  // Que evento es cada cosa dibujada (id de la anotacion -> id del evento).
  final Map<String, int> _porPoligono = <String, int>{};
  final Map<String, int> _porLinea = <String, int>{};
  final Map<String, int> _porPin = <String, int>{};
  final List<Cancelable> _escuchas = <Cancelable>[];

  void _tocar(int? eventoId) {
    if (eventoId != null) alTocarEvento?.call(eventoId);
  }

  /// Deja de escuchar los toques (al cerrarse el mapa).
  void liberar() {
    for (final Cancelable c in _escuchas) {
      c.cancel();
    }
    _escuchas.clear();
  }

  /// Borra todo y lo vuelve a dibujar. Lo "secundario" (de otras empresas) va
  /// primero y en gris, para que quede por debajo de lo propio.
  ///
  /// [pines] son los locales (nodos de abastecimiento) como pines sueltos, sin
  /// nombre. [densidad] es el `devicePixelRatio` de la pantalla.
  ///
  /// Cada pin escribe el nombre de su zona. Con [etiquetaZonas] todos los pines
  /// de las zonas propias ([areas] y [recorridos]) escriben ese texto en su
  /// lugar (vacio: ninguno); asi el editor muestra el nombre del evento que se
  /// esta escribiendo.
  Future<void> dibujar({
    required double densidad,
    String? etiquetaZonas,
    List<ZonaEvento> areas = const <ZonaEvento>[],
    List<ZonaEvento> recorridos = const <ZonaEvento>[],
    List<ZonaEvento> areasSecundarias = const <ZonaEvento>[],
    List<ZonaEvento> recorridosSecundarios = const <ZonaEvento>[],
    List<PuntoGeo> pines = const <PuntoGeo>[],
  }) async {
    await poligonos.deleteAll();
    await lineas.deleteAll();
    await iconos.deleteAll();
    _porPoligono.clear();
    _porLinea.clear();
    _porPin.clear();

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

    final _Pines pinesDe = _Pines();
    await _pinesDeZonas(pinesDe, aSec, rSec, true, densidad);
    await _pinesDeZonas(pinesDe, a, r, false, densidad, etiquetaZonas);
    for (final PuntoGeo punto in p) {
      pinesDe.agregar(
        opcionesDePin(
          lat: punto.lat,
          lng: punto.lng,
          imagen: await imagenPin(TipoPin.local),
          densidad: densidad,
        ),
        null, // un local no es de un evento
      );
    }
    if (pinesDe.opciones.isEmpty) return;
    final List<PointAnnotation?> creados = await iconos.createMulti(
      pinesDe.opciones,
    );
    for (int i = 0; i < creados.length; i++) {
      final PointAnnotation? pin = creados[i];
      final int? evento = pinesDe.eventos[i];
      if (pin != null && evento != null) _porPin[pin.id] = evento;
    }
  }

  Future<void> _relleno(
    List<ZonaEvento> zonas,
    Color color,
    double opacidad,
  ) async {
    final List<ZonaEvento> validas = <ZonaEvento>[
      for (final ZonaEvento z in zonas)
        if (z.puntos.length >= 3) z,
    ];
    if (validas.isEmpty) return;
    final List<PolygonAnnotation?> creados = await poligonos.createMulti(
      <PolygonAnnotationOptions>[
        for (final ZonaEvento z in validas)
          PolygonAnnotationOptions(
            geometry: Polygon(coordinates: <List<Position>>[_anillo(z.puntos)]),
            fillColor: color.toARGB32(),
            fillOpacity: opacidad,
            fillOutlineColor: color.toARGB32(),
          ),
      ],
    );
    for (int i = 0; i < creados.length; i++) {
      final PolygonAnnotation? anotacion = creados[i];
      final int? evento = validas[i].eventoId;
      if (anotacion != null && evento != null) {
        _porPoligono[anotacion.id] = evento;
      }
    }
  }

  Future<void> _trazo(List<ZonaEvento> zonas, Color color, double ancho) async {
    final List<ZonaEvento> validas = <ZonaEvento>[
      for (final ZonaEvento z in zonas)
        if (z.puntos.length >= 2) z,
    ];
    if (validas.isEmpty) return;
    final List<PolylineAnnotation?> creados = await lineas
        .createMulti(<PolylineAnnotationOptions>[
          for (final ZonaEvento z in validas)
            PolylineAnnotationOptions(
              geometry: LineString(coordinates: _posiciones(z.puntos)),
              lineColor: color.toARGB32(),
              lineWidth: ancho,
            ),
        ]);
    for (int i = 0; i < creados.length; i++) {
      final PolylineAnnotation? anotacion = creados[i];
      final int? evento = validas[i].eventoId;
      if (anotacion != null && evento != null) {
        _porLinea[anotacion.id] = evento;
      }
    }
  }

  /// Los pines de las zonas: la bandera del area (con su nombre) en el centro, y
  /// el caminante del recorrido (con su nombre) al inicio y la meta al final.
  Future<void> _pinesDeZonas(
    _Pines destino,
    List<ZonaEvento> areas,
    List<ZonaEvento> recorridos,
    bool secundario,
    double densidad, [
    String? etiquetaFija,
  ]) async {
    for (final ZonaEvento z in areas) {
      if (z.puntos.length < 3) continue;
      final PuntoGeo centro = centroideDe(z.puntos);
      final Uint8List imagen = await imagenPin(
        TipoPin.area,
        secundario: secundario,
      );
      destino.agregar(
        opcionesDePin(
          lat: centro.lat,
          lng: centro.lng,
          imagen: imagen,
          densidad: densidad,
          etiqueta: etiquetaFija ?? z.nombre,
          secundario: secundario,
        ),
        z.eventoId,
      );
    }
    for (final ZonaEvento z in recorridos) {
      if (z.puntos.length < 2) continue;
      destino.agregar(
        opcionesDePin(
          lat: z.puntos.first.lat,
          lng: z.puntos.first.lng,
          imagen: await imagenPin(
            TipoPin.recorridoInicio,
            secundario: secundario,
          ),
          densidad: densidad,
          etiqueta: etiquetaFija ?? z.nombre,
          secundario: secundario,
        ),
        z.eventoId,
      );
      // La meta no lleva nombre: ya lo lleva el inicio.
      destino.agregar(
        opcionesDePin(
          lat: z.puntos.last.lat,
          lng: z.puntos.last.lng,
          imagen: await imagenPin(TipoPin.recorridoFin, secundario: secundario),
          densidad: densidad,
        ),
        z.eventoId,
      );
    }
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

/// Los pines por dibujar, cada uno con el evento al que pertenece (o null).
class _Pines {
  final List<PointAnnotationOptions> opciones = <PointAnnotationOptions>[];
  final List<int?> eventos = <int?>[];

  void agregar(PointAnnotationOptions o, int? evento) {
    opciones.add(o);
    eventos.add(evento);
  }
}
