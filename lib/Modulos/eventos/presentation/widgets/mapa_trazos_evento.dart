import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/mapa/adornos_mapa.dart';
import 'package:fit_quest_go/core/geo/simplificar_trazo.dart';
import 'package:fit_quest_go/core/mapa/mapbox_config.dart';
import 'package:fit_quest_go/core/mapa/ubicacion_mapa.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/capa_eventos_mapa.dart';

/// Que hace el dedo sobre el mapa.
enum ModoDibujo {
  /// Mover el mapa como siempre.
  ninguno,

  /// Trazar con el dedo una linea (un recorrido).
  recorrido,

  /// Trazar con el dedo el contorno de una zona (un area).
  area,
}

/// Mapa Mapbox que muestra los trazos de un evento (areas rellenas, recorridos
/// como linea) y, en un modo de dibujo, deja trazar uno nuevo con el dedo.
///
/// Mientras se dibuja, una capa transparente por encima del mapa se queda con
/// el gesto: el mapa no se mueve y cada punto del dedo se convierte en una
/// coordenada con `coordinateForPixel`. Al soltar, el trazo se simplifica y
/// llega por [onTrazoDibujado]; si es demasiado corto para ser un area o un
/// recorrido llega [onTrazoCorto] y no se dibuja nada.
class MapaTrazosEvento extends StatefulWidget {
  const MapaTrazosEvento({
    super.key,
    this.areas = const <ZonaEvento>[],
    this.recorridos = const <ZonaEvento>[],
    this.modoDibujo = ModoDibujo.ninguno,
    this.onTrazoDibujado,
    this.onTrazoCorto,
    this.centrarEnUsuario = false,
    this.areasSecundarias = const <ZonaEvento>[],
    this.recorridosSecundarios = const <ZonaEvento>[],
    this.pines = const <PuntoGeo>[],
    this.etiquetaZonas,
    this.alTocarEvento,
  });

  /// Trazos ya guardados. La lista se redibuja cuando cambia la instancia:
  /// quien edita tiene que pasar una lista nueva, no mutar la anterior.
  final List<ZonaEvento> areas;
  final List<ZonaEvento> recorridos;

  final ModoDibujo modoDibujo;

  /// Un trazo terminado: ya simplificado, y en el modo con el que se dibujo.
  final void Function(ModoDibujo modo, List<PuntoGeo> puntos)? onTrazoDibujado;
  final VoidCallback? onTrazoCorto;

  /// Sin trazos que encuadrar, mueve la camara a donde esta la persona.
  final bool centrarEnUsuario;

  /// Trazos de otros (p. ej. de otras empresas): se dibujan debajo, en gris,
  /// para distinguirlos de los propios. Igual que [areas], se redibujan cuando
  /// cambia la instancia de la lista.
  final List<ZonaEvento> areasSecundarias;
  final List<ZonaEvento> recorridosSecundarios;

  /// Lugares sueltos (nodos de abastecimiento) como pines.
  final List<PuntoGeo> pines;

  /// Si se da, todos los pines de [areas] y [recorridos] escriben este texto en
  /// vez del nombre de cada zona (el editor pasa el nombre del evento).
  final String? etiquetaZonas;

  /// Se llama con el id del evento cuya area, recorrido o pin se toca (los
  /// trazos tienen que traer su `eventoId`: ver `Evento.areasRotuladas`).
  final void Function(int eventoId)? alTocarEvento;

  @override
  State<MapaTrazosEvento> createState() => _MapaTrazosEventoState();
}

class _MapaTrazosEventoState extends State<MapaTrazosEvento> {
  /// Separacion minima, en pixeles, entre dos puntos del dedo que se conservan.
  static const double _pasoMinimoPx = 5;

  /// Un trazo no debe pasar de esto tras simplificarlo (el servidor admite 1000).
  static const int _maxPuntosTrazo = 400;

  /// Donde arranca el mapa si no hay trazos (el mismo centro que el mapa de Home).
  static const double _latInicial = 9.9281;
  static const double _lngInicial = -84.0907;

  MapboxMap? _mapa;
  CapaEventosMapa? _capa;
  PolylineAnnotation? _previa;

  /// La linea que sigue al dedo se dibuja en la misma capa de lineas.
  PolylineAnnotationManager? get _lineas => _capa?.lineas;

