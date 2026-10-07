import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/catalogos/categorias_nodo.dart';
import 'package:fit_quest_go/core/catalogos/tipos_alerta.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/mapa/mapbox_config.dart';
import 'package:fit_quest_go/core/mapa/pin_icono.dart';
import 'package:fit_quest_go/core/mapa/ubicacion_mapa.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/voz/aviso_voz.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/alertas/application/proximidad_alertas.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';
import 'package:fit_quest_go/Modulos/alertas/presentation/banner_alerta_cercana.dart';
import 'package:fit_quest_go/Modulos/alertas/presentation/formulario_alerta.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/clima/application/clima_zona.dart';
import 'package:fit_quest_go/Modulos/clima/data/alerta_clima.dart';
import 'package:fit_quest_go/Modulos/clima/data/clima_api.dart';
import 'package:fit_quest_go/Modulos/clima/presentation/banner_clima.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/ficha_nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/formulario_nodo.dart';

class HomeUsuarioScreen extends StatefulWidget {
  const HomeUsuarioScreen({
    super.key,
    this.nodoApi,
    this.alertaApi,
    this.climaApi,
    this.voz,
    this.posiciones,
  });

  /// Inyectables para pruebas; en produccion se crean los reales.
  final NodoApi? nodoApi;
  final AlertaApi? alertaApi;
  final ClimaApi? climaApi;
  final AvisoVoz? voz;

  /// Fabrica del stream de posiciones del aviso de alertas cercanas. En
  /// produccion usa el GPS del dispositivo ([posicionesGps]).
  final Stream<PosicionGps> Function()? posiciones;

  @override
  State<HomeUsuarioScreen> createState() => _HomeUsuarioScreenState();
}

class _HomeUsuarioScreenState extends State<HomeUsuarioScreen> {
  static const String _accessToken = kMapboxAccessToken;

  /// Cada cuanto se vuelven a pedir las alertas vigentes y los puntos de
  /// interes: una alerta que reporta otra persona mientras caminas tiene que
  /// poder avisarte sin reabrir la app, y un punto que otras personas votan
  /// como obsoleto tiene que salir del mapa.
  static const Duration _refrescoAlertas = Duration(seconds: 60);

  /// Cada cuanto se vuelve a preguntar el clima de la zona: cambia despacio y el
  /// servidor ademas lo guarda 10 minutos.
  static const Duration _refrescoClima = Duration(minutes: 15);

  late final NodoApi _nodoApi = widget.nodoApi ?? NodoApi();
  late final AlertaApi _alertaApi = widget.alertaApi ?? AlertaApi();
  late final ClimaApi _climaApi = widget.climaApi ?? ClimaApi();
  late final ProximidadAlertas _proximidad;
  late final ClimaZona _clima;
  Timer? _temporizadorAlertas;
  Timer? _temporizadorClima;
  AvisoVoz? _vozActiva;
  CircleAnnotationManager? _pines;
  Cancelable? _escuchaTapPines;

  /// Los locales de empresas van aparte, con su icono (una imagen, no un circulo).
  PointAnnotationManager? _iconosLocales;
  Cancelable? _escuchaTapLocales;

  /// Pin del mapa -> nodo, para abrir su ficha al tocarlo.
  final Map<String, Nodo> _nodoPorPin = <String, Nodo>{};
  final Map<String, Nodo> _localPorPin = <String, Nodo>{};
  List<Nodo> _nodos = <Nodo>[];
  List<Alerta> _alertas = <Alerta>[];
  bool _votando = false;

  /// El motor de voz se crea al primer aviso, no al abrir Home.
  AvisoVoz get _voz => _vozActiva ??= widget.voz ?? AvisoVozTts();

  int? get _usuarioId =>
      context.getInheritedWidgetOfExactType<AuthScope>()?.notifier?.usuario?.id;

