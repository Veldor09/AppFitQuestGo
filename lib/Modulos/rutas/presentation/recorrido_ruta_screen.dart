import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/geo/distancia.dart';
import 'package:fit_quest_go/core/geo/formato_distancia.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/mapa/adornos_mapa.dart';
import 'package:fit_quest_go/core/mapa/guia_verde.dart';
import 'package:fit_quest_go/core/mapa/mapbox_config.dart';
import 'package:fit_quest_go/core/mapa/mapbox_directions_service.dart';
import 'package:fit_quest_go/core/mapa/pin_anotacion.dart';
import 'package:fit_quest_go/core/mapa/pin_icono.dart';
import 'package:fit_quest_go/core/mapa/ubicacion_mapa.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/voz/aviso_voz.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion_api.dart';
import 'package:fit_quest_go/Modulos/calificaciones/presentation/pulgares.dart';
import 'package:fit_quest_go/Modulos/rutas/application/actividades_service.dart';
import 'package:fit_quest_go/Modulos/rutas/application/cronometro_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/application/desviacion_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/application/metricas_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/application/progreso_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// Navegacion de una ruta a pantalla completa.
///
/// Fase 1 "Acercamiento": si estas lejos del inicio se dibuja el camino por
/// calles (Mapbox Directions, una sola consulta; sin red, una linea recta)
/// hasta el punto de salida. Al llegar (o con "Empezar aqui") pasa a la fase
/// 2 "En ruta": el cronometro corre, se dibuja lo que vas caminando sobre el
/// trazo oficial y se avisa por voz si te desvias. "Finalizar" registra el
/// recorrido (en el servidor, o en el telefono si no hay red).
class RecorridoRutaScreen extends StatefulWidget {
  const RecorridoRutaScreen({
    super.key,
    required this.ruta,
    this.posiciones,
    this.directions,
    this.voz,
    this.servicio,
    this.ahora,
    this.accessToken,
    this.idUsuario,
    this.calificaciones,
  });

  final Ruta ruta;

  /// Fabrica del stream de posiciones; en produccion usa el GPS del telefono.
  final Stream<PosicionGps> Function()? posiciones;

  /// Servicio de rutas por calles, inyectable para pruebas.
  final MapboxDirectionsService? directions;

  /// Motor de voz, inyectable para pruebas.
  final AvisoVoz? voz;

  /// Registro de recorridos, inyectable para pruebas.
  final ActividadesService? servicio;

  /// Reloj del cronometro, inyectable para pruebas.
  final DateTime Function()? ahora;

  /// Token de Mapbox; las pruebas pasan '' para no crear el mapa nativo.
  final String? accessToken;

  /// Id del usuario; por defecto el de la sesion.
  final int? idUsuario;

  final CalificacionApi? calificaciones;

  @override
  State<RecorridoRutaScreen> createState() => _RecorridoRutaScreenState();
}

