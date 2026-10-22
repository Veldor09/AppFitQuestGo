import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/mapa/adornos_mapa.dart';
import 'package:fit_quest_go/core/mapa/capa_dibujo_mano.dart';
import 'package:fit_quest_go/core/mapa/control_ubicacion.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart' show PuntoGeo;
import 'package:fit_quest_go/Modulos/admin/data/catalogos_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/selector_actividades_catalogo.dart';
import 'package:fit_quest_go/core/mapa/ubicacion_mapa.dart';
import 'package:fit_quest_go/core/mapa/mapbox_config.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/fotos/selector_foto.dart';
import 'package:fit_quest_go/core/widgets/campo_foto.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_icono_dificultad.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/db/daos/sync_rutas_dao.dart';
import 'package:fit_quest_go/core/db/daos/tracking_dao.dart';
import 'package:fit_quest_go/Modulos/rutas/application/cronometro_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/application/metricas_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/resumen_grabacion_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/metrica_ruta.dart';

enum _ModoRuta { dibujar, gps }

/// RTE-05/06/07 · Planificar ruta. Modo "Dibujar": se traza con el dedo sobre el
/// mapa, igual que las empresas trazan sus recorridos (un trazo por arrastre,
/// varios si se quiere seguir; el lapiz alterna entre trazar y mover el mapa). Modo "Grabar GPS": cada posicion del dispositivo (con un
/// filtro de distancia minima) agrega un punto mientras se graba, con
/// cronometro, distancia y ritmo en vivo, y se puede pausar y reanudar. Al
/// detener se abre un resumen (tiempo, distancia, ritmo medio) desde donde se
/// guarda o se descarta. En ambos modos "Guardar" abre el mismo formulario y
/// crea la ruta como Privada (`POST /rutas`); la distancia se calcula sola
/// (haversine) a partir de los puntos, vengan de donde vengan.
///
/// Nota: `geolocator` se importa con prefijo (`geo.`) porque su clase
/// `Position` (lectura de GPS) colisiona por nombre con `Position` de
/// `mapbox_maps_flutter` (coordenadas del mapa, reexportada via
/// `turf`/`geotypes`) — son dos tipos distintos con el mismo nombre.
class PlanificarRutaScreen extends StatefulWidget {
  const PlanificarRutaScreen({
    super.key,
    this.api,
    this.catalogosApi,
    this.posicionStream,
    this.ahora,
    this.accessToken,
    this.permitirFallbackActividades = true,
    this.selectorFoto,
  });

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final RutaApi? api;

  /// API de catálogos inyectable para pruebas de ADM-11.
  final CatalogosApi? catalogosApi;

  /// Selector de foto del formulario de guardar, inyectable para pruebas.
  final SelectorFoto? selectorFoto;

  /// Permite usar actividades de respaldo si falla la red al planificar offline.
  final bool permitirFallbackActividades;

  /// Fabrica del stream de posicion, inyectable para pruebas. En produccion
  /// usa `Geolocator.getPositionStream`.
  final Stream<geo.Position> Function()? posicionStream;

  /// Reloj del cronometro, inyectable para pruebas. En produccion, `DateTime.now`.
  final DateTime Function()? ahora;

  /// Token de Mapbox; por defecto el de la app. Las pruebas pasan '' para no
  /// crear el mapa nativo.
  final String? accessToken;

  @override
  State<PlanificarRutaScreen> createState() => _PlanificarRutaScreenState();
}

class _PlanificarRutaScreenState extends State<PlanificarRutaScreen> {
  String get _accessToken => widget.accessToken ?? kMapboxAccessToken;
  static const double _distanciaMinimaEntrePuntosM = 8;

  late final RutaApi _api = widget.api ?? RutaApi();
  late final CronometroRuta _cronometro = CronometroRuta(ahora: widget.ahora);
  MapboxMap? _mapa;
  CircleAnnotationManager? _pines;
  PolylineAnnotationManager? _lineas;

  /// La linea que sigue al dedo mientras se traza.
  PolylineAnnotation? _previa;