  @override
  void initState() {
    super.initState();
    _proximidad = ProximidadAlertas(
      posiciones: (widget.posiciones ?? posicionesGps)(),
      usuarioId: () => _usuarioId,
      alAvisar: _avisarPorVoz,
      // El clima depende de donde estas: se pregunta en cuanto hay GPS.
      alPrimeraPosicion: (PosicionGps _) => unawaited(_clima.actualizar()),
    );
    _clima = ClimaZona(
      api: _climaApi,
      posicion: () => _proximidad.ultimaPosicion,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _proximidad.iniciar();
      _cargarNodos();
      _cargarAlertas();
    });
    _temporizadorAlertas = Timer.periodic(_refrescoAlertas, (Timer _) {
      _cargarAlertas();
      _cargarNodos();
    });
    _temporizadorClima = Timer.periodic(
      _refrescoClima,
      (Timer _) => unawaited(_clima.actualizar()),
    );
  }

  @override
  void dispose() {
    _temporizadorAlertas?.cancel();
    _temporizadorClima?.cancel();
    _escuchaTapPines?.cancel();
    _escuchaTapLocales?.cancel();
    _clima.dispose();
    _proximidad.dispose();
    _vozActiva?.detener();
    super.dispose();
  }

  void _avisarPorVoz(Alerta alerta, int metros) {
    if (!mounted) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    _voz.decir(
      l10n.alertasAvisoVoz(
        tipoAlertaLabel(l10n, alerta.tipo, otro: alerta.tipoOtro),
        metros,
      ),
      idioma: Localizations.localeOf(context),
    );
  }

  /// Voto del usuario sobre la alerta del banner. El servidor valida con la
  /// posicion enviada que este a menos de 150 m y que no haya votado antes.
  Future<void> _votar({required bool sigueAhi}) async {
    final Alerta? alerta = _proximidad.alertaCercana;
    final PosicionGps? posicion = _proximidad.ultimaPosicion;
    if (alerta == null || posicion == null || _votando) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() => _votando = true);
    try {
      final Alerta actualizada = sigueAhi
          ? await _alertaApi.confirmar(alerta.id, lat: posicion.lat, lng: posicion.lng)
          : await _alertaApi.desmentir(alerta.id, lat: posicion.lat, lng: posicion.lng);
      if (!mounted) return;
      _proximidad.descartar();
      _reemplazarAlerta(actualizada);
      notificarExito(
        sigueAhi ? l10n.alertasGraciasConfirmar : l10n.alertasGraciasDesmentir,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      notificarError(switch (e.statusCode) {
        400 => l10n.alertasVotoLejos,
        409 => l10n.alertasVotoNoNecesario,
        _ => l10n.alertasVotoError,
      });
      // 400 y 409 son definitivos: reintentar no cambia nada, asi que se cierra
      // el aviso (y con un 409 se resincroniza, la alerta ya cambio). Otro
      // codigo puede ser pasajero: el aviso queda para reintentar.
      if (e.statusCode == 400 || e.statusCode == 409) {
        _proximidad.descartar();
        if (e.statusCode == 409) unawaited(_cargarAlertas());
      }
    } catch (_) {
      // Sin red u otro fallo: el aviso queda para reintentar.
      if (mounted) notificarError(l10n.alertasVotoError);
    } finally {
      if (mounted) setState(() => _votando = false);
    }
  }

  /// Aplica a la lista local el estado que devolvio el servidor tras un voto:
  /// la alerta queda con `miVoto`, o sale de la lista si ya no esta activa.
  void _reemplazarAlerta(Alerta nueva) {
    final List<Alerta> lista = <Alerta>[
      for (final Alerta a in _alertas)
        if (a.id != nueva.id) a else if (nueva.estaActiva) nueva,
    ];
    setState(() => _alertas = lista);
    _proximidad.actualizarAlertas(lista);
    unawaited(_dibujarPines());
  }

  /// Aplica a la lista local el punto tal como quedo en el servidor tras un
  /// voto: con tu voto, o fuera del mapa si ya no esta aprobado.
  void _reemplazarNodo(Nodo nuevo) {
    if (!mounted) return;
    setState(() {
      _nodos = <Nodo>[
        for (final Nodo n in _nodos)
          if (n.id != nuevo.id) n else if (nuevo.estado == 'Aprobado') nuevo,
      ];
    });
    unawaited(_dibujarPines());
  }

  Future<void> _cargarNodos() async {
    try {
      final List<Nodo> nodos = await _nodoApi.listar();
      // La recarga es periodica: si no cambio nada no se redibujan los pines.
      if (!mounted || _mismosNodos(_nodos, nodos)) return;
      setState(() => _nodos = nodos);
      await _dibujarPines();
    } catch (_) {
      // Sin datos por ahora: el mapa queda vacio, no bloquea la pantalla.
    }
  }

  bool _mismosNodos(List<Nodo> a, List<Nodo> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].estado != b[i].estado ||
          a[i].miVoto != b[i].miVoto ||
          a[i].confirmaciones != b[i].confirmaciones ||
          a[i].obsoletos != b[i].obsoletos) {
        return false;
      }
    }
    return true;
  }

  Future<void> _cargarAlertas() async {
    try {
      final List<Alerta> alertas = await _alertaApi.listar();
      // La recarga es periodica: si no cambio nada no se redibujan los pines.
      if (!mounted || _mismasAlertas(_alertas, alertas)) return;
      setState(() => _alertas = alertas);
      _proximidad.actualizarAlertas(alertas);
      await _dibujarPines();
    } catch (_) {
      // Sin datos por ahora: el mapa queda vacio, no bloquea la pantalla.
    }
  }

  bool _mismasAlertas(List<Alerta> a, List<Alerta> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].estado != b[i].estado ||
          a[i].miVoto != b[i].miVoto) {
        return false;
      }
    }
    return true;
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    final CircleAnnotationManager pines =
        await controller.annotations.createCircleAnnotationManager();
    _pines = pines;
    _escuchaTapPines = pines.tapEvents(onTap: _onTapPin);
    // Despues de los circulos: los iconos de los locales quedan por encima.
    final PointAnnotationManager locales =
        await controller.annotations.createPointAnnotationManager();
    _iconosLocales = locales;
    _escuchaTapLocales = locales.tapEvents(onTap: _onTapLocal);
    await _dibujarPines();
    await centrarEnUbicacionActual(controller);
  }

  /// Tocar el pin de un punto de interes abre su ficha (con foto, si tiene) y,
  /// si estas cerca, deja votar si sigue ahi o ya no existe.
  void _onTapPin(CircleAnnotation pin) => _abrirFicha(_nodoPorPin[pin.id]);

  /// Lo mismo para el local de una empresa, que tiene su propio icono.
  void _onTapLocal(PointAnnotation pin) => _abrirFicha(_localPorPin[pin.id]);

  void _abrirFicha(Nodo? nodo) {
    if (nodo == null || !mounted) return;
    unawaited(
      mostrarFichaNodo(
        context,
        nodo,
        _nodoApi,
        posicionActual: () => _proximidad.ultimaPosicion,
        usuarioId: _usuarioId,
        alVotar: _reemplazarNodo,
      ),
    );
  }

  Future<void> _dibujarPines() async {
    final CircleAnnotationManager? pines = _pines;
    if (pines == null) return;
    await pines.deleteAll();
    await _iconosLocales?.deleteAll();
    _nodoPorPin.clear();
    _localPorPin.clear();
    // Copia: las listas pueden cambiar mientras se espera a Mapbox.
    final List<Nodo> todos = List<Nodo>.of(_nodos);
    final List<Alerta> alertas = List<Alerta>.of(_alertas);
    // Un local de empresa (nodo patrocinado) se ve con su icono; los demas
    // puntos de interes, como circulos del color de su categoria.
    final List<Nodo> nodos = <Nodo>[
      for (final Nodo n in todos)
        if (!n.patrocinado) n,
    ];
    final List<Nodo> locales = <Nodo>[
      for (final Nodo n in todos)
        if (n.patrocinado) n,
    ];
    if (nodos.isNotEmpty || alertas.isNotEmpty) {
      final List<CircleAnnotation?> creados =
          await pines.createMulti(<CircleAnnotationOptions>[
        for (final Nodo nodo in nodos)
          CircleAnnotationOptions(
            geometry: Point(coordinates: Position(nodo.lng, nodo.lat)),
            circleColor: colorCategoriaNodo(nodo.categoria).toARGB32(),
            circleRadius: 8,
            circleStrokeColor: FqColors.white.toARGB32(),
            circleStrokeWidth: 2,
          ),
        for (final Alerta alerta in alertas)
          CircleAnnotationOptions(
            geometry: Point(coordinates: Position(alerta.lng, alerta.lat)),
            circleColor: FqColors.risk.toARGB32(),
            circleRadius: alerta.gravedad == 'alta' ? 10 : 8,
            circleStrokeColor: FqColors.white.toARGB32(),
            circleStrokeWidth: 2,
          ),
      ]);
      // Los pines salen en el orden de las opciones: primero los nodos.
      for (int i = 0; i < nodos.length && i < creados.length; i++) {
        final CircleAnnotation? pin = creados[i];
        if (pin != null) _nodoPorPin[pin.id] = nodos[i];
      }
    }

    final PointAnnotationManager? iconos = _iconosLocales;
    if (iconos == null || locales.isEmpty) return;
    final Uint8List imagen = await imagenPin(TipoPin.local);
    final List<PointAnnotation?> iconosCreados =
        await iconos.createMulti(<PointAnnotationOptions>[
      for (final Nodo local in locales)
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(local.lng, local.lat)),
          image: imagen,
          iconSize: kPinIconSize,
        ),
    ]);
    for (int i = 0; i < locales.length && i < iconosCreados.length; i++) {
      final PointAnnotation? pin = iconosCreados[i];
      if (pin != null) _localPorPin[pin.id] = locales[i];
    }
  }

  Future<void> _onLongTap(MapContentGestureContext contexto) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Position posicion = contexto.point.coordinates;
    final double lng = posicion[0]!.toDouble();
    final double lat = posicion[1]!.toDouble();
    final String? tipo = await _elegirQueReportar(l10n);
    if (tipo == null || !mounted) return;
    if (tipo == 'nodo') {
      final Nodo? creado = await _mostrarFormularioNodo(lat: lat, lng: lng);
      if (creado == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.homeNodoEnviadoExito)),
      );
      // Sale publicado de inmediato: se trae de nuevo para que aparezca ya.
      unawaited(_cargarNodos());
    } else {
      final Alerta? creada =
          await _mostrarFormularioAlerta(lat: lat, lng: lng);
      if (creada == null || !mounted) return;
      setState(() => _alertas = <Alerta>[..._alertas, creada]);
      _proximidad.actualizarAlertas(_alertas);
      await _dibujarPines();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.homeAlertaPublicadaExito)),
      );
    }
  }

  Future<String?> _elegirQueReportar(AppLocalizations l10n) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.homeQuePublicar,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(l10n.homePuntoDeInteres),
              subtitle: Text(l10n.homePuntoDeInteresSubtitulo),
              onTap: () => Navigator.of(ctx).pop('nodo'),
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: FqColors.risk),
              title: Text(l10n.homeAlertaOpcion),
              subtitle: Text(l10n.homeAlertaOpcionSubtitulo),
              onTap: () => Navigator.of(ctx).pop('alerta'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<Nodo?> _mostrarFormularioNodo({
    required double lat,
    required double lng,
  }) {
    return showModalBottomSheet<Nodo>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext _) =>
          FormularioNodo(api: _nodoApi, lat: lat, lng: lng),
    );
  }

  Future<Alerta?> _mostrarFormularioAlerta({
    required double lat,
    required double lng,
  }) {
    return showModalBottomSheet<Alerta>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext _) =>
          FormularioAlerta(api: _alertaApi, lat: lat, lng: lng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (_accessToken.isNotEmpty)
          MapWidget(
            key: const ValueKey<String>('fitquest-map'),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(-84.0907, 9.9281)),
              zoom: 13.5,
            ),
            onMapCreated: _onMapCreated,
            onLongTapListener: _onLongTap,
          )
        else
          const _MissingTokenBackground(),
        SafeArea(
          child: Column(
            children: <Widget>[
              const _TopControls(),
              const SizedBox(height: 8),
              const _FilterChips(),
              ListenableBuilder(
                listenable: _clima,
                builder: (BuildContext context, Widget? _) {
                  final AlertaClima? aviso = _clima.principal;
                  if (aviso == null) return const SizedBox.shrink();
                  return BannerClima(
                    alerta: aviso,
                    fuente: _clima.fuente,
                    masAvisos: _clima.visibles.length - 1,
                    onCerrar: () => _clima.cerrar(aviso),
                  );
                },
              ),
              const Spacer(),
              ListenableBuilder(
                listenable: _proximidad,
                builder: (BuildContext context, Widget? _) {
                  final Alerta? alerta = _proximidad.alertaCercana;
                  if (alerta == null) return const SizedBox.shrink();
                  return BannerAlertaCercana(
                    alerta: alerta,
                    metros: _proximidad.metrosAlertaCercana ?? 0,
                    votando: _votando,
                    onSigue: () => _votar(sigueAhi: true),
                    onNoEsta: () => _votar(sigueAhi: false),
                    onCerrar: _proximidad.descartar,
                  );
                },
              ),
              const _NearbyPanel(),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopControls extends StatelessWidget {
  const _TopControls();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: _floatingDecoration(radius: 18),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.search_rounded, color: FqColors.muted, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    l10n.homeBuscarPlaceholder,
                    style: const TextStyle(color: FqColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          Container(
            width: 50,
            height: 50,
            decoration: _floatingDecoration(radius: 17),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                const Icon(Icons.notifications_none_rounded, size: 27),
                Positioned(
                  right: 9,
                  top: 9,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: FqColors.risk,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        child: Row(
          children: <Widget>[
            _chip(l10n.homeFiltroTodo, selected: true),
            _chip(l10n.rutasTitulo),
            _chip(l10n.homeFiltroAlertas),
            _chip(l10n.homeFiltroPois),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, {bool selected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 7),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? FqColors.night : FqColors.paper.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? FqColors.white : FqColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NearbyPanel extends StatelessWidget {
  const _NearbyPanel();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(9, 0, 9, 10),
      padding: const EdgeInsets.fromLTRB(16, 15, 4, 15),
      decoration: _floatingDecoration(radius: 19),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  l10n.homeCercaDeTi,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                Text(
                  l10n.homeMantenPresionado,
                  style: const TextStyle(fontSize: 9, color: FqColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: <Widget>[
              Expanded(
                child: _ResultTile(
                  icon: Icons.route_rounded,
                  label: l10n.homeRutaFake,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _ResultTile(
                  icon: Icons.warning_amber_rounded,
                  label: l10n.homeAlertaFake,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                width: 57,
                height: 57,
                decoration: BoxDecoration(
                  color: FqColors.volt,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.add_rounded, size: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 43,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: FqColors.paper,
        border: Border.all(color: FqColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingTokenBackground extends StatelessWidget {
  const _MissingTokenBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EEE5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: const Text(
        'Mapbox necesita ACCESS_TOKEN.\nInicia con --dart-define=ACCESS_TOKEN=pk…',
        textAlign: TextAlign.center,
        style: TextStyle(color: FqColors.muted, fontWeight: FontWeight.w600),
      ),
    );
  }
}

BoxDecoration _floatingDecoration({required double radius}) {
  return BoxDecoration(
    color: FqColors.white.withValues(alpha: .97),
    borderRadius: BorderRadius.circular(radius),
    boxShadow: const <BoxShadow>[
      BoxShadow(color: Color(0x1F13233F), blurRadius: 18, offset: Offset(0, 5)),
    ],
  );
}