class _RecorridoRutaScreenState extends State<RecorridoRutaScreen>
    with WidgetsBindingObserver {
  /// A cuantos metros del inicio se considera que ya llegaste.
  static const double _radioLlegadaM = 50;

  /// Metros minimos entre dos puntos guardados del recorrido.
  static const double _pasoMinimoM = 5;

  /// A cuantos metros del final se avisa que terminaste la ruta.
  static const double _radioFinalM = 30;

  /// Distancia maxima en metros para considerar que el usuario sigue sobre el camino vial de aproximacion.
  static const double _umbralDesviacionCaminoM = 30;

  /// Umbral en metros a partir del cual se muestran puntitos para volver a reincorporarse a la ruta oficial.
  static const double _umbralPuntitosRetornoM = 20;

  /// Intervalo minimo entre solicitudes sucesivas a Directions para reconstruir la ruta de aproximacion.
  static const Duration _intervaloMinimoRepedir = Duration(seconds: 4);

  static const Locale _idiomaVoz = Locale('es');

  String get _token => widget.accessToken ?? kMapboxAccessToken;

  late final MapboxDirectionsService _directions =
      widget.directions ?? MapboxDirectionsService();
  late final AvisoVoz _voz = widget.voz ?? AvisoVozTts();
  late final ActividadesService _servicio =
      widget.servicio ?? ActividadesService.instancia;
  late final CronometroRuta _cronometro = CronometroRuta(ahora: widget.ahora);
  late final DesviacionRutaDetector _detector =
      DesviacionRutaDetector(trazo: widget.ruta.puntos, ahora: widget.ahora);

  MapboxMap? _mapa;
  PolylineAnnotationManager? _lineasAcercamiento;
  CircleAnnotationManager? _puntosAcercamiento;
  PolylineAnnotationManager? _lineasRuta;
  int _indiceSegmentoRuta = 0;

  StreamSubscription<PosicionGps>? _suscripcion;
  Timer? _reloj;
  DateTime? _iniciadoEn;

  PosicionGps? _ultima;
  double _rumbo = 0;

  bool _enRuta = false;
  bool _pausado = false;
  bool _siguiendo = true;
  bool _silenciado = false;
  bool _finalizando = false;
  bool _llegoAlFinal = false;
  bool _pidiendoCamino = false;
  DateTime? _ultimoPedidoCamino;
  bool _sinGps = false;
  bool _alcanzoRuta = false;

  RutaVial? _camino;
  ProgresoEnRuta? _progreso;
  final List<PuntoRuta> _recorrido = <PuntoRuta>[];

  PuntoRuta get _inicio => widget.ruta.puntos.first;
  PuntoRuta get _fin => widget.ruta.puntos.last;

  /// Misma instancia en cada `build`: `MapWidget` la compara por identidad y,
  /// si cambiara, devolveria la camara al inicio en cada `setState`.
  late final CameraViewportState _viewportInicial = CameraViewportState(
    center: Point(coordinates: Position(_inicio.lng, _inicio.lat)),
    zoom: 14,
  );

  double get _distanciaRecorridaKm => distanciaTrazoKm(_recorrido);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  bool _gpsIniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Aqui y no en initState: la notificacion en segundo plano lleva textos
    // traducidos y el idioma solo se puede leer con el contexto ya montado.
    if (_gpsIniciado) return;
    _gpsIniciado = true;
    _escucharGps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reloj?.cancel();
    _suscripcion?.cancel();
    unawaited(_voz.detener());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && (!_enRuta || _sinGps)) {
      _reintentarGps();
    }
  }

  void _reintentarGps() {
    _suscripcion?.cancel();
    _suscripcion = null;
    if (mounted) setState(() => _sinGps = false);
    _escucharGps();
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
            tituloNotificacion:
                AppLocalizations.of(context)?.recorridoNotifTitulo(widget.ruta.nombre) ??
                'Navegando: ${widget.ruta.nombre}',
            mensajeNotificacion:
                AppLocalizations.of(context)?.recorridoNotifMensaje ??
                'Siguiendo ruta en FitQuest Go',
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

    if (!_enRuta) {
      final double aInicio =
          distanciaMetros(p.lat, p.lng, _inicio.lat, _inicio.lng);
      if (aInicio <= _radioLlegadaM) {
        await _comenzarRecorrido(avisar: true);
      } else {
        _actualizarGuia(p);
      }
    } else if (!_pausado) {
      final double aInicio =
          distanciaMetros(p.lat, p.lng, _inicio.lat, _inicio.lng);
      if (!_alcanzoRuta) {
        if (aInicio <= _radioLlegadaM) {
          _alcanzoRuta = true;
          _camino = null;
          _indiceSegmentoRuta = 0;
          await _lineasAcercamiento?.deleteAll();
          await _puntosAcercamiento?.deleteAll();
          final AppLocalizations? l10n = mounted ? AppLocalizations.of(context) : null;
          _decir(l10n?.recorridoVozLlegoInicio ?? 'Has llegado al inicio de la ruta. Comienza el recorrido');
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

    if (mounted) setState(() {});
    unawaited(_seguirCamara(p));
  }

  void _actualizarGuia(PosicionGps p) {
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
          puntos: <PosicionGps>[p, (lat: _inicio.lat, lng: _inicio.lng)],
          distanciaMetros: distanciaMetros(p.lat, p.lng, _inicio.lat, _inicio.lng),
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
      // El usuario se salió mucho del camino vial (por ejemplo, entró a otra calle o callejón).
      // Se reconstruye la ruta por calles desde su nueva ubicación hacia el inicio.
      if (puedePedir) {
        unawaited(_pedirCamino(p));
      }
    } else {
      // El usuario avanza siguiendo el camino vial: recortamos los tramos ya
      // recorridos y proyectamos su posición sobre el asfalto (no dentro de la casa).
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
        _inicio.lat,
        _inicio.lng,
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

  void _registrarPunto(PosicionGps p) {
    if (_recorrido.isNotEmpty) {
      final PuntoRuta u = _recorrido.last;
      if (distanciaMetros(u.lat, u.lng, p.lat, p.lng) < _pasoMinimoM) return;
    }
    _recorrido.add(PuntoRuta(lat: p.lat, lng: p.lng));
  }

  void _evaluarRuta(PosicionGps p) {
    _progreso = calcularProgreso(p, widget.ruta.puntos);
    final AppLocalizations? l10n = mounted ? AppLocalizations.of(context) : null;

    switch (_detector.evaluar(p)) {
      case EventoDesviacion.desviado:
        _decir(l10n?.recorridoVozDesviado ?? 'Atención: te has desviado de la ruta');
      case EventoDesviacion.regreso:
        _decir(l10n?.recorridoVozRegreso ?? 'Has regresado a la ruta');
      case EventoDesviacion.ninguno:
        break;
    }

    final ProgresoEnRuta pr = _progreso!;
    final double distAlFin = distanciaMetros(p.lat, p.lng, _fin.lat, _fin.lng);
    if (!_llegoAlFinal &&
        (pr.restanteM <= _radioFinalM || distAlFin <= _radioFinalM) &&
        pr.progresoM > 0) {
      _llegoAlFinal = true;
      _decir(l10n?.recorridoVozFinal ?? 'Has llegado al final de la ruta');
      unawaited(_lineasRuta?.deleteAll());
      unawaited(_puntosAcercamiento?.deleteAll());
      unawaited(_finalizar(confirmar: false));
    }
  }

  void _decir(String texto) {
    if (_silenciado) return;
    final Locale loc = mounted ? Localizations.localeOf(context) : _idiomaVoz;
    unawaited(_voz.decir(texto, idioma: loc));
  }

  // ───────────────────────── Fases ─────────────────────────

  Future<void> _pedirCamino(PosicionGps origen) async {
    if (_pidiendoCamino) return;
    _pidiendoCamino = true;
    _ultimoPedidoCamino = (widget.ahora ?? DateTime.now)();
    try {
      final PosicionGps destino = (lat: _inicio.lat, lng: _inicio.lng);
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

  Future<void> _comenzarRecorrido({
    required bool avisar,
  }) async {
    if (_enRuta) return;
    _enRuta = true;
    _iniciadoEn = (widget.ahora ?? DateTime.now)();
    _cronometro.iniciar();
    _reloj = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (mounted) setState(() {});
    });

    final PosicionGps? p = _ultima;
    final double aInicio = p != null
        ? distanciaMetros(p.lat, p.lng, _inicio.lat, _inicio.lng)
        : double.infinity;
    final double distRuta = p != null
        ? distanciaATrazoM(p, widget.ruta.puntos)
        : double.infinity;

    final AppLocalizations? l10n = mounted ? AppLocalizations.of(context) : null;
    if (aInicio <= _radioLlegadaM || distRuta <= _radioLlegadaM) {
      _alcanzoRuta = true;
      _indiceSegmentoRuta = 0;
      if (avisar) {
        _decir(l10n?.recorridoVozLlegoInicio ?? 'Has llegado al inicio de la ruta. Comienza el recorrido');
      } else {
        _decir(l10n?.recorridoVozComienza ?? 'Comienza el recorrido');
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
      // Inicia el cronómetro de la sesión, pero mantiene la guía vial verde
      // hacia la ruta y no empieza el recorrido hasta alcanzarla.
      _alcanzoRuta = false;
      _indiceSegmentoRuta = 0;
      _decir(l10n?.recorridoVozComienza ?? 'Comienza el recorrido');
      if (p != null) {
        _actualizarGuia(p);
      }
    }
    if (mounted) setState(() {});
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
    _lineasAcercamiento = await mapa.annotations.createPolylineAnnotationManager();
    _puntosAcercamiento = await mapa.annotations.createCircleAnnotationManager();
    _lineasRuta = await mapa.annotations.createPolylineAnnotationManager();
    final PointAnnotationManager iconos =
        await mapa.annotations.createPointAnnotationManager();
    await prepararPines(iconos);

    await _dibujarRuta(iconos);
    await _dibujarCamino();

    final PosicionGps? p = _ultima;
    if (p != null) {
      if (_enRuta && _alcanzoRuta) {
        await _actualizarTrazoRutaEnMarcha(p);
      }
      await _seguirCamara(p);
    }
  }

  Future<void> _dibujarRuta(PointAnnotationManager iconos) async {
    if (!mounted) return;
    final double densidad = MediaQuery.devicePixelRatioOf(context);
    final List<PuntoRuta> puntos = widget.ruta.puntos;
    await _lineasRuta?.deleteAll();
    await _lineasRuta?.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: <Position>[
            for (final PuntoRuta p in puntos) Position(p.lng, p.lat),
          ],
        ),
        lineColor: FqColors.river.toARGB32(),
        lineWidth: 6,
      ),
    );
    await iconos.deleteAll();
    await iconos.createMulti(<PointAnnotationOptions>[
      opcionesDePin(
        lat: _inicio.lat,
        lng: _inicio.lng,
        imagen: await imagenPin(TipoPin.rutaInicio),
        densidad: densidad,
      ),
      opcionesDePin(
        lat: _fin.lat,
        lng: _fin.lng,
        imagen: await imagenPin(TipoPin.rutaFin),
        densidad: densidad,
      ),
    ]);
  }

  /// Guia en verde lima hacia el inicio de la ruta: la calle en trazo solido
  /// y puntitos donde no hay calle (hasta la calle y de la calle al inicio).
  Future<void> _dibujarCamino() async {
    final RutaVial? camino = _camino;
    await dibujarGuiaVerde(
      lineas: _lineasAcercamiento,
      puntos: _puntosAcercamiento,
      trazo: camino == null
          ? null
          : trazoGuia(
              camino: camino,
              destino: (lat: _inicio.lat, lng: _inicio.lng),
              usuario: _ultima,
            ),
    );
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

    // Si hay un índice de referencia, buscar primero en una ventana local [ref - 3 .. ref + 5]
    // para evitar saltos indeseados en circuitos cerrados o de ida y vuelta.
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

    // Búsqueda global si no hay referencia o si el usuario se alejó más de 50m.
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

  /// Actualiza dinámicamente la ruta oficial en azul recortándola hacia adelante
  /// conforme avanza el usuario, restaurándola si retrocede, y proyectando
  /// puntitos de reincorporación si se desvía 20m o más.
  Future<void> _actualizarTrazoRutaEnMarcha(PosicionGps p) async {
    final List<PuntoRuta> puntosRuta = widget.ruta.puntos;
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
        final List<PosicionGps> dots = puntitosEntre(
          p,
          info.puntoProyectado,
        );
        if (dots.isNotEmpty) {
          await puntosCirculo.createMulti(opcionesPuntitos(dots));
        }
      }
    }

    // 2. Trazo oficial en azul: se recorta dinámicamente desde el punto
    // proyectado hacia adelante, y se restaura si el usuario retrocede.
    final PolylineAnnotationManager? lineas = _lineasRuta;
    if (lineas == null) return;

    if (_llegoAlFinal || _finalizando) {
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
        lineColor: FqColors.river.toARGB32(),
        lineWidth: 6,
      ),
    );
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

  Future<void> _encuadrarRuta() async {
    final MapboxMap? mapa = _mapa;
    if (mapa == null) return;
    setState(() => _siguiendo = false);
    final List<Point> puntos = <Point>[
      for (final PuntoRuta p in widget.ruta.puntos)
        Point(coordinates: Position(p.lng, p.lat)),
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

  // ───────────────────────── Salir / finalizar ─────────────────────────

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
            child: Text(AppLocalizations.of(ctx)?.recorridoSeguir ?? 'Seguir'),
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
    final AppLocalizations? l10n = AppLocalizations.of(context);
    final bool salir = await _confirmar(
      titulo: l10n?.recorridoSalirTitulo ?? '¿Salir del recorrido?',
      mensaje: l10n?.recorridoSalirMensaje ?? 'Si sales ahora no se guardará lo que llevas.',
      aceptar: l10n?.recorridoSalirSinGuardar ?? 'Salir sin guardar',
      peligro: true,
    );
    if (salir && mounted) Navigator.of(context).pop();
  }

  Future<void> _finalizar({bool confirmar = true}) async {
    if (_finalizando) return;
    // Antes de cualquier await: el context no se usa despues de una espera.
    final int idUsuarioSesion = AuthScope.maybeOf(context)?.usuario?.id ?? 0;
    final AppLocalizations? l10n = AppLocalizations.of(context);
    if (confirmar) {
      final bool ok = await _confirmar(
        titulo: l10n?.recorridoFinalizarTitulo ?? 'Finalizar recorrido',
        mensaje: l10n?.recorridoFinalizarMensaje ?? '¿Quieres terminar y guardar tu recorrido?',
        aceptar: l10n?.recorridoFinalizarBtn ?? 'Finalizar',
      );
      if (!ok || !mounted) return;
    }

    setState(() => _finalizando = true);
    _cronometro.detener();
    _reloj?.cancel();
    unawaited(_suscripcion?.cancel());
    _suscripcion = null;
    if (confirmar) {
      unawaited(_voz.detener());
    }

    final double km = _distanciaRecorridaKm;
    final int segundos = _cronometro.transcurrido.inSeconds;
    final DateTime inicio = _iniciadoEn ?? DateTime.now();
    final DateTime fin = (widget.ahora ?? DateTime.now)();

    // Nada que registrar: el servidor exige distancia y tiempo positivos.
    if (_recorrido.length < 2 || km < 0.01 || segundos <= 0) {
      notificarInfo(l10n?.recorridoDemasiadoCorto ?? 'El recorrido fue demasiado corto y no se registró.');
      if (mounted) Navigator.of(context).pop(false);
      return;
    }

    final int idUsuario = widget.idUsuario ?? idUsuarioSesion;
    final ResultadoRecorrido r = await _servicio.registrar(
      idUsuario: idUsuario,
      idRuta: widget.ruta.id,
      distanciaKm: double.parse(km.toStringAsFixed(2)),
      duracionSegundos: segundos,
      iniciadoEn: inicio,
      finalizadoEn: fin,
      puntos: adelgazarTrazo(_recorrido),
    );
    if (!mounted) return;

    switch (r) {
      case ResultadoRecorrido.subido:
      case ResultadoRecorrido.guardadoLocal:
        await _mostrarResumenLlegada(
          km: km,
          tiempo: Duration(seconds: segundos),
          esOffline: r == ResultadoRecorrido.guardadoLocal,
        );
      case ResultadoRecorrido.rechazado:
        notificarError(l10n?.recorridoServidorRechazo ?? 'El servidor no aceptó el recorrido.');
      case ResultadoRecorrido.fallo:
        notificarError(l10n?.recorridoErrorGuardar ?? 'No se pudo guardar el recorrido.');
    }
    if (mounted) {
      Navigator.of(context).pop(
        r == ResultadoRecorrido.subido || r == ResultadoRecorrido.guardadoLocal,
      );
    }
  }

  Future<void> _mostrarResumenLlegada({
    required double km,
    required Duration tiempo,
    required bool esOffline,
  }) async {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
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
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 32,
                    color: FqColors.volt,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n?.recorridoLlegadaFelicidades ?? '¡Felicidades!',
                  style: const TextStyle(
                    color: FqColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n?.recorridoLlegadaDetalle(km.toStringAsFixed(2), widget.ruta.nombre) ??
                      'Recorriste ${km.toStringAsFixed(2)} km en ${widget.ruta.nombre}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: FqColors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
                        etiqueta: l10n?.recorridoMetricaTiempo ?? 'TIEMPO',
                        valor: formatoDuracion(tiempo),
                      ),
                      Container(
                        height: 32,
                        width: 1,
                        color: FqColors.white.withValues(alpha: 0.12),
                      ),
                      _Metrica(
                        etiqueta: l10n?.recorridoMetricaDistancia ?? 'DISTANCIA',
                        valor: '${km.toStringAsFixed(2)} km',
                      ),
                      Container(
                        height: 32,
                        width: 1,
                        color: FqColors.white.withValues(alpha: 0.12),
                      ),
                      _Metrica(
                        etiqueta: l10n?.recorridoMetricaRitmoMedio ?? 'RITMO MEDIO',
                        valor: formatoRitmo(ritmoPorKm(tiempo, km)),
                        unidad: '/km',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      esOffline
                          ? Icons.cloud_off_rounded
                          : Icons.cloud_done_rounded,
                      size: 14,
                      color: esOffline ? FqColors.amber : FqColors.voltDark,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        esOffline
                            ? (l10n?.recorridoGuardadoOffline ??
                                'Guardado en tu teléfono · Se sincronizará con red')
                            : (l10n?.recorridoSincronizadoPerfil ??
                                'Progreso sincronizado con tu perfil'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: esOffline ? FqColors.amber : FqColors.voltDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!esOffline) ...<Widget>[
                  const SizedBox(height: 16),
                  _CalificarRecorrido(
                    rutaId: widget.ruta.id,
                    api: widget.calificaciones,
                  ),
                ],
                const SizedBox(height: 20),
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
                    onPressed: () => Navigator.of(ctx).pop(),
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) unawaited(_salir());
      },
      child: Scaffold(
        backgroundColor: FqColors.paper,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (_token.isNotEmpty)
              MapWidget(
                key: const ValueKey<String>('recorrido-ruta-map'),
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
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: _CabeceraRecorrido(
                    nombre: widget.ruta.nombre,
                    estado: _estado,
                    silenciado: _silenciado,
                    onCerrar: _salir,
                    onVoz: _alternarVoz,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 14,
              bottom: 215,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _BotonAccionMapa(
                      heroTag: 'encuadrar-recorrido',
                      icono: Icons.zoom_out_map_rounded,
                      tooltip:
                          AppLocalizations.of(context)?.recorridoTooltipVerRutaCompleta ??
                          'Ver ruta completa',
                      onPressed: _encuadrarRuta,
                    ),
                    const SizedBox(height: 10),
                    _BotonAccionMapa(
                      heroTag: 'centrar-recorrido',
                      icono: _siguiendo
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                      activo: _siguiendo,
                      tooltip: AppLocalizations.of(context)?.recorridoTooltipCentrar ??
                          'Centrar en mi ubicación',
                      onPressed: _centrar,
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: _panelInferior(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({String texto, Color color, IconData icono}) get _estado {
    final AppLocalizations? l10n = mounted ? AppLocalizations.of(context) : null;
    final String locale = Localizations.localeOf(context).toString();
    if (_sinGps && _ultima == null) {
      return (
        texto: l10n?.recorridoEstadoActivaUbicacion ?? 'Activa la ubicación para comenzar',
        color: FqColors.risk,
        icono: Icons.location_off_rounded,
      );
    }
    if (_ultima == null) {
      return (
        texto: l10n?.recorridoEstadoBuscandoUbicacion ?? 'Buscando tu ubicación…',
        color: FqColors.amber,
        icono: Icons.gps_not_fixed_rounded,
      );
    }
    if (!_enRuta || !_alcanzoRuta) {
      final PosicionGps p = _ultima!;
      final double m = _camino != null && !_camino!.esLineaRecta
          ? _camino!.distanciaMetros
          : distanciaMetros(p.lat, p.lng, _inicio.lat, _inicio.lng);
      final String distStr = formatearDistancia(m, locale: locale);
      return (
        texto: l10n?.recorridoEstadoRumboInicio(distStr) ?? 'Rumbo al inicio · $distStr',
        color: FqColors.amber,
        icono: Icons.navigation_rounded,
      );
    }
    if (_pausado) {
      return (
        texto: l10n?.recorridoEstadoEnPausa ?? 'En pausa',
        color: FqColors.muted,
        icono: Icons.pause_circle_rounded,
      );
    }
    if (_detector.desviado) {
      final String distStr = formatearDistancia(_detector.distanciaAlTrazoM, locale: locale);
      return (
        texto: l10n?.recorridoEstadoFueraRuta(distStr) ?? '¡Fuera de ruta! · $distStr',
        color: FqColors.risk,
        icono: Icons.warning_amber_rounded,
      );
    }
    if (_llegoAlFinal) {
      return (
        texto: l10n?.recorridoEstadoLlegasteFinal ?? 'Llegaste al final · puedes finalizar',
        color: FqColors.voltDark,
        icono: Icons.flag_rounded,
      );
    }
    final ProgresoEnRuta? pr = _progreso;
    final double total = (pr?.progresoM ?? 0) + (pr?.restanteM ?? 0);
    final int pct = total > 0 ? ((pr!.progresoM / total) * 100).round() : 0;
    return (
      texto: l10n?.recorridoEstadoEnRuta(pct) ?? 'En ruta · $pct% completado',
      color: FqColors.voltDark,
      icono: Icons.directions_run_rounded,
    );
  }

  Widget _panelInferior() {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final Duration tiempo = _cronometro.transcurrido;
    final double km = _distanciaRecorridaKm;
    final ProgresoEnRuta? pr = _progreso;
    final String restante = _enRuta && _alcanzoRuta && pr != null
        ? formatearDistancia(pr.restanteM, locale: locale)
        : formatearDistancia(
            widget.ruta.distanciaKm * 1000,
            locale: locale,
          );

    return Container(
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
          Row(
            children: <Widget>[
              _Metrica(
                etiqueta: l10n?.recorridoMetricaTiempo ?? 'TIEMPO',
                valor: formatoDuracion(tiempo),
              ),
              const _SeparadorMetrica(),
              _Metrica(
                etiqueta: l10n?.recorridoMetricaRecorrido ?? 'RECORRIDO',
                valor: formatearDistancia(km * 1000, locale: locale),
              ),
              const _SeparadorMetrica(),
              _Metrica(
                etiqueta: _enRuta && _alcanzoRuta
                    ? (l10n?.recorridoMetricaRestante ?? 'RESTANTE')
                    : (l10n?.recorridoMetricaRuta ?? 'RUTA'),
                valor: restante,
              ),
              const _SeparadorMetrica(),
              _Metrica(
                etiqueta: l10n?.recorridoMetricaRitmo ?? 'RITMO',
                valor: formatoRitmo(ritmoPorKm(tiempo, km)),
                unidad: '/km',
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                  Icon(
                    Icons.navigation_rounded,
                    size: 16,
                    color: FqColors.volt,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sigue la línea verde hasta el inicio de la ruta',
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
            Row(
              children: <Widget>[
                Expanded(
                  child: _sinGps && _ultima == null
                      ? FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: FqColors.risk,
                            foregroundColor: FqColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () async {
                            await abrirConfiguracionUbicacion();
                            _reintentarGps();
                          },
                          icon: const Icon(Icons.location_on_rounded),
                          label: Text(
                            l10n?.recorridoEstadoActivaUbicacion ?? 'Activar ubicación',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        )
                      : FilledButton.icon(
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
                              : () => _comenzarRecorrido(
                                    avisar: false,
                                  ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: Text(
                            l10n?.recorridoEmpezarAqui ?? 'Empezar aquí',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                ),
              ],
            ),
          ]
          else ...<Widget>[
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
                    Icon(
                      Icons.navigation_rounded,
                      size: 16,
                      color: FqColors.volt,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sigue la línea verde hasta el inicio de la ruta',
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
                      _pausado
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 20,
                    ),
                    label: Text(
                      _pausado
                          ? (l10n?.recorridoReanudar ?? 'Reanudar')
                          : (l10n?.recorridoPausar ?? 'Pausar'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
                    onPressed: _finalizando ? null : _finalizar,
                    icon: const Icon(Icons.stop_rounded, size: 20),
                    label: Text(
                      l10n?.recorridoFinalizarBtn ?? 'Finalizar',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CabeceraRecorrido extends StatelessWidget {
  const _CabeceraRecorrido({
    required this.nombre,
    required this.estado,
    required this.silenciado,
    required this.onCerrar,
    required this.onVoz,
  });

  final String nombre;
  final ({String texto, Color color, IconData icono}) estado;
  final bool silenciado;
  final VoidCallback onCerrar;
  final VoidCallback onVoz;

  @override
  Widget build(BuildContext context) {
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
                Text(
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
  const _Metrica({required this.etiqueta, required this.valor, this.unidad});

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
            child: Text(
              unidad == null ? valor : '$valor$unidad',
              style: const TextStyle(
                color: FqColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
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
      height: 28,
      width: 1,
      color: Colors.white.withValues(alpha: 0.10),
    );
  }
}

class _BotonAccionMapa extends StatelessWidget {
  const _BotonAccionMapa({
    required this.heroTag,
    required this.icono,
    required this.tooltip,
    required this.onPressed,
    this.activo = false,
  });

  final String heroTag;
  final IconData icono;
  final String tooltip;
  final VoidCallback onPressed;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: FqColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          icon: Icon(
            icono,
            color: activo ? FqColors.volt : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _CalificarRecorrido extends StatelessWidget {
  const _CalificarRecorrido({required this.rutaId, this.api});

  final int rutaId;
  final CalificacionApi? api;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    return Container(
      key: const ValueKey<String>('calificar-recorrido'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: FqColors.paper,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n?.calificarPreguntaRuta ?? '¿Cómo estuvo tu recorrido?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: FqColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          PulgaresObjeto(
            tipo: TipoCalificable.ruta,
            id: rutaId,
            api: api,
          ),
        ],
      ),
    );
  }
}