  /// Cuantos puntos aporto cada trazo, para que "Deshacer" quite el ultimo
  /// trazo entero y no un punto suelto.
  final List<int> _trazos = <int>[];

  /// En modo Dibujar: el dedo traza (true) o mueve el mapa (false).
  bool _trazando = true;

  final List<PuntoRuta> _puntos = <PuntoRuta>[];
  bool _guardando = false;

  _ModoRuta _modo = _ModoRuta.dibujar;
  StreamSubscription<geo.Position>? _suscripcionGps;
  Timer? _reloj;
  bool _grabando = false;
  bool _iniciando = false;

  /// SQLite: buffer de la grabacion en curso y cola de rutas sin subir.
  final TrackingDao _tracking = TrackingDao();
  final SyncRutasDao _colaSync = SyncRutasDao();

  bool get _pausada => _cronometro.estado == EstadoCronometro.pausado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revisarSesionInterrumpida());
  }

  /// Si la app se cerro en medio de una grabacion, ofrece reanudarla, guardar
  /// lo grabado o descartarlo.
  Future<void> _revisarSesionInterrumpida() async {
    final SesionTrackingGuardada? sesion = await _tracking.recuperar();
    if (sesion == null || !mounted || _grabando) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String km = sesion.distanciaKm.toStringAsFixed(2);
    final String? decision = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.rutasGrabacionInterrumpidaTitulo),
        content: Text(
          l10n.rutasGrabacionInterrumpidaMsg(km, sesion.puntos.length),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('descartar'),
            child: Text(l10n.resumenGrabacionDescartar),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('guardar'),
            child: Text(l10n.rutasGuardarLoGrabado),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('reanudar'),
            child: Text(l10n.recorridoReanudar),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (decision) {
      case 'reanudar':
        setState(() => _modo = _ModoRuta.gps);
        await _iniciarGrabacion(retomar: sesion);
      case 'guardar':
        setState(() {
          _modo = _ModoRuta.gps;
          _puntos
            ..clear()
            ..addAll(sesion.puntos);
          _cronometro.iniciar(inicial: Duration(seconds: sesion.segundos));
          _cronometro.detener();
        });
        await _redibujar();
        await _mostrarResumen();
      default:
        await _tracking.limpiar();
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _suscripcionGps?.cancel();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _mapa = controller;
    await ocultarAdornos(controller);
    _pines = await controller.annotations.createCircleAnnotationManager();
    _lineas = await controller.annotations.createPolylineAnnotationManager();
    // Mismo criterio que FqLiveMapView: el mapa debe arrancar centrado en la
    // ubicacion real del dispositivo, no en una coordenada fija, sin importar
    // el modo (Dibujar o Grabar GPS) en el que este el usuario.
    await centrarEnUbicacionActual(controller);
  }

  /// Un trazo terminado con el dedo: se agrega a continuacion de lo que ya hay.
  Future<void> _alTrazoMano(List<PuntoGeo> trazo) async {
    if (_guardando || _modo != _ModoRuta.dibujar) return;
    setState(() {
      _puntos.addAll(<PuntoRuta>[
        for (final PuntoGeo p in trazo) PuntoRuta(lat: p.lat, lng: p.lng),
      ]);
      _trazos.add(trazo.length);
    });
    await _redibujar();
  }

  void _alTrazoCortoMano() {
    notificarInfo(AppLocalizations.of(context)!.eventoTrazoCorto);
  }

  /// La linea que sigue al dedo mientras se traza.
  Future<void> _pintarPrevia(List<PuntoGeo> enCurso) async {
    final PolylineAnnotationManager? lineas = _lineas;
    if (lineas == null || enCurso.length < 2) return;
    final LineString geometria = LineString(
      coordinates: <Position>[
        for (final PuntoGeo p in enCurso) Position(p.lng, p.lat),
      ],
    );
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

  Future<void> _deshacer() async {
    if (_puntos.isEmpty || _grabando) return;
    setState(() {
      // El ultimo trazo entero; sin trazos registrados, el ultimo punto.
      final int quitar = _trazos.isEmpty
          ? 1
          : _trazos.removeLast().clamp(1, _puntos.length);
      _puntos.removeRange(_puntos.length - quitar, _puntos.length);
    });
    await _redibujar();
  }

  Future<void> _limpiar() async {
    if (_puntos.isEmpty || _grabando) return;
    setState(() {
      _puntos.clear();
      _trazos.clear();
    });
    await _redibujar();
  }

  void _cambiarModo(_ModoRuta modo) {
    if (_grabando || _guardando) return;
    setState(() => _modo = modo);
  }

  Future<void> _iniciarGrabacion({SesionTrackingGuardada? retomar}) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() => _iniciando = true);
    try {
      // `widget.posicionStream` inyectado (tests) trae su propio stream falso:
      // no toca los platform channels reales de permisos/servicio de
      // ubicacion, que no existen fuera de un dispositivo/emulador real.
      final Stream<geo.Position> stream;
      if (widget.posicionStream != null) {
        stream = widget.posicionStream!();
      } else {
        final bool servicioActivo = await geo.Geolocator.isLocationServiceEnabled();
        if (!servicioActivo) {
          notificarError(l10n.planificarActivaUbicacion);
          return;
        }

        geo.LocationPermission permiso = await geo.Geolocator.checkPermission();
        if (permiso == geo.LocationPermission.denied) {
          permiso = await geo.Geolocator.requestPermission();
        }
        if (permiso == geo.LocationPermission.denied) {
          notificarError(l10n.planificarPermisoNecesario);
          return;
        }
        if (permiso == geo.LocationPermission.deniedForever) {
          notificarError(l10n.planificarPermisoBloqueado);
          return;
        }

        final geo.LocationSettings settings;
        if (defaultTargetPlatform == TargetPlatform.android) {
          settings = geo.AndroidSettings(
            accuracy: geo.LocationAccuracy.high,
            distanceFilter: _distanciaMinimaEntrePuntosM.toInt(),
            intervalDuration: const Duration(seconds: 2),
          );
        } else {
          settings = geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
            distanceFilter: _distanciaMinimaEntrePuntosM.toInt(),
          );
        }

        stream = geo.Geolocator.getPositionStream(
          locationSettings: settings,
        );
      }

      if (!mounted) return;
      // Una grabacion nueva empieza vacia: lo que hubiera de una anterior (o
      // dibujado a mano) se descarta, y el cronometro arranca de cero.
      setState(() {
        _puntos.clear();
        _trazos.clear();
        if (retomar != null) _puntos.addAll(retomar.puntos);
        _grabando = true;
      });
      _cronometro.iniciar(inicial: Duration(seconds: retomar?.segundos ?? 0));
      if (retomar == null) unawaited(_tracking.iniciarSesion());
      _arrancarReloj();
      unawaited(_redibujar());

      _suscripcionGps = stream.listen((geo.Position posicion) async {
        // En pausa el GPS sigue abierto (para no volver a pedir permisos al
        // reanudar) pero sus puntos no cuentan.
        if (!mounted || _pausada) return;
        final PuntoRuta punto =
            PuntoRuta(lat: posicion.latitude, lng: posicion.longitude);
        setState(() => _puntos.add(punto));
        // Buffer en SQLite: si la app muere, la grabacion se puede recuperar.
        unawaited(
          _tracking.agregarPunto(
            punto,
            _puntos.length,
            segundos: _cronometro.transcurrido.inSeconds,
            distanciaKm: _distanciaKm,
          ),
        );
        await _redibujar();
      });
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  /// Redibuja el panel cada segundo para que el cronometro corra en vivo.
  void _arrancarReloj() {
    _reloj?.cancel();
    _reloj = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (mounted) setState(() {});
    });
  }

  void _pausarGrabacion() {
    _cronometro.pausar();
    _reloj?.cancel();
    _reloj = null;
    setState(() {});
  }

  void _reanudarGrabacion() {
    _cronometro.reanudar();
    _arrancarReloj();
    setState(() {});
  }

  Future<void> _detenerGrabacion() async {
    await _suscripcionGps?.cancel();
    _suscripcionGps = null;
    _reloj?.cancel();
    _reloj = null;
    _cronometro.detener();
    if (!mounted) return;
    setState(() => _grabando = false);
    if (_puntos.isEmpty) {
      // Nada que resumir: la pantalla vuelve a su estado inicial.
      setState(_cronometro.reiniciar);
      unawaited(_tracking.limpiar());
      return;
    }
    await _mostrarResumen();
  }

  /// Pantalla de resumen al terminar. Volver atras (null) no decide nada: la
  /// ruta queda en el panel para guardarla despues.
  Future<void> _mostrarResumen() async {
    final ResultadoResumen? decision =
        await Navigator.of(context).push<ResultadoResumen>(
      MaterialPageRoute<ResultadoResumen>(
        builder: (BuildContext _) => ResumenGrabacionScreen(
          puntos: List<PuntoRuta>.of(_puntos),
          tiempo: _cronometro.transcurrido,
          distanciaKm: _distanciaKm,
        ),
      ),
    );
    if (!mounted) return;
    switch (decision) {
      case ResultadoResumen.guardar:
        await _guardar();
      case ResultadoResumen.descartar:
        await _descartarGrabacion();
      case null:
        break;
    }
  }

  Future<void> _descartarGrabacion() async {
    unawaited(_tracking.limpiar());
    setState(() {
      _puntos.clear();
      _trazos.clear();
      _cronometro.reiniciar();
    });
    await _redibujar();
  }

  Future<void> _redibujar() async {
    // Borrar las lineas tambien se lleva la que seguia al dedo.
    _previa = null;
    await _pines?.deleteAll();
    await _lineas?.deleteAll();
    for (final PuntoRuta p in _puntos) {
      await _pines?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(p.lng, p.lat)),
          circleColor: FqColors.voltDark.toARGB32(),
          circleRadius: 6,
          circleStrokeColor: FqColors.white.toARGB32(),
          circleStrokeWidth: 2,
        ),
      );
    }
    if (_puntos.length >= 2) {
      await _lineas?.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: <Position>[
              for (final PuntoRuta p in _puntos) Position(p.lng, p.lat),
            ],
          ),
          lineColor: FqColors.river.toARGB32(),
          lineWidth: 4,
        ),
      );
    }
  }

  double get _distanciaKm => distanciaTrazoKm(_puntos);

  Future<void> _guardar() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (_puntos.length < 2) return;
    final _DatosRuta? datos = await _mostrarFormulario(l10n);
    if (datos == null) return;
    setState(() => _guardando = true);
    try {
      try {
        final Ruta creada = await _api.crear(
          nombre: datos.nombre,
          actividades: datos.actividades,
          dificultad: datos.dificultad,
          distanciaKm: _distanciaKm,
          puntos: _puntos,
          visibilidad: datos.visibilidad,
        );
        // La foto va aparte del JSON: si falla, la ruta ya quedo guardada.
        final Uint8List? foto = datos.foto;
        if (foto != null) {
          try {
            await _api.subirFoto(creada.id, foto);
          } catch (_) {
            notificarError(l10n.fotoNoSubida);
          }
        }
        unawaited(_tracking.limpiar());
        if (!mounted) return;
        final String msg = datos.visibilidad == 'publica'
            ? l10n.rutasPublicadaAviso
            : 'Ruta guardada como privada.';
        notificarExito(msg);
      } on ApiException {
        rethrow; // el servidor respondio: no es un problema de red
      } catch (_) {
        // Sin conexion: la ruta se guarda en SQLite y se sube sola despues.
        final int? idLocal = await _colaSync.encolar(
          nombre: datos.nombre,
          actividades: datos.actividades,
          dificultad: datos.dificultad,
          distanciaKm: _distanciaKm,
          puntos: List<PuntoRuta>.of(_puntos),
          visibilidad: datos.visibilidad,
        );
        if (idLocal == null) rethrow;
        if (!mounted) return;
        notificarInfo(l10n.rutasGuardadaOfflineAviso);
      }
      unawaited(_tracking.limpiar());
      setState(() {
        _puntos.clear();
        _trazos.clear();
        _cronometro.reiniciar();
      });
      await _redibujar();
    } catch (_) {
      if (mounted) notificarError(l10n.planificarNoSePudoGuardar);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<_DatosRuta?> _mostrarFormulario(AppLocalizations l10n) {
    final TextEditingController nombre = TextEditingController();
    // Una o varias claves de `actividadesRuta`: se eligen, no se escriben.
    final Set<String> actividades = <String>{};
    String? errorActividades;
    bool catalogoDisponible = false;
    List<String> clavesDisponibles = <String>[];
    String dificultad = 'moderada';
    String visibilidad = 'privada';
    Uint8List? foto;
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    return showModalBottomSheet<_DatosRuta>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      l10n.planificarGuardarRutaTitulo,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.planificarPuntosYDistancia(
                        _puntos.length,
                        _distanciaKm.toStringAsFixed(1),
                      ),
                      style: const TextStyle(fontSize: 11, color: FqColors.muted),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nombre,
                      decoration: InputDecoration(labelText: l10n.comunNombre),
                      validator: (String? v) =>
                          (v == null || v.trim().isEmpty) ? l10n.comunObligatorio : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.rutasActividades,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: FqColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectorActividadesCatalogo(
                      catalogosApi: widget.catalogosApi,
                      permitirFallbackOffline:
                          widget.permitirFallbackActividades,
                      seleccion: actividades,
                      onChanged: (Set<String> seleccion) {
                        setSheetState(() {
                          actividades
                            ..clear()
                            ..addAll(seleccion);
                          errorActividades = null;
                        });
                      },
                      onEstadoCarga: (bool disponible) {
                        setSheetState(() {
                          catalogoDisponible = disponible;
                        });
                      },
                      onActividadesDisponibles: (List<String> claves) {
                        setSheetState(() {
                          clavesDisponibles = claves;
                        });
                      },
                      errorTexto: errorActividades,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: dificultad,
                      decoration: InputDecoration(labelText: l10n.rutasDificultadLabel),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'facil',
                          child: _OpcionDificultad(
                            dificultad: 'facil',
                            texto: dificultadLabel(l10n, 'facil'),
                          ),
                        ),
                        DropdownMenuItem<String>(
                          value: 'moderada',
                          child: _OpcionDificultad(
                            dificultad: 'moderada',
                            texto: dificultadLabel(l10n, 'moderada'),
                          ),
                        ),
                        DropdownMenuItem<String>(
                          value: 'dificil',
                          child: _OpcionDificultad(
                            dificultad: 'dificil',
                            texto: dificultadLabel(l10n, 'dificil'),
                          ),
                        ),
                      ],
                      onChanged: (String? v) =>
                          setSheetState(() => dificultad = v ?? dificultad),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: visibilidad,
                      decoration: InputDecoration(
                        labelText: l10n.rutasVisibilidadLabel,
                        helperText: l10n.rutasVisibilidadHelper,
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'privada',
                          child: Text(l10n.rutasVisibilidadPrivada),
                        ),
                        DropdownMenuItem<String>(
                          value: 'publica',
                          child: Text(l10n.rutasVisibilidadPublica),
                        ),
                      ],
                      onChanged: (String? v) =>
                          setSheetState(() => visibilidad = v ?? visibilidad),
                    ),
                    const SizedBox(height: 14),
                    CampoFoto(
                      foto: foto,
                      selector: widget.selectorFoto,
                      alCambiar: (Uint8List? f) =>
                          setSheetState(() => foto = f),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: !catalogoDisponible ? null : () {
                        final bool formularioOk =
                            formKey.currentState?.validate() ?? false;
                        if (actividades.isEmpty) {
                          setSheetState(
                            () => errorActividades = l10n.rutasElegiActividad,
                          );
                          return;
                        }
                        if (!formularioOk) return;
                        Navigator.of(ctx).pop(
                          _DatosRuta(
                            nombre: nombre.text.trim(),
                            // En el orden del catalogo, no del orden de toque.
                            actividades: <String>[
                              for (final String clave in clavesDisponibles)
                                if (actividades.contains(clave)) clave,
                            ],
                            dificultad: dificultad,
                            visibilidad: visibilidad,
                            foto: foto,
                          ),
                        );
                      },
                      child: Text(l10n.comunGuardar),
                    ),
                  ],
                ),
              ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (_accessToken.isNotEmpty)
          MapWidget(
            key: const ValueKey<String>('planificar-ruta-map'),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(-84.0907, 9.9281)),
              zoom: 13.5,
            ),
            onMapCreated: _onMapCreated,
          )
        else
          const ColoredBox(
            color: Color(0xFFE8EEE5),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Mapbox necesita ACCESS_TOKEN.\nInicia con --dart-define=ACCESS_TOKEN=pk…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: FqColors.muted, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        if (_modo == _ModoRuta.dibujar && _trazando && !_guardando)
          Positioned.fill(
            child: CapaDibujoMano(
              mapa: () => _mapa,
              alMover: (List<PuntoGeo> enCurso) =>
                  unawaited(_pintarPrevia(enCurso)),
              alTrazo: _alTrazoMano,
              alTrazoCorto: _alTrazoCortoMano,
            ),
          ),
        SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: _SelectorModo(
                  modo: _modo,
                  habilitado: !_grabando && !_guardando && !_iniciando,
                  onCambiar: _cambiarModo,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: FqColors.white.withValues(alpha: .97),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: FqColors.softShadow,
                  ),
                  child: Text(
                    _modo == _ModoRuta.dibujar
                        ? (_trazando
                            ? l10n.planificarModoDibujarInstruccion
                            : l10n.planificarModoMoverInstruccion)
                        : (_pausada
                            ? l10n.grabacionEnPausa(l10n.grabacionReanudar)
                            : (_grabando
                                ? l10n.planificarModoGpsGrabando
                                : l10n.planificarModoGpsInstruccion(
                                    l10n.planificarIniciarGrabacion,
                                  ))),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                    ),
                    if (_modo == _ModoRuta.dibujar) ...<Widget>[
                      const SizedBox(width: 8),
                      _BotonTrazar(
                        trazando: _trazando,
                        alCambiar: () => setState(() => _trazando = !_trazando),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: BotonMiUbicacion(mapa: () => _mapa),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FqColors.white.withValues(alpha: .97),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: FqColors.softShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (_modo == _ModoRuta.gps &&
                          _cronometro.estado != EstadoCronometro.inactivo) ...<Widget>[
                        _metricasEnVivo(l10n),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        _puntos.isEmpty
                            ? l10n.planificarSinPuntos
                            : l10n.planificarPuntosYDistancia(
                                _puntos.length,
                                _distanciaKm.toStringAsFixed(1),
                              ),
                        textAlign: _modo == _ModoRuta.gps ? TextAlign.center : null,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      _modo == _ModoRuta.dibujar
                          ? Row(
                              children: <Widget>[
                                Expanded(
                                  child: FqButton.secondary(
                                    label: l10n.planificarDeshacer,
                                    dense: true,
                                    onPressed:
                                        _puntos.isEmpty || _guardando ? null : _deshacer,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FqButton.secondary(
                                    label: l10n.planificarLimpiar,
                                    dense: true,
                                    onPressed:
                                        _puntos.isEmpty || _guardando ? null : _limpiar,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FqButton.primary(
                                    label: _guardando ? l10n.comunGuardando : l10n.comunGuardar,
                                    dense: true,
                                    onPressed: (_puntos.length < 2 || _guardando)
                                        ? null
                                        : _guardar,
                                  ),
                                ),
                              ],
                            )
                          : (_grabando
                              ? Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: FqButton.secondary(
                                        label: _pausada
                                            ? l10n.grabacionReanudar
                                            : l10n.grabacionPausar,
                                        dense: true,
                                        onPressed: _pausada
                                            ? _reanudarGrabacion
                                            : _pausarGrabacion,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FqButton.danger(
                                        label: l10n.planificarDetener,
                                        dense: true,
                                        onPressed: _detenerGrabacion,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: FqButton.secondary(
                                        label: l10n.planificarIniciarGrabacion,
                                        dense: true,
                                        onPressed: _guardando || _iniciando
                                            ? null
                                            : _iniciarGrabacion,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FqButton.primary(
                                        label: _guardando
                                            ? l10n.comunGuardando
                                            : l10n.comunGuardar,
                                        dense: true,
                                        onPressed: (_puntos.length < 2 || _guardando)
                                            ? null
                                            : _guardar,
                                      ),
                                    ),
                                  ],
                                )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Tiempo, distancia y ritmo de la sesion. Mientras graba se redibuja cada
  /// segundo; al detener queda con los valores finales.
  Widget _metricasEnVivo(AppLocalizations l10n) {
    final Duration tiempo = _cronometro.transcurrido;
    final double km = _distanciaKm;
    return Row(
      children: <Widget>[
        Expanded(
          child: MetricaRuta(
            compacta: true,
            etiqueta: l10n.grabacionTiempo,
            valor: formatoDuracion(tiempo),
          ),
        ),
        Expanded(
          child: MetricaRuta(
            compacta: true,
            etiqueta: l10n.rutasDistancia,
            valor: km.toStringAsFixed(2),
            unidad: 'km',
          ),
        ),
        Expanded(
          child: MetricaRuta(
            compacta: true,
            etiqueta: l10n.grabacionRitmo,
            valor: formatoRitmo(ritmoPorKm(tiempo, km)),
            unidad: '/km',
          ),
        ),
      ],
    );
  }
}

/// Una dificultad del selector del formulario: su carita y su nombre.
class _OpcionDificultad extends StatelessWidget {
  const _OpcionDificultad({required this.dificultad, required this.texto});

  final String dificultad;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconoDificultad(dificultad: dificultad, size: 22),
        const SizedBox(width: 10),
        Text(texto),
      ],
    );
  }
}

/// Alterna el dedo entre trazar y mover el mapa (mientras traza, el mapa no se
/// mueve: la capa de dibujo se queda con el gesto).
class _BotonTrazar extends StatelessWidget {
  const _BotonTrazar({required this.trazando, required this.alCambiar});

  final bool trazando;
  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Material(
      color: trazando ? FqColors.volt : FqColors.white,
      elevation: 3,
      shadowColor: const Color(0x3313233F),
      shape: const CircleBorder(),
      child: InkWell(
        key: const ValueKey<String>('boton-trazar'),
        customBorder: const CircleBorder(),
        onTap: alCambiar,
        child: Tooltip(
          message: trazando ? l10n.planificarMoverMapa : l10n.planificarTrazar,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              trazando ? Icons.draw_rounded : Icons.pan_tool_alt_rounded,
              size: 22,
              color: FqColors.night,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectorModo extends StatelessWidget {
  const _SelectorModo({
    required this.modo,
    required this.habilitado,
    required this.onCambiar,
  });

  final _ModoRuta modo;
  final bool habilitado;
  final ValueChanged<_ModoRuta> onCambiar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: FqColors.white.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(12),
        boxShadow: FqColors.softShadow,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _Opcion(
              label: l10n.planificarDibujar,
              seleccionado: modo == _ModoRuta.dibujar,
              habilitado: habilitado,
              onTap: () => onCambiar(_ModoRuta.dibujar),
            ),
          ),
          Expanded(
            child: _Opcion(
              label: l10n.planificarGrabarGps,
              seleccionado: modo == _ModoRuta.gps,
              habilitado: habilitado,
              onTap: () => onCambiar(_ModoRuta.gps),
            ),
          ),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.label,
    required this.seleccionado,
    required this.habilitado,
    required this.onTap,
  });

  final String label;
  final bool seleccionado;
  final bool habilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: habilitado ? onTap : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? FqColors.voltDark : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: seleccionado ? FqColors.white : FqColors.ink,
          ),
        ),
      ),
    );
  }
}

class _DatosRuta {
  const _DatosRuta({
    required this.nombre,
    required this.actividades,
    required this.dificultad,
    this.visibilidad = 'privada',
    this.foto,
  });

  final String nombre;
  final List<String> actividades;
  final String dificultad;
  final String visibilidad;

  /// La foto elegida (se sube despues de guardar la ruta).
  final Uint8List? foto;
}
