import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/catalogos/categorias_evento.dart';
import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/core/geo/formato_distancia.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/mapa/adornos_mapa.dart';
import 'package:fit_quest_go/core/mapa/mapbox_config.dart';
import 'package:fit_quest_go/core/mapa/mapbox_directions_service.dart';
import 'package:fit_quest_go/core/mapa/pin_anotacion.dart';
import 'package:fit_quest_go/core/mapa/pin_icono.dart';
import 'package:fit_quest_go/core/mapa/ubicacion_mapa.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/voz/aviso_voz.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/ficha_evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/capa_eventos_mapa.dart';
import 'package:fit_quest_go/Modulos/rutas/application/cronometro_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/application/desviacion_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/application/metricas_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/application/progreso_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// Navegación a pantalla completa hacia un evento (Cómo llegar), con la misma
/// experiencia de guiado y estética de "Iniciar recorrido" de una ruta:
///
/// - Dibuja el camino por calles (Mapbox Directions) en color lima.
/// - Dibuja "puntitos verdes" fuera de la red vial (off-road) desde la ubicación
///   del usuario hasta la calle, y desde la calle hasta el evento real.
/// - Sigue la posición del usuario en tiempo real con la cámara inclinada y
///   orientada hacia su rumbo.
/// - Avisa por voz y notifica al llegar al destino.
class RecorridoEventoScreen extends StatefulWidget {
  const RecorridoEventoScreen({
    super.key,
    required this.evento,
    this.posiciones,
    this.directions,
    this.voz,
    this.ahora,
    this.accessToken,
  });

  final Evento evento;

  /// Fábrica del stream de posiciones; en producción usa el GPS del teléfono.
  final Stream<PosicionGps> Function()? posiciones;

  /// Servicio de rutas por calles, inyectable para pruebas.
  final MapboxDirectionsService? directions;

  /// Motor de voz, inyectable para pruebas.
  final AvisoVoz? voz;

  /// Reloj inyectable para pruebas.
  final DateTime Function()? ahora;

  /// Token de Mapbox; las pruebas pasan '' para no crear el mapa nativo.
  final String? accessToken;

  @override
  State<RecorridoEventoScreen> createState() => _RecorridoEventoScreenState();
}