  /// Puntos del trazo en curso, en el orden en que el dedo los dejo.
  final List<PuntoGeo> _enCurso = <PuntoGeo>[];
  Offset? _ultimoPixel;

  /// Las conversiones pixel -> coordenada son asincronas: se encadenan para
  /// que los puntos queden en el orden del dedo aunque lleguen mezclados.
  Future<void> _cola = Future<void>.value();

  /// Misma instancia en cada `build`: `MapWidget` la compara por identidad y
  /// si cambia vuelve a mover la camara (ver `MapaTrazoRuta`).
  late final CameraViewportState _viewportInicial = CameraViewportState(
    center: _centroDeInicio(),
    zoom: _todosLosPuntos().isEmpty ? 13.5 : 14,
  );

  /// Todo lo que hay que tener a la vista: primero lo propio y, si no hay
  /// nada, lo secundario y los pines.
  List<PuntoGeo> _todosLosPuntos() {
    final List<PuntoGeo> propios = <PuntoGeo>[
      for (final ZonaEvento z in widget.areas) ...z.puntos,
      for (final ZonaEvento z in widget.recorridos) ...z.puntos,
    ];
    if (propios.isNotEmpty) return propios;
    return <PuntoGeo>[
      for (final ZonaEvento z in widget.areasSecundarias) ...z.puntos,
      for (final ZonaEvento z in widget.recorridosSecundarios) ...z.puntos,
      ...widget.pines,
    ];
  }

  Point _centroDeInicio() {
    final List<PuntoGeo> todos = _todosLosPuntos();
    if (todos.isEmpty) {
      return Point(coordinates: Position(_lngInicial, _latInicial));
    }
    return Point(coordinates: Position(todos.first.lng, todos.first.lat));
  }

  @override
  void dispose() {
    _capa?.liberar();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapaTrazosEvento oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.areas, widget.areas) ||
        !identical(oldWidget.recorridos, widget.recorridos) ||
        !identical(oldWidget.areasSecundarias, widget.areasSecundarias) ||
        !identical(
          oldWidget.recorridosSecundarios,
          widget.recorridosSecundarios,
        ) ||
        !identical(oldWidget.pines, widget.pines) ||
        oldWidget.etiquetaZonas != widget.etiquetaZonas) {
      unawaited(_dibujarTrazos());
    }
    if (oldWidget.modoDibujo != widget.modoDibujo) {
      unawaited(_descartarPrevia());
    }
  }

  Future<void> _onMapCreated(MapboxMap mapa) async {
    _mapa = mapa;
    await ocultarAdornos(mapa);
    _capa = await CapaEventosMapa.crear(
      mapa,
      // Siempre el callback actual del widget, aunque cambie despues.
      alTocarEvento: (int id) => widget.alTocarEvento?.call(id),
    );
    await _dibujarTrazos();
    final bool hayTrazos = _todosLosPuntos().isNotEmpty;
    if (hayTrazos) {
      await _encuadrar();
    } else if (widget.centrarEnUsuario) {
      await centrarEnUbicacionActual(mapa);
    }
  }

  Future<void> _dibujarTrazos() async {
    final CapaEventosMapa? capa = _capa;
    if (capa == null) return;
    // Al redibujar se borra todo, tambien la linea que sigue al dedo.
    _previa = null;
    await capa.dibujar(
      densidad: MediaQuery.devicePixelRatioOf(context),
      areas: widget.areas,
      recorridos: widget.recorridos,
      areasSecundarias: widget.areasSecundarias,
      recorridosSecundarios: widget.recorridosSecundarios,
      pines: widget.pines,
      etiquetaZonas: widget.etiquetaZonas,
    );
  }

  List<Position> _posiciones(List<PuntoGeo> puntos) => <Position>[
    for (final PuntoGeo p in puntos) Position(p.lng, p.lat),
  ];

  Future<void> _encuadrar() async {
    final MapboxMap? mapa = _mapa;
    if (mapa == null) return;
    final List<PuntoGeo> todos = _todosLosPuntos();
    if (todos.isEmpty) return;
    final CameraOptions camara = await mapa.cameraForCoordinatesPadding(
      <Point>[
        for (final PuntoGeo p in todos)
          Point(coordinates: Position(p.lng, p.lat)),
      ],
      CameraOptions(),
      MbxEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
      16.5, // un evento chiquito no se acerca hasta perder el contexto
      null,
    );
    await mapa.setCamera(camara);
  }

  // ---- Dibujo con el dedo ------------------------------------------------

  void _alEmpezar(DragStartDetails d) {
    _enCurso.clear();
    _ultimoPixel = null;
    unawaited(_descartarPrevia());
    _agregarPixel(d.localPosition);
  }

  void _alMover(DragUpdateDetails d) => _agregarPixel(d.localPosition);

  void _agregarPixel(Offset pixel) {
    final Offset? anterior = _ultimoPixel;
    if (anterior != null && (pixel - anterior).distance < _pasoMinimoPx) return;
    _ultimoPixel = pixel;
    _cola = _cola.then((_) async {
      final MapboxMap? mapa = _mapa;
      if (mapa == null || !mounted) return;
      final Point punto = await mapa.coordinateForPixel(
        ScreenCoordinate(x: pixel.dx, y: pixel.dy),
      );
      _enCurso.add(
        PuntoGeo(
          lat: punto.coordinates.lat.toDouble(),
          lng: punto.coordinates.lng.toDouble(),
        ),
      );
      await _pintarPrevia();
    });
  }

  Future<void> _alSoltar(DragEndDetails _) async {
    await _cola;
    if (!mounted) return;
    final ModoDibujo modo = widget.modoDibujo;
    final List<PuntoGeo> trazo = _simplificar(List<PuntoGeo>.of(_enCurso));
    _enCurso.clear();
    _ultimoPixel = null;
    await _descartarPrevia();
    final int minimo = modo == ModoDibujo.area ? 3 : 2;
    if (modo == ModoDibujo.ninguno) return;
    if (trazo.length < minimo) {
      widget.onTrazoCorto?.call();
      return;
    }
    widget.onTrazoDibujado?.call(modo, trazo);
  }

  /// Simplifica con tolerancia creciente hasta que el trazo es liviano.
  List<PuntoGeo> _simplificar(List<PuntoGeo> puntos) {
    double tolerancia = 3;
    List<PuntoGeo> resultado = simplificarTrazo(
      puntos,
      toleranciaM: tolerancia,
    );
    while (resultado.length > _maxPuntosTrazo && tolerancia < 500) {
      tolerancia *= 2;
      resultado = simplificarTrazo(puntos, toleranciaM: tolerancia);
    }
    return resultado;
  }

  /// La linea que sigue al dedo mientras se dibuja. En un area se cierra con
  /// el primer punto para que se vea la forma que quedara.
  Future<void> _pintarPrevia() async {
    final PolylineAnnotationManager? lineas = _lineas;
    if (lineas == null || _enCurso.length < 2) return;
    final List<PuntoGeo> puntos = widget.modoDibujo == ModoDibujo.area
        ? <PuntoGeo>[..._enCurso, _enCurso.first]
        : List<PuntoGeo>.of(_enCurso);
    final LineString geometria = LineString(coordinates: _posiciones(puntos));
    final PolylineAnnotation? previa = _previa;
    if (previa == null) {
      _previa = await lineas.create(
        PolylineAnnotationOptions(
          geometry: geometria,
          lineColor: FqColors.volt.toARGB32(),
          lineWidth: 6,
        ),
      );
    } else {
      previa.geometry = geometria;
      await lineas.update(previa);
    }
  }

  Future<void> _descartarPrevia() async {
    final PolylineAnnotation? previa = _previa;
    _previa = null;
    final PolylineAnnotationManager? lineas = _lineas;
    if (previa != null && lineas != null) await lineas.delete(previa);
  }

  @override
  Widget build(BuildContext context) {
    final bool dibujando = widget.modoDibujo != ModoDibujo.ninguno;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        MapWidget(
          key: const ValueKey<String>('mapa-trazos-evento'),
          viewport: _viewportInicial,
          onMapCreated: _onMapCreated,
        ),
        if (dibujando)
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey<String>('capa-dibujo'),
              behavior: HitTestBehavior.opaque,
              onPanStart: _alEmpezar,
              onPanUpdate: _alMover,
              onPanEnd: _alSoltar,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: FqColors.volt, width: 3),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