class _RecorridoEventoScreenState extends State<RecorridoEventoScreen>
    with WidgetsBindingObserver {
  /// A cuántos metros del evento se considera que ya llegaste.
  static const double _radioLlegadaM = 50;

  /// A cuántos metros del final del recorrido del evento se considera completado.
  static const double _radioFinalM = 30;

  /// Distancia máxima en metros para considerar que el usuario sigue sobre el camino vial.
  static const double _umbralDesviacionCaminoM = 30;

  /// Umbral en metros a partir del cual se muestran puntitos para volver a reincorporarse al recorrido oficial del evento.
  static const double _umbralPuntitosRetornoM = 20;

  /// Intervalo mínimo entre solicitudes sucesivas a Directions para reconstruir la ruta.
  static const Duration _intervaloMinimoRepedir = Duration(seconds: 4);

  static const Locale _idiomaVoz = Locale('es');

  String get _token => widget.accessToken ?? kMapboxAccessToken;

  late final MapboxDirectionsService _directions =
      widget.directions ?? MapboxDirectionsService();
  late final AvisoVoz _voz = widget.voz ?? AvisoVozTts();

  MapboxMap? _mapa;
  CapaEventosMapa? _capaEventos;
  PolylineAnnotationManager? _lineasAcercamiento;
  CircleAnnotationManager? _puntosAcercamiento;
  PolylineAnnotationManager? _lineasRutaEvento;
  PointAnnotationManager? _pinesDestino;
  DesviacionRutaDetector? _detector;
  ProgresoEnRuta? _progreso;

  static const double _pasoMinimoM = 5;

  late final CronometroRuta _cronometro = CronometroRuta(ahora: widget.ahora);
  Timer? _reloj;

  final List<PuntoRuta> _recorrido = <PuntoRuta>[];
  double get _distanciaRecorridaKm => distanciaTrazoKm(_recorrido);

  StreamSubscription<PosicionGps>? _suscripcion;

  PosicionGps? _ultima;
  double _rumbo = 0;

  bool _siguiendo = true;
  bool _silenciado = false;
  bool _haLlegado = false;
  bool _enRuta = false;
  bool _alcanzoRuta = false;
  bool _pausado = false;
  bool _finalizando = false;
  int _indiceSegmentoRuta = 0;
  bool _pidiendoCamino = false;
  DateTime? _ultimoPedidoCamino;
  bool _sinGps = false;

  RutaVial? _camino;

  bool get _tieneRuta =>
      widget.evento.recorridos.isNotEmpty &&
      widget.evento.recorridos.first.puntos.length >= 2;

  List<PuntoRuta> get _puntosRuta => _tieneRuta
      ? <PuntoRuta>[
          for (final PuntoGeo p in widget.evento.recorridos.first.puntos)
            PuntoRuta(lat: p.lat, lng: p.lng),
        ]
      : const <PuntoRuta>[];

  ({double lat, double lng})? get _destino {
    if (_tieneRuta) {
      final PuntoGeo inicio = widget.evento.recorridos.first.puntos.first;
      return (lat: inicio.lat, lng: inicio.lng);
    }
    return destinoDeEvento(widget.evento) ??
        (widget.evento.todosLosPuntos.isNotEmpty
            ? (lat: widget.evento.todosLosPuntos.first.lat, lng: widget.evento.todosLosPuntos.first.lng)
            : null);
  }

  late final CameraViewportState _viewportInicial = CameraViewportState(
    center: Point(
      coordinates: Position(
        _destino?.lng ?? -84.08,
        _destino?.lat ?? 9.93,
      ),
    ),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_tieneRuta) {
      _detector = DesviacionRutaDetector(
        trazo: _puntosRuta,
        ahora: widget.ahora,
      );
    }
    _escucharGps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reloj?.cancel();
    _suscripcion?.cancel();
    unawaited(_voz.detener());
    _capaEventos?.liberar();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _sinGps) {
      _reintentarGps();
    }
  }

  void _reintentarGps() {
    _suscripcion?.cancel();
    _suscripcion = null;
    if (mounted) setState(() => _sinGps = false);
    _escucharGps();
  }

  void _registrarPunto(PosicionGps p) {
    if (_recorrido.isNotEmpty) {
      final PuntoRuta u = _recorrido.last;
      if (distanciaMetros(u.lat, u.lng, p.lat, p.lng) < _pasoMinimoM) return;
    }
    _recorrido.add(PuntoRuta(lat: p.lat, lng: p.lng));
  }

  Future<void> _comenzarRecorrido({
    required bool avisar,
  }) async {
    if (_enRuta) return;
    _enRuta = true;
    _cronometro.iniciar();
    _reloj = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (mounted) setState(() {});
    });

    final PosicionGps? p = _ultima;
    final ({double lat, double lng})? dest = _destino;
    final double aInicio = (p != null && dest != null)
        ? distanciaMetros(p.lat, p.lng, dest.lat, dest.lng)
        : double.infinity;
    final double distRuta = p != null
        ? distanciaATrazoM(p, _puntosRuta)
        : double.infinity;

    if (aInicio <= _radioLlegadaM || distRuta <= _radioLlegadaM) {
      _alcanzoRuta = true;
      _indiceSegmentoRuta = 0;
      if (avisar) {
        _decir('Has llegado al inicio del evento. Comienza el recorrido');
      } else {
        _decir('Comienza el recorrido');
      }
      _camino = null;
      await _lineasAcercamiento?.deleteAll();
      await _puntosAcercamiento?.deleteAll();
      if (p != null) {
        _registrarPunto(p);
        _evaluarRuta(p);
        await _actualizarTrazoRutaEnMarcha(p);
      }
    } else {
      _alcanzoRuta = false;
      _indiceSegmentoRuta = 0;
      _decir('Comienza el recorrido');
      if (p != null) {
        _actualizarGuia(p);
      }
    }
    if (mounted) setState(() {});
  }

  // ───────────────────────── GPS ─────────────────────────

  void _escucharGps() {
    if (widget.posiciones == null && _ultima == null) {
      unawaited(obtenerPosicionActualRapida().then((PosicionGps? p) {
        if (p != null && mounted && _ultima == null) {
          _alRecibirPosicion(p);
        }
      }));
    }
    final Stream<PosicionGps> flujo = widget.posiciones != null
        ? widget.posiciones!()
        : posicionesGps(
            distanciaMinimaM: 3,
            segundoPlano: true,
            tituloNotificacion: 'Rumbo al evento: ${widget.evento.nombre}',
            mensajeNotificacion: 'Navegando con FitQuest Go',
          );
    _suscripcion = flujo.listen(
      _alRecibirPosicion,
      onError: (_) {
        if (mounted) setState(() => _sinGps = true);
      },
      onDone: () {
        if (mounted && _ultima == null) setState(() => _sinGps = true);
      },
    );
  }

  Future<void> _alRecibirPosicion(PosicionGps p) async {
    if (!mounted) return;
    final PosicionGps? previa = _ultima;
    if (previa != null && distanciaMetros(previa.lat, previa.lng, p.lat, p.lng) > 3) {
      _rumbo = rumboEntre(previa, p);
    }
    _ultima = p;
    _sinGps = false;

    final ({double lat, double lng})? dest = _destino;
    if (dest == null) {
      if (mounted) setState(() {});
      return;
    }

    if (!_haLlegado) {
      if (_tieneRuta) {
        if (!_enRuta) {
          final double aInicio =
              distanciaMetros(p.lat, p.lng, dest.lat, dest.lng);
          // IMPORTANTE: Solo se activa la llegada si está dentro del radio del inicio.
          // Si el camino de aproximación pasa cerca de la mitad del recorrido,
          // NO debe activarse prematuramente.
          if (aInicio <= _radioLlegadaM) {
            await _comenzarRecorrido(avisar: true);
          } else {
            _actualizarGuia(p);
          }
        } else if (!_pausado) {
          final double aInicio =
              distanciaMetros(p.lat, p.lng, dest.lat, dest.lng);
          if (!_alcanzoRuta) {
            if (aInicio <= _radioLlegadaM) {
              _alcanzoRuta = true;
              _camino = null;
              _indiceSegmentoRuta = 0;
              await _lineasAcercamiento?.deleteAll();
              await _puntosAcercamiento?.deleteAll();
              _decir('Has llegado al inicio del evento. Comienza el recorrido');
              _registrarPunto(p);
              _evaluarRuta(p);
              await _actualizarTrazoRutaEnMarcha(p);
            } else {
              _actualizarGuia(p);
            }
          } else {
            _registrarPunto(p);
            _evaluarRuta(p);
            await _actualizarTrazoRutaEnMarcha(p);
          }
        }
      } else {
        final double aDestino = distanciaMetros(p.lat, p.lng, dest.lat, dest.lng);
        if (aDestino <= _radioLlegadaM) {
          _haLlegado = true;
          _camino = null;
          await _lineasAcercamiento?.deleteAll();
          await _puntosAcercamiento?.deleteAll();
          _decir('Has llegado al evento ${widget.evento.nombre}');
          if (mounted) {
            setState(() {});
            unawaited(_mostrarResumenLlegada());
          }
        } else {
          _actualizarGuia(p);
        }
      }
    }

    if (mounted) setState(() {});
    unawaited(_seguirCamara(p));
  }

  void _actualizarGuia(PosicionGps p) {
    final ({double lat, double lng})? dest = _destino;
    if (dest == null) return;

    final DateTime ahora = (widget.ahora ?? DateTime.now)();
    final bool puedePedir = !_pidiendoCamino &&
        (_ultimoPedidoCamino == null ||
            ahora.difference(_ultimoPedidoCamino!) >= _intervaloMinimoRepedir);

    // Si aún no tenemos camino o es una línea directa previa y ya podemos pedir:
    if (_camino == null || _camino!.puntos.length < 2 || _camino!.esLineaRecta) {
      if (puedePedir) {
        unawaited(_pedirCamino(p));
      } else if (_camino == null || _camino!.puntos.length < 2) {
        _camino = RutaVial(
          puntos: <PosicionGps>[p, (lat: dest.lat, lng: dest.lng)],
          distanciaMetros: distanciaMetros(p.lat, p.lng, dest.lat, dest.lng),
          duracionSegundos: 0,
          esLineaRecta: true,
        );
        unawaited(_dibujarCamino());
      }
      return;
    }

    final ({
      double distanciaMinima,
      int indiceSegmento,
      PosicionGps puntoProyectado,
    }) infoCamino = _distanciaYMasCercanoAlCamino(p, _camino!.puntos);

    if (infoCamino.distanciaMinima > _umbralDesviacionCaminoM) {
      // El usuario se desvió del camino vial hacia el evento
      if (puedePedir) {
        unawaited(_pedirCamino(p));
      }
    } else {
      // El usuario avanza siguiendo el camino: recortamos los tramos recorridos
      final int seg = infoCamino.indiceSegmento;
      final List<PosicionGps> puntosRestantes = <PosicionGps>[
        infoCamino.puntoProyectado,
        ..._camino!.puntos.sublist(seg + 1),
      ];
      final List<PosicionGps> puntosActualizados = puntosRestantes.length >= 2
          ? puntosRestantes
          : <PosicionGps>[infoCamino.puntoProyectado, _camino!.puntos.last];

      final double distVial = _distanciaPolilineaMetros(puntosActualizados);
      final double distOffRoadInicio =
          infoCamino.distanciaMinima > 5 ? infoCamino.distanciaMinima : 0;
      final double distOffRoadFin = distanciaMetros(
        puntosActualizados.last.lat,
        puntosActualizados.last.lng,
        dest.lat,
        dest.lng,
      );
      final double distTotal = distVial +
          distOffRoadInicio +
          (distOffRoadFin > 8 ? distOffRoadFin : 0);

      _camino = RutaVial(
        puntos: puntosActualizados,
        distanciaMetros: distTotal,
        duracionSegundos: _camino!.duracionSegundos,
        esLineaRecta: false,
      );
      unawaited(_dibujarCamino());
    }
  }

  Future<void> _pedirCamino(PosicionGps origen) async {
    final ({double lat, double lng})? dest = _destino;
    if (dest == null || _pidiendoCamino) return;
    _pidiendoCamino = true;
    _ultimoPedidoCamino = (widget.ahora ?? DateTime.now)();
    try {
      final PosicionGps destino = (lat: dest.lat, lng: dest.lng);
      RutaVial? camino = await _directions.rutaHastaInicio(
        origen: origen,
        destino: destino,
        perfil: 'walking',
      );
      // Null = ya estás a menos de 30 m: trazo directo hasta el pin.
      camino ??= RutaVial(
        puntos: <PosicionGps>[origen, destino],
        distanciaMetros:
            distanciaMetros(origen.lat, origen.lng, destino.lat, destino.lng),
        duracionSegundos: 0,
        esLineaRecta: true,
      );
      if (!mounted) return;
      setState(() => _camino = camino);
      await _dibujarCamino();
    } finally {
      _pidiendoCamino = false;
    }
  }

  void _decir(String texto) {
    if (_silenciado) return;
    final Locale loc = mounted ? Localizations.localeOf(context) : _idiomaVoz;
    unawaited(_voz.decir(texto, idioma: loc));
  }

  // ───────────────────────── Matemáticas de camino ─────────────────────────

  static PosicionGps _puntoMasCercanoEnSegmentoGps(
    PosicionGps p,
    PosicionGps a,
    PosicionGps b,
  ) {
    final double lat0 = p.lat * math.pi / 180;
    final double kx = 6371000 * math.cos(lat0) * math.pi / 180;
    final double ky = 6371000 * math.pi / 180;

    final double ax = (a.lng - p.lng) * kx, ay = (a.lat - p.lat) * ky;
    final double bx = (b.lng - p.lng) * kx, by = (b.lat - p.lat) * ky;
    final double dx = bx - ax, dy = by - ay;
    final double largo2 = dx * dx + dy * dy;

    if (largo2 == 0) return a;

    final double t = (-(ax * dx + ay * dy) / largo2).clamp(0.0, 1.0);
    return (
      lat: a.lat + t * (b.lat - a.lat),
      lng: a.lng + t * (b.lng - a.lng),
    );
  }

  static ({
    double distanciaMinima,
    int indiceSegmento,
    PosicionGps puntoProyectado,
  }) _distanciaYMasCercanoAlCamino(
    PosicionGps p,
    List<PosicionGps> puntos,
  ) {
    if (puntos.length < 2) {
      if (puntos.isEmpty) {
        return (
          distanciaMinima: double.infinity,
          indiceSegmento: 0,
          puntoProyectado: p,
        );
      }
      return (
        distanciaMinima:
            distanciaMetros(p.lat, p.lng, puntos.first.lat, puntos.first.lng),
        indiceSegmento: 0,
        puntoProyectado: puntos.first,
      );
    }
    double minDist = double.infinity;
    int segMin = 0;
    PosicionGps proyMin = puntos.first;

    for (int i = 0; i < puntos.length - 1; i++) {
      final PosicionGps proy =
          _puntoMasCercanoEnSegmentoGps(p, puntos[i], puntos[i + 1]);
      final double d = distanciaMetros(p.lat, p.lng, proy.lat, proy.lng);
      if (d < minDist) {
        minDist = d;
        segMin = i;
        proyMin = proy;
      }
    }
    return (
      distanciaMinima: minDist,
      indiceSegmento: segMin,
      puntoProyectado: proyMin,
    );
  }

  static double _distanciaPolilineaMetros(List<PosicionGps> puntos) {
    if (puntos.length < 2) return 0;
    double total = 0;
    for (int i = 0; i < puntos.length - 1; i++) {
      total += distanciaMetros(
        puntos[i].lat,
        puntos[i].lng,
        puntos[i + 1].lat,
        puntos[i + 1].lng,
      );
    }
    return total;
  }

  static List<PosicionGps> _generarPuntitos(
    PosicionGps desde,
    PosicionGps hasta, {
    double espaciadoM = 7.0,
  }) {
    final double dist =
        distanciaMetros(desde.lat, desde.lng, hasta.lat, hasta.lng);
    if (dist < 4.0) return <PosicionGps>[];
    final int pasos = (dist / espaciadoM).round().clamp(1, 100);
    final List<PosicionGps> puntos = <PosicionGps>[];
    for (int i = 1; i <= pasos; i++) {
      final double t = i / (pasos + 1);
      puntos.add((
        lat: desde.lat + t * (hasta.lat - desde.lat),
        lng: desde.lng + t * (hasta.lng - desde.lng),
      ));
    }
    return puntos;
  }

  // ───────────────────────── Mapa ─────────────────────────

  Future<void> _onMapCreated(MapboxMap mapa) async {
    _mapa = mapa;
    await ocultarAdornos(mapa);
    try {
      await mapa.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          puckBearingEnabled: true,
        ),
      );
    } catch (_) {}

    _capaEventos = await CapaEventosMapa.crear(mapa);
    _lineasAcercamiento = await mapa.annotations.createPolylineAnnotationManager();
    _puntosAcercamiento = await mapa.annotations.createCircleAnnotationManager();
    _lineasRutaEvento = await mapa.annotations.createPolylineAnnotationManager();
    _pinesDestino = await mapa.annotations.createPointAnnotationManager();
    await prepararPines(_pinesDestino!);

    await _dibujarEvento();
    await _dibujarRutaEvento();
    await _dibujarCamino();

    final PosicionGps? p = _ultima;
    if (p != null) {
      if (_enRuta) {
        await _actualizarTrazoRutaEnMarcha(p);
      }
      await _seguirCamara(p);
    }
  }

  Future<void> _dibujarEvento() async {
    if (!mounted || _capaEventos == null) return;
    final double densidad = MediaQuery.devicePixelRatioOf(context);

    // Dibujar áreas y recorridos secundarios del evento mediante la capa común
    await _capaEventos!.dibujar(
      densidad: densidad,
      areas: widget.evento.areasRotuladas,
      recorridos: _tieneRuta
          ? widget.evento.recorridosRotulados.sublist(1)
          : widget.evento.recorridosRotulados,
      eventosDestacados: widget.evento.destacado ? <int>{widget.evento.id} : const <int>{},
    );

    // Pines de salida/meta o pin de llegada en el destino principal
    final ({double lat, double lng})? dest = _destino;
    if (_pinesDestino != null) {
      await _pinesDestino!.deleteAll();
      if (_tieneRuta) {
        final PuntoRuta ini = _puntosRuta.first;
        final PuntoRuta fin = _puntosRuta.last;
        await _pinesDestino!.createMulti(<PointAnnotationOptions>[
          opcionesDePin(
            lat: ini.lat,
            lng: ini.lng,
            imagen: await imagenPin(TipoPin.rutaInicio),
            densidad: densidad,
            etiqueta: widget.evento.recorridos.first.nombre,
          ),
          opcionesDePin(
            lat: fin.lat,
            lng: fin.lng,
            imagen: await imagenPin(TipoPin.rutaFin),
            densidad: densidad,
          ),
        ]);
      } else if (dest != null) {
        await _pinesDestino!.create(
          opcionesDePin(
            lat: dest.lat,
            lng: dest.lng,
            imagen: await imagenPin(TipoPin.area),
            densidad: densidad,
            etiqueta: widget.evento.nombre,
          ),
        );
      }
    }
  }

  Future<void> _dibujarRutaEvento() async {
    if (!_tieneRuta) return;
    final PolylineAnnotationManager? lineas = _lineasRutaEvento;
    if (lineas == null) return;
    await lineas.deleteAll();
    final List<PuntoRuta> puntos = _puntosRuta;
    if (puntos.length < 2) return;
    await lineas.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: <Position>[
            for (final PuntoRuta p in puntos) Position(p.lng, p.lat),
          ],
        ),
        lineColor: colorRecorridoEvento.toARGB32(),
        lineWidth: 6,
      ),
    );
  }

  /// Camino de guía en verde lima hacia el evento.
  /// Sigue la carretera con trazo sólido y proyecta "puntitos" estilo Google Maps
  /// en tramos fuera de la red vial hasta el evento.
  Future<void> _dibujarCamino() async {
    final RutaVial? camino = _camino;
    final PolylineAnnotationManager? lineas = _lineasAcercamiento;
    final CircleAnnotationManager? puntosCirculo = _puntosAcercamiento;
    if (lineas == null && puntosCirculo == null) return;
    await lineas?.deleteAll();
    await puntosCirculo?.deleteAll();
    if (camino == null) return;

    final ({double lat, double lng})? dest = _destino;
    if (dest == null) return;
    final PosicionGps destino = camino.puntos.isNotEmpty
        ? camino.puntos.last
        : (lat: dest.lat, lng: dest.lng);
    final PosicionGps? usuario = _ultima;

    if (camino.esLineaRecta) {
      // No hay carretera disponible o se está muy cerca: dibujar los puntitos
      // desde la posición actual del usuario hasta el destino (estilo Google Maps).
      final PosicionGps desde = usuario ?? camino.puntos.first;
      final List<PosicionGps> dots = _generarPuntitos(desde, destino);
      if (puntosCirculo != null && dots.isNotEmpty) {
        await puntosCirculo.createMulti(<CircleAnnotationOptions>[
          for (final PosicionGps pt in dots)
            CircleAnnotationOptions(
              geometry: Point(coordinates: Position(pt.lng, pt.lat)),
              circleColor: FqColors.volt.toARGB32(),
              circleRadius: 4.5,
              circleStrokeColor: FqColors.night.toARGB32(),
              circleStrokeWidth: 1.5,
            ),
        ]);
      }
      return;
    }

    // Hay carretera (camino vial de Mapbox):
    // 1. Trazado sólido verde sobre la carretera
    final List<PosicionGps> caminoCarretera = camino.puntos;
    if (caminoCarretera.length >= 2 && lineas != null) {
      await lineas.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: <Position>[
              for (final PosicionGps p in caminoCarretera) Position(p.lng, p.lat),
            ],
          ),
          lineColor: FqColors.volt.toARGB32(),
          lineWidth: 6,
        ),
      );
    }

    // 2. Puntitos desde el final de la carretera hasta el evento
    // cuando el evento queda en un parque, plaza, estadio o sendero.
    final List<CircleAnnotationOptions> opcionesCirculos = <CircleAnnotationOptions>[];
    final PosicionGps finCarretera = caminoCarretera.last;
    final double distFinAInicio =
        distanciaMetros(finCarretera.lat, finCarretera.lng, destino.lat, destino.lng);

    if (distFinAInicio > 8) {
      final List<PosicionGps> dots = _generarPuntitos(finCarretera, destino);
      for (final PosicionGps pt in dots) {
        opcionesCirculos.add(
          CircleAnnotationOptions(
            geometry: Point(coordinates: Position(pt.lng, pt.lat)),
            circleColor: FqColors.volt.toARGB32(),
            circleRadius: 4.5,
            circleStrokeColor: FqColors.night.toARGB32(),
            circleStrokeWidth: 1.5,
          ),
        );
      }
    }

    // 3. Si el usuario está fuera de la carretera (> 5m del asfalto),
    // proyectamos puntitos desde su posición exacta hasta la calle más cercana.
    if (usuario != null) {
      final PosicionGps inicioCarretera = caminoCarretera.first;
      final double distUsuarioACarretera =
          distanciaMetros(usuario.lat, usuario.lng, inicioCarretera.lat, inicioCarretera.lng);
      if (distUsuarioACarretera > 5) {
        final List<PosicionGps> dotsInicio =
            _generarPuntitos(usuario, inicioCarretera);
        for (final PosicionGps pt in dotsInicio) {
          opcionesCirculos.add(
            CircleAnnotationOptions(
              geometry: Point(coordinates: Position(pt.lng, pt.lat)),
              circleColor: FqColors.volt.toARGB32(),
              circleRadius: 4.5,
              circleStrokeColor: FqColors.night.toARGB32(),
              circleStrokeWidth: 1.5,
            ),
          );
        }
      }
    }

    if (puntosCirculo != null && opcionesCirculos.isNotEmpty) {
      await puntosCirculo.createMulti(opcionesCirculos);
    }
  }

  Future<void> _seguirCamara(PosicionGps p) async {
    final MapboxMap? mapa = _mapa;
    if (mapa == null || !_siguiendo) return;
    try {
      await mapa.easeTo(
        CameraOptions(
          center: Point(coordinates: Position(p.lng, p.lat)),
          zoom: 17,
          bearing: _rumbo,
          pitch: 45,
        ),
        MapAnimationOptions(duration: 800),
      );
    } catch (_) {}
  }

  Future<void> _centrar() async {
    setState(() => _siguiendo = true);
    final PosicionGps? p = _ultima;
    if (p != null) await _seguirCamara(p);
  }

  Future<void> _encuadrarEvento() async {
    final MapboxMap? mapa = _mapa;
    if (mapa == null) return;
    setState(() => _siguiendo = false);

    final List<Point> puntos = <Point>[
      for (final PuntoGeo p in widget.evento.todosLosPuntos)
        Point(coordinates: Position(p.lng, p.lat)),
      if (_destino != null)
        Point(coordinates: Position(_destino!.lng, _destino!.lat)),
      if (_ultima != null)
        Point(coordinates: Position(_ultima!.lng, _ultima!.lat)),
    ];
    if (puntos.isEmpty) return;
    try {
      final CameraOptions camara = await mapa.cameraForCoordinatesPadding(
        puntos,
        CameraOptions(),
        MbxEdgeInsets(top: 110, left: 40, bottom: 250, right: 40),
        16,
        null,
      );
      await mapa.easeTo(camara, MapAnimationOptions(duration: 800));
    } catch (_) {}
  }

  static ({
    double distanciaMinima,
    int indiceSegmento,
    PosicionGps puntoProyectado,
  }) _distanciaYMasCercanoEnRuta(
    PosicionGps p,
    List<PuntoRuta> puntos, {
    int? indiceReferencia,
  }) {
    if (puntos.length < 2) {
      if (puntos.isEmpty) {
        return (
          distanciaMinima: double.infinity,
          indiceSegmento: 0,
          puntoProyectado: p,
        );
      }
      return (
        distanciaMinima:
            distanciaMetros(p.lat, p.lng, puntos.first.lat, puntos.first.lng),
        indiceSegmento: 0,
        puntoProyectado: (lat: puntos.first.lat, lng: puntos.first.lng),
      );
    }

    double minDist = double.infinity;
    int segMin = 0;
    PosicionGps proyMin = (lat: puntos.first.lat, lng: puntos.first.lng);

    if (indiceReferencia != null) {
      final int inicio = math.max(0, indiceReferencia - 3);
      final int fin = math.min(puntos.length - 2, indiceReferencia + 5);
      for (int i = inicio; i <= fin; i++) {
        final PosicionGps proy = _puntoMasCercanoEnSegmentoGps(
          p,
          (lat: puntos[i].lat, lng: puntos[i].lng),
          (lat: puntos[i + 1].lat, lng: puntos[i + 1].lng),
        );
        final double d = distanciaMetros(p.lat, p.lng, proy.lat, proy.lng);
        if (d < minDist) {
          minDist = d;
          segMin = i;
          proyMin = proy;
        }
      }
      if (minDist <= 50) {
        return (
          distanciaMinima: minDist,
          indiceSegmento: segMin,
          puntoProyectado: proyMin,
        );
      }
    }

    minDist = double.infinity;
    for (int i = 0; i < puntos.length - 1; i++) {
      final PosicionGps proy = _puntoMasCercanoEnSegmentoGps(
        p,
        (lat: puntos[i].lat, lng: puntos[i].lng),
        (lat: puntos[i + 1].lat, lng: puntos[i + 1].lng),
      );
      final double d = distanciaMetros(p.lat, p.lng, proy.lat, proy.lng);
      if (d < minDist) {
        minDist = d;
        segMin = i;
        proyMin = proy;
      }
    }

    return (
      distanciaMinima: minDist,
      indiceSegmento: segMin,
      puntoProyectado: proyMin,
    );
  }

  void _evaluarRuta(PosicionGps p) {
    if (!_tieneRuta) return;
    _progreso = calcularProgreso(p, _puntosRuta);
    final DesviacionRutaDetector? detector = _detector;
    if (detector != null) {
      switch (detector.evaluar(p)) {
        case EventoDesviacion.desviado:
          _decir('Atención: te has desviado del recorrido del evento');
        case EventoDesviacion.regreso:
          _decir('Has regresado al recorrido del evento');
        case EventoDesviacion.ninguno:
          break;
      }
    }

    final ProgresoEnRuta? pr = _progreso;
    final PuntoGeo fin = widget.evento.recorridos.first.puntos.last;
    final double distAlFin = distanciaMetros(p.lat, p.lng, fin.lat, fin.lng);
    if (!_haLlegado &&
        pr != null &&
        (pr.restanteM <= _radioFinalM || distAlFin <= _radioFinalM) &&
        pr.progresoM > 0) {
      _haLlegado = true;
      _cronometro.pausar();
      _decir('¡Has completado el recorrido del evento!');
      unawaited(_lineasRutaEvento?.deleteAll());
      unawaited(_puntosAcercamiento?.deleteAll());
      if (mounted) {
        setState(() {});
        unawaited(_mostrarResumenLlegada());
      }
    }
  }

  Future<void> _actualizarTrazoRutaEnMarcha(PosicionGps p) async {
    if (!_tieneRuta) return;
    final List<PuntoRuta> puntosRuta = _puntosRuta;
    if (puntosRuta.length < 2) return;

    final ({
      double distanciaMinima,
      int indiceSegmento,
      PosicionGps puntoProyectado,
    }) info = _distanciaYMasCercanoEnRuta(
      p,
      puntosRuta,
      indiceReferencia: _indiceSegmentoRuta,
    );

    _indiceSegmentoRuta = info.indiceSegmento;

    // 1. Puntitos para reincorporarse si el usuario se desvía >= 20 metros.
    final CircleAnnotationManager? puntosCirculo = _puntosAcercamiento;
    if (puntosCirculo != null) {
      await puntosCirculo.deleteAll();
      if (info.distanciaMinima >= _umbralPuntitosRetornoM) {
        final List<PosicionGps> dots =
            _generarPuntitos(p, info.puntoProyectado);
        if (dots.isNotEmpty) {
          await puntosCirculo.createMulti(<CircleAnnotationOptions>[
            for (final PosicionGps pt in dots)
              CircleAnnotationOptions(
                geometry: Point(coordinates: Position(pt.lng, pt.lat)),
                circleColor: FqColors.volt.toARGB32(),
                circleRadius: 4.5,
                circleStrokeColor: FqColors.night.toARGB32(),
                circleStrokeWidth: 1.5,
              ),
          ]);
        }
      }
    }

    // 2. Trazo oficial en azul: se recorta dinámicamente desde el punto
    // proyectado hacia adelante, y se restaura si el usuario retrocede.
    final PolylineAnnotationManager? lineas = _lineasRutaEvento;
    if (lineas == null) return;

    if (_haLlegado) {
      await lineas.deleteAll();
      return;
    }

    final List<Position> restantes = <Position>[
      Position(info.puntoProyectado.lng, info.puntoProyectado.lat),
      for (int i = info.indiceSegmento + 1; i < puntosRuta.length; i++)
        Position(puntosRuta[i].lng, puntosRuta[i].lat),
    ];

    final double distAlFin = distanciaMetros(
      info.puntoProyectado.lat,
      info.puntoProyectado.lng,
      puntosRuta.last.lat,
      puntosRuta.last.lng,
    );

    // Si ya estamos a menos de _radioFinalM del final o no quedan puntos por recorrer:
    if (restantes.length < 2 || distAlFin <= _radioFinalM) {
      await lineas.deleteAll();
      return;
    }

    await lineas.deleteAll();
    await lineas.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: restantes),
        lineColor: colorRecorridoEvento.toARGB32(),
        lineWidth: 6,
      ),
    );
  }

  void _alternarPausa() {
    setState(() {
      if (_pausado) {
        _cronometro.reanudar();
        _pausado = false;
      } else {
        _cronometro.pausar();
        _pausado = true;
      }
    });
  }

  void _alternarVoz() {
    setState(() => _silenciado = !_silenciado);
    if (_silenciado) unawaited(_voz.detener());
  }

  Future<bool> _confirmar({
    required String titulo,
    required String mensaje,
    required String aceptar,
    bool peligro = false,
  }) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Seguir'),
          ),
          FilledButton(
            style: peligro
                ? FilledButton.styleFrom(backgroundColor: FqColors.risk)
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(aceptar),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _salir() async {
    if (!_enRuta) {
      Navigator.of(context).pop();
      return;
    }
    final bool salir = await _confirmar(
      titulo: '¿Salir del recorrido?',
      mensaje: 'Si sales ahora no se guardará lo que llevas.',
      aceptar: 'Salir sin guardar',
      peligro: true,
    );
    if (salir && mounted) Navigator.of(context).pop();
  }

  Future<void> _finalizar({bool confirmar = true}) async {
    if (_finalizando) return;
    if (confirmar) {
      final bool ok = await _confirmar(
        titulo: 'Finalizar recorrido',
        mensaje: '¿Quieres terminar tu recorrido del evento?',
        aceptar: 'Finalizar',
      );
      if (!ok || !mounted) return;
    }
    _finalizando = true;
    _cronometro.pausar();
    _haLlegado = true;
    _decir('¡Has completado el recorrido del evento!');
    await _lineasRutaEvento?.deleteAll();
    await _puntosAcercamiento?.deleteAll();
    if (mounted) {
      setState(() {});
      await _mostrarResumenLlegada();
    }
  }

  Future<void> _mostrarResumenLlegada() async {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    final Duration tiempo = _cronometro.transcurrido;
    final double km = _distanciaRecorridaKm;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: FqColors.night,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FqColors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: FqColors.volt.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: FqColors.volt.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _tieneRuta ? Icons.emoji_events_rounded : Icons.flag_rounded,
                    color: FqColors.volt,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _tieneRuta
                      ? '¡Has completado el recorrido!'
                      : '¡Has llegado al evento!',
                  style: const TextStyle(
                    color: FqColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.evento.nombre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_tieneRuta) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A26),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: FqColors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        _Metrica(
                          etiqueta: 'TIEMPO',
                          valor: formatoDuracion(tiempo),
                        ),
                        const _SeparadorMetrica(),
                        _Metrica(
                          etiqueta: 'DISTANCIA',
                          valor: '${km.toStringAsFixed(2)} km',
                        ),
                        const _SeparadorMetrica(),
                        _Metrica(
                          etiqueta: 'RITMO MEDIO',
                          valor: formatoRitmo(ritmoPorKm(tiempo, km)),
                          unidad: '/km',
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: FqColors.volt,
                      foregroundColor: FqColors.night,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      l10n?.comunListo ?? 'Listo',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────── UI ─────────────────────────

  ({String texto, Color color, IconData icono}) get _estado {
    final String locale = Localizations.localeOf(context).toString();
    if (_sinGps && _ultima == null) {
      return (
        texto: 'Activa la ubicación para comenzar',
        color: FqColors.risk,
        icono: Icons.location_off_rounded,
      );
    }
    if (_ultima == null) {
      return (
        texto: 'Buscando tu ubicación…',
        color: FqColors.amber,
        icono: Icons.gps_not_fixed_rounded,
      );
    }
    if (_haLlegado) {
      return (
        texto: _tieneRuta ? '¡Completaste el recorrido!' : '¡Llegaste al evento!',
        color: FqColors.voltDark,
        icono: Icons.flag_rounded,
      );
    }
    if (_tieneRuta && _enRuta) {
      if (_detector?.desviado == true) {
        final double dist = _detector?.distanciaAlTrazoM ?? 0;
        final String distStr = formatearDistancia(dist, locale: locale);
        return (
          texto: '¡Fuera de ruta! · $distStr',
          color: FqColors.risk,
          icono: Icons.warning_amber_rounded,
        );
      }
      final ProgresoEnRuta? pr = _progreso;
      final double total = (pr?.progresoM ?? 0) + (pr?.restanteM ?? 0);
      final int pct = total > 0 ? ((pr!.progresoM / total) * 100).round() : 0;
      return (
        texto: 'En ruta · $pct% completado',
        color: FqColors.voltDark,
        icono: Icons.directions_run_rounded,
      );
    }
    final PosicionGps p = _ultima!;
    final ({double lat, double lng})? dest = _destino;
    final double m = dest != null
        ? (_camino != null && !_camino!.esLineaRecta
            ? _camino!.distanciaMetros
            : distanciaMetros(p.lat, p.lng, dest.lat, dest.lng))
        : 0;
    final String distStr = formatearDistancia(m, locale: locale);
    return (
      texto: _tieneRuta ? 'Rumbo al inicio · $distStr' : 'Rumbo al evento · $distStr',
      color: FqColors.amber,
      icono: Icons.navigation_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String locale = Localizations.localeOf(context).toString();
    final PosicionGps? p = _ultima;
    final ({double lat, double lng})? dest = _destino;
    final double distanciaM = (p != null && dest != null)
        ? (_camino != null && !_camino!.esLineaRecta
            ? _camino!.distanciaMetros
            : distanciaMetros(p.lat, p.lng, dest.lat, dest.lng))
        : 0;

    // Estimación caminando a ~4.8 km/h = ~80 metros por minuto
    final int minutosAprox = _camino != null && _camino!.duracionSegundos > 0
        ? (_camino!.duracionSegundos / 60).ceil()
        : (distanciaM / 80).ceil().clamp(1, 180);

    final Duration tiempo = _cronometro.transcurrido;
    final double kmRecorrido = _distanciaRecorridaKm;
    final ProgresoEnRuta? pr = _progreso;

    final double distanciaTotalRutaM = _tieneRuta
        ? _distanciaPolilineaMetros(
            <PosicionGps>[
              for (final PuntoRuta pt in _puntosRuta)
                (lat: pt.lat, lng: pt.lng),
            ],
          )
        : 0;

    final String restanteStr = (_enRuta && _alcanzoRuta && pr != null)
        ? formatearDistancia(pr.restanteM, locale: locale)
        : formatearDistancia(distanciaTotalRutaM, locale: locale);

    return Scaffold(
      backgroundColor: FqColors.paper,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (_token.isNotEmpty)
            MapWidget(
              key: const ValueKey<String>('recorrido-evento-map'),
              styleUri: MapboxStyles.MAPBOX_STREETS,
              viewport: _viewportInicial,
              onMapCreated: _onMapCreated,
              onScrollListener: (MapContentGestureContext _) {
                if (_siguiendo) setState(() => _siguiendo = false);
              },
            )
          else
            const ColoredBox(
              color: Color(0xFFE8EEE5),
              child: Center(
                child: Text(
                  'Mapbox necesita ACCESS_TOKEN.',
                  style: TextStyle(
                    color: FqColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          // ── Cabecera flotante superior ──────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: _CabeceraRecorridoEvento(
                  nombre: widget.evento.nombre,
                  categoria: widget.evento.categoria,
                  estado: _estado,
                  silenciado: _silenciado,
                  onCerrar: _salir,
                  onVoz: _alternarVoz,
                ),
              ),
            ),
          ),

          // ── Botones de mapa flotantes ───────────────────────────────
          Positioned(
            right: 14,
            bottom: 215,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _BotonAccionMapa(
                    heroTag: 'encuadrar-evento',
                    icono: Icons.zoom_out_map_rounded,
                    tooltip: 'Ver evento completo',
                    onPressed: _encuadrarEvento,
                  ),
                  const SizedBox(height: 10),
                  _BotonAccionMapa(
                    heroTag: 'centrar-evento',
                    icono: _siguiendo
                        ? Icons.my_location_rounded
                        : Icons.location_searching_rounded,
                    activo: _siguiendo,
                    tooltip: 'Centrar en mi ubicación',
                    onPressed: _centrar,
                  ),
                ],
              ),
            ),
          ),

          // ── Panel inferior de navegación ────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                    boxShadow: FqColors.softShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (_tieneRuta) ...<Widget>[
                        Row(
                          children: <Widget>[
                            _Metrica(
                              etiqueta: 'TIEMPO',
                              valor: formatoDuracion(tiempo),
                            ),
                            const _SeparadorMetrica(),
                            _Metrica(
                              etiqueta: 'RECORRIDO',
                              valor: formatearDistancia(kmRecorrido * 1000, locale: locale),
                            ),
                            const _SeparadorMetrica(),
                            _Metrica(
                              etiqueta: (_enRuta && _alcanzoRuta) ? 'RESTANTE' : 'EVENTO',
                              valor: restanteStr,
                            ),
                            const _SeparadorMetrica(),
                            _Metrica(
                              etiqueta: 'RITMO',
                              valor: formatoRitmo(ritmoPorKm(tiempo, kmRecorrido)),
                              unidad: '/km',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (!_enRuta) ...<Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: FqColors.volt.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: FqColors.volt.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              children: <Widget>[
                                Icon(Icons.navigation_rounded, size: 16, color: FqColors.volt),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Sigue la línea verde hasta el inicio del recorrido',
                                    style: TextStyle(
                                      color: FqColors.volt,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: FqColors.volt,
                                foregroundColor: FqColors.night,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _ultima == null
                                  ? null
                                  : () => _comenzarRecorrido(avisar: false),
                              icon: const Icon(Icons.play_arrow_rounded, size: 22),
                              label: const Text(
                                'Empezar recorrido',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ),
                          ),
                        ] else ...<Widget>[
                          if (!_alcanzoRuta) ...<Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: FqColors.volt.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: FqColors.volt.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                children: <Widget>[
                                  Icon(Icons.navigation_rounded, size: 16, color: FqColors.volt),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Sigue la línea verde hasta el inicio del recorrido',
                                      style: TextStyle(
                                        color: FqColors.volt,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_haLlegado)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: FqColors.volt,
                                  foregroundColor: FqColors.night,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Ver detalles del evento',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                                ),
                              ),
                            )
                          else
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _pausado ? FqColors.amber : FqColors.volt,
                                      foregroundColor: FqColors.night,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: _finalizando ? null : _alternarPausa,
                                    icon: Icon(
                                      _pausado ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                      size: 20,
                                    ),
                                    label: Text(
                                      _pausado ? 'Reanudar' : 'Pausar',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: FqColors.risk,
                                      foregroundColor: FqColors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: _finalizando ? null : () => _finalizar(confirmar: true),
                                    icon: const Icon(Icons.stop_rounded, size: 20),
                                    label: const Text(
                                      'Finalizar recorrido',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ] else ...<Widget>[
                        Row(
                          children: <Widget>[
                            _Metrica(
                              etiqueta: 'DISTANCIA',
                              valor: formatearDistancia(distanciaM, locale: locale),
                            ),
                            const _SeparadorMetrica(),
                            _Metrica(
                              etiqueta: 'A PIE',
                              valor: '$minutosAprox min',
                            ),
                            const _SeparadorMetrica(),
                            _Metrica(
                              etiqueta: 'ESTADO',
                              valor: _haLlegado ? 'Llegaste' : 'En camino',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: (_haLlegado ? FqColors.voltDark : FqColors.volt)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (_haLlegado ? FqColors.voltDark : FqColors.volt)
                                  .withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                _haLlegado
                                    ? Icons.check_circle_rounded
                                    : Icons.navigation_rounded,
                                size: 16,
                                color: _haLlegado ? FqColors.voltDark : FqColors.volt,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _haLlegado
                                      ? '¡Has llegado al destino del evento!'
                                      : 'Sigue la línea y los puntos verdes hasta el evento',
                                  style: TextStyle(
                                    color: _haLlegado
                                        ? FqColors.voltDark
                                        : FqColors.volt,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  _haLlegado ? FqColors.volt : const Color(0xFF1E293B),
                              foregroundColor:
                                  _haLlegado ? FqColors.night : FqColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              if (_haLlegado) {
                                Navigator.of(context).pop();
                              } else {
                                setState(() => _haLlegado = true);
                                unawaited(_lineasAcercamiento?.deleteAll());
                                unawaited(_puntosAcercamiento?.deleteAll());
                                unawaited(_mostrarResumenLlegada());
                              }
                            },
                            child: Text(
                              _haLlegado ? 'Ver detalles del evento' : '¡Ya llegué!',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Widgets auxiliares ─────────────────────────

class _CabeceraRecorridoEvento extends StatelessWidget {
  const _CabeceraRecorridoEvento({
    required this.nombre,
    required this.categoria,
    required this.estado,
    required this.silenciado,
    required this.onCerrar,
    required this.onVoz,
  });

  final String nombre;
  final String categoria;
  final ({String texto, Color color, IconData icono}) estado;
  final bool silenciado;
  final VoidCallback onCerrar;
  final VoidCallback onVoz;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    final String catLabel = l10n != null ? categoriaEventoLabel(l10n, categoria) : categoria;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: FqColors.softShadow,
      ),
      child: Row(
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onCerrar,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: FqColors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FqColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: FqColors.purple.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        catLabel,
                        style: const TextStyle(
                          color: Color(0xFFC4B8F9),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: estado.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: estado.color.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(estado.icono, size: 12, color: estado.color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          estado.texto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: estado.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onVoz,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: silenciado
                      ? Colors.white.withValues(alpha: 0.06)
                      : FqColors.volt.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  silenciado
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: silenciado
                      ? FqColors.white.withValues(alpha: 0.5)
                      : FqColors.volt,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({
    required this.etiqueta,
    required this.valor,
    this.unidad,
  });

  final String etiqueta;
  final String valor;
  final String? unidad;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  valor,
                  style: const TextStyle(
                    color: FqColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (unidad != null)
                  Text(
                    unidad!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            etiqueta,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeparadorMetrica extends StatelessWidget {
  const _SeparadorMetrica();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 1,
      color: FqColors.white.withValues(alpha: 0.12),
    );
  }
}

class _BotonAccionMapa extends StatelessWidget {
  const _BotonAccionMapa({
    required this.heroTag,
    required this.icono,
    required this.onPressed,
    this.tooltip,
    this.activo = false,
  });

  final String heroTag;
  final IconData icono;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: heroTag,
      tooltip: tooltip,
      backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.92),
      foregroundColor: activo ? FqColors.volt : FqColors.white,
      elevation: 3,
      shape: CircleBorder(
        side: BorderSide(
          color: activo
              ? FqColors.volt.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.12),
          width: 1.2,
        ),
      ),
      onPressed: onPressed,
      child: Icon(icono, size: 20),
    );
  }
}
