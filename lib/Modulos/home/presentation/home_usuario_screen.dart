import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:fit_quest_go/core/db/daos/avisos_locales_dao.dart';
import 'package:fit_quest_go/core/mapa/adornos_mapa.dart';
import 'package:fit_quest_go/core/mapa/control_ubicacion.dart';
import 'package:fit_quest_go/core/mapa/estilo_mapa.dart';
import 'package:fit_quest_go/core/mapa/mapbox_directions_service.dart';
import 'package:fit_quest_go/core/mapa/navegacion_destino.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/catalogos/tipos_alerta.dart';
import 'package:fit_quest_go/core/geo/posicion_gps.dart';
import 'package:fit_quest_go/core/mapa/mapbox_config.dart';
import 'package:fit_quest_go/core/mapa/pin_anotacion.dart';
import 'package:fit_quest_go/core/mapa/pin_icono.dart';
import 'package:fit_quest_go/core/mapa/redibujo_unico.dart';
import 'package:fit_quest_go/core/mapa/ubicacion_mapa.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/voz/aviso_voz.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/alertas/application/proximidad_alertas.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';
import 'package:fit_quest_go/Modulos/alertas/presentation/banner_alerta_cercana.dart';
import 'package:fit_quest_go/Modulos/alertas/presentation/ficha_alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/presentation/formulario_alerta.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/clima/application/clima_zona.dart';
import 'package:fit_quest_go/Modulos/clima/data/alerta_clima.dart';
import 'package:fit_quest_go/Modulos/clima/data/clima_api.dart';
import 'package:fit_quest_go/Modulos/clima/presentation/banner_clima.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/ficha_evento.dart';
import 'package:fit_quest_go/Modulos/eventos/presentation/widgets/capa_eventos_mapa.dart';
import 'package:fit_quest_go/Modulos/home/application/busqueda_mapa.dart';
import 'package:fit_quest_go/Modulos/home/application/cercanos.dart';
import 'package:fit_quest_go/Modulos/home/application/filtro_mapa.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/banner_guia.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/barra_busqueda_mapa.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/campana_notificaciones.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/filtros_mapa.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/panel_cercano.dart';
import 'package:fit_quest_go/Modulos/home/presentation/widgets/resultados_busqueda.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/ficha_nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/formulario_nodo.dart';
import 'package:fit_quest_go/Modulos/perfil/data/avisos_locales.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificaciones_api.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/notificaciones_screen.dart';
import 'package:fit_quest_go/Modulos/patrocinio/application/proximidad_destacados.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/banner_destacado_cerca.dart';
import 'package:fit_quest_go/Modulos/patrocinio/presentation/capa_destacados_mapa.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/ruta_detalle_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/capa_rutas_mapa.dart';

/// Cada cuanto se vuelven a pedir las alertas vigentes, los puntos de interes,
/// los eventos y las notificaciones sin leer: una alerta que reporta otra
/// persona mientras caminas tiene que poder avisarte sin reabrir la app, un
/// punto que otras personas votan como obsoleto tiene que salir del mapa y una
/// notificacion nueva tiene que prender la campana. Publica para que las pruebas
/// avancen el reloj exactamente este tiempo.
const Duration refrescoAlertasHome = Duration(seconds: 5);

/// Cada cuanto se vuelven a pedir las rutas publicadas: cambian poco (pasan por
/// la moderacion del admin) y cada una trae todo su trazo.
const Duration refrescoRutasHome = Duration(seconds: 5);

class HomeUsuarioScreen extends StatefulWidget {
  const HomeUsuarioScreen({
    super.key,
    this.nodoApi,
    this.alertaApi,
    this.climaApi,
    this.voz,
    this.posiciones,
    this.eventoApi,
    this.rutaApi,
    this.notificacionesApi,
    this.avisosLocales,
  });

  /// Inyectables para pruebas; en produccion se crean los reales.
  final NodoApi? nodoApi;
  final AlertaApi? alertaApi;
  final ClimaApi? climaApi;
  final EventoApi? eventoApi;
  final RutaApi? rutaApi;
  final NotificacionesApi? notificacionesApi;

  /// Donde queda constancia de los avisos que salen unos segundos en el mapa
  /// (clima, alerta o destacado cerca) para encontrarlos en Notificaciones.
  final AvisosLocales? avisosLocales;
  final AvisoVoz? voz;

  /// Fabrica del stream de posiciones del aviso de alertas cercanas. En
  /// produccion usa el GPS del dispositivo ([posicionesGps]).
  final Stream<PosicionGps> Function()? posiciones;

  @override
  State<HomeUsuarioScreen> createState() => _HomeUsuarioScreenState();
}

class _HomeUsuarioScreenState extends State<HomeUsuarioScreen> {
  static const String _accessToken = kMapboxAccessToken;

  /// Cada cuanto se vuelve a preguntar el clima de la zona: cambia despacio y el
  /// servidor ademas lo guarda 10 minutos.
  static const Duration _refrescoClima = Duration(minutes: 15);

  late final NodoApi _nodoApi = widget.nodoApi ?? NodoApi();
  late final AlertaApi _alertaApi = widget.alertaApi ?? AlertaApi();
  late final ClimaApi _climaApi = widget.climaApi ?? ClimaApi();
  late final EventoApi _eventoApi = widget.eventoApi ?? EventoApi();
  late final RutaApi _rutaApi = widget.rutaApi ?? RutaApi();
  late final NotificacionesApi _notificacionesApi =
      widget.notificacionesApi ?? NotificacionesApi();
  late final AvisosLocales _avisosLocales =
      widget.avisosLocales ?? AvisosLocalesDao();
  late final ProximidadAlertas _proximidad;
  late final ClimaZona _clima;

  /// El aviso "Destacado cerca de ti" (a 1 km o menos, uno a la vez).
  final ProximidadDestacados _destacados = ProximidadDestacados();
  Timer? _temporizadorAlertas;
  Timer? _temporizadorRutas;
  Timer? _temporizadorClima;
  Timer? _temporizadorAutoCierreAlerta;
  Timer? _temporizadorAutoCierreClima;
  Timer? _temporizadorAutoCierreDestacado;
  int? _alertaAutoCierreId;
  String? _climaAutoCierreClave;
  String? _destacadoAutoCierreClave;

  /// Duracion prudente antes de ocultar automaticamente las tarjetas emergentes
  /// del mapa (alerta cercana, clima, destacados) si el usuario no interactua.
  static const Duration _duracionAutoCierreAvisos = Duration(seconds: 7);

  AvisoVoz? _vozActiva;

  MapboxMap? _mapa;

  /// Las alertas, como circulos rojos.

  /// Los puntos de interes y los locales de empresas: un pin con forma de gota
  /// y el icono de su categoria (como en Google Maps).
  PointAnnotationManager? _iconosNodos;
  Cancelable? _escuchaTapNodos;

  /// Los puntos destacados: pines dorados en su propio administrador, creado
  /// despues del de los demas puntos para que quede encima de todo.
  CapaDestacadosMapa? _capaDestacados;

  /// Los eventos de las empresas: sus areas y recorridos, con nombre.
  CapaEventosMapa? _capaEventos;
  List<Evento> _eventos = <Evento>[];

  /// Las rutas publicadas: su trazo en verde y el pin de salida con el nombre.
  CapaRutasMapa? _capaRutas;
  List<Ruta> _rutas = <Ruta>[];

  /// Pin del mapa -> nodo, para abrir su ficha al tocarlo.
  final Map<String, Nodo> _nodoPorPin = <String, Nodo>{};
  final Map<String, Alerta> _alertaPorPin = <String, Alerta>{};

  /// El camino a pie que "Como llegar" dibuja en el mapa, y su resumen.
  PolylineAnnotationManager? _lineasGuia;
  PointAnnotationManager? _pinGuia;
  final ValueNotifier<GuiaActiva?> _guia = ValueNotifier<GuiaActiva?>(null);
  final MapboxDirectionsService _directions = MapboxDirectionsService();
  RutaVial? _rutaGuia;
  DestinoNavegacion? _destinoGuia;

  /// Mantiene el estilo del mapa (Mapa / Satelite) al dia con el que eligio la
  /// persona; al cambiarlo se vuelven a crear las capas (ver [GestorEstiloMapa]).
  late final GestorEstiloMapa _estilo = GestorEstiloMapa(
    mapa: () => _mapa,
    alCambiarEstilo: _recrearCapas,
  );
  List<Nodo> _nodos = <Nodo>[];
  List<Alerta> _alertas = <Alerta>[];
  bool _votando = false;

  /// Notificaciones sin leer: el globito de la campana.
  int _noLeidas = 0;

  /// Lo que el servidor dijo la ultima vez; los avisos locales se suman aparte.
  int _noLeidasServidor = 0;

  /// Lo que dejan ver los chips de arriba. Solo cambia el dibujo del mapa y
  /// donde busca el buscador; el aviso por voz de las alertas sigue igual.
  FiltroMapa _filtro = FiltroMapa.todo;

  /// El buscador. La lista de resultados se calcula al construir, con lo que
  /// Home ya tiene cargado (no hay otra consulta al servidor).
  final TextEditingController _busqueda = TextEditingController();
  final FocusNode _focoBusqueda = FocusNode();
  bool _verResultados = false;

  // Cada capa se dibuja de a una vez: ver [RedibujoUnico].
  late final RedibujoUnico _redibujoPines = RedibujoUnico(_pintarPines);
  late final RedibujoUnico _redibujoEventos = RedibujoUnico(_pintarEventos);
  late final RedibujoUnico _redibujoRutas = RedibujoUnico(_pintarRutas);

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
    _focoBusqueda.addListener(_alCambiarFocoBusqueda);
    _proximidad.posicion.addListener(_alMoverseDestacados);
    _proximidad.addListener(_alCambiarAlertaProximidad);
    _clima.addListener(_alCambiarAvisoClima);
    _destacados.addListener(_alCambiarDestacadoCercano);
    NavegacionApp.instancia.registrarMapa();
    _estilo.iniciar();
    NavegacionApp.instancia.destino.addListener(_alPedirDestino);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _proximidad.iniciar();
      _cargarNodos();
      _cargarAlertas();
      _cargarEventos();
      _cargarRutas();
      _cargarNoLeidas();
    });
    _temporizadorAlertas = Timer.periodic(refrescoAlertasHome, (Timer _) {
      _cargarAlertas();
      _cargarNodos();
      _cargarEventos();
      _cargarNoLeidas();
    });
    _temporizadorRutas = Timer.periodic(
      refrescoRutasHome,
      (Timer _) => unawaited(_cargarRutas()),
    );
    _temporizadorClima = Timer.periodic(
      _refrescoClima,
      (Timer _) => unawaited(_clima.actualizar()),
    );
  }

  @override
  void dispose() {
    _focoBusqueda.removeListener(_alCambiarFocoBusqueda);
    _focoBusqueda.dispose();
    _busqueda.dispose();
    _capaEventos?.liberar();
    _capaDestacados?.liberar();
    _capaRutas?.liberar();
    _temporizadorAlertas?.cancel();
    _temporizadorRutas?.cancel();
    _temporizadorClima?.cancel();
    _temporizadorAutoCierreAlerta?.cancel();
    _temporizadorAutoCierreClima?.cancel();
    _temporizadorAutoCierreDestacado?.cancel();
    _escuchaTapNodos?.cancel();
    _clima.removeListener(_alCambiarAvisoClima);
    _clima.dispose();
    _proximidad.removeListener(_alCambiarAlertaProximidad);
    _proximidad.posicion.removeListener(_alMoverseDestacados);
    NavegacionApp.instancia.destino.removeListener(_alPedirDestino);
    NavegacionApp.instancia.liberarMapa();
    _estilo.liberar();
    _guia.dispose();
    _destacados.removeListener(_alCambiarDestacadoCercano);
    _destacados.dispose();
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
          ? await _alertaApi.confirmar(
              alerta.id,
              lat: posicion.lat,
              lng: posicion.lng,
            )
          : await _alertaApi.desmentir(
              alerta.id,
              lat: posicion.lat,
              lng: posicion.lng,
            );
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
    _actualizarDestacables();
    unawaited(_dibujarPines());
  }

  /// Lo destacado que Home tiene cargado, para el aviso de cercania.
  void _actualizarDestacables() =>
      _destacados.actualizarDestacables(_nodos, _eventos);

  void _alMoverseDestacados() {
    final PosicionGps? pos = _proximidad.posicion.value;
    if (pos != null) _destacados.alMoverse(pos);
  }

  /// Oculta la tarjeta de alerta de proximidad tras un tiempo prudente si no se vota.
  void _alCambiarAlertaProximidad() {
    final Alerta? actual = _proximidad.alertaCercana;
    if (actual == null) {
      _alertaAutoCierreId = null;
      _temporizadorAutoCierreAlerta?.cancel();
      return;
    }
    if (_alertaAutoCierreId == actual.id) return;
    _alertaAutoCierreId = actual.id;
    _guardarAviso(
      (AppLocalizations l10n) => avisoDeAlertaCercana(
        l10n,
        actual,
        _proximidad.metrosAlertaCercana ?? 0,
      ),
    );
    _temporizadorAutoCierreAlerta?.cancel();
    _temporizadorAutoCierreAlerta = Timer(_duracionAutoCierreAvisos, () {
      if (!mounted || _votando) return;
      _alertaAutoCierreId = null;
      _proximidad.descartar();
    });
  }

  /// Deja constancia en el centro de notificaciones de un aviso que sale unos
  /// segundos en el mapa y se va solo, y prende la campana si es nuevo.
  void _guardarAviso(AvisoLocal Function(AppLocalizations l10n) crear) {
    if (!mounted) return;
    final AppLocalizations? l10n = AppLocalizations.of(context);
    if (l10n == null) return;
    unawaited(
      _avisosLocales.registrar(crear(l10n)).then((_) => _cargarNoLeidas()),
    );
  }

  /// Oculta la tarjeta de aviso del clima tras unos segundos para no tapar el mapa.
  void _alCambiarAvisoClima() {
    final AlertaClima? aviso = _clima.principal;
    if (aviso == null) {
      _climaAutoCierreClave = null;
      _temporizadorAutoCierreClima?.cancel();
      return;
    }
    if (_climaAutoCierreClave == aviso.clave) return;
    _climaAutoCierreClave = aviso.clave;
    _guardarAviso((AppLocalizations l10n) => avisoDeClima(l10n, aviso));
    _temporizadorAutoCierreClima?.cancel();
    _temporizadorAutoCierreClima = Timer(_duracionAutoCierreAvisos, () {
      if (!mounted) return;
      _climaAutoCierreClave = null;
      _clima.cerrar(aviso);
    });
  }

  /// Oculta la tarjeta de destacado cercano tras unos segundos si no se abre.
  void _alCambiarDestacadoCercano() {
    final DestacadoCercano? destacado = _destacados.cercano;
    if (destacado == null) {
      _destacadoAutoCierreClave = null;
      _temporizadorAutoCierreDestacado?.cancel();
      return;
    }
    if (_destacadoAutoCierreClave == destacado.clave) return;
    _destacadoAutoCierreClave = destacado.clave;
    _guardarAviso((AppLocalizations l10n) => avisoDeDestacado(l10n, destacado));
    _temporizadorAutoCierreDestacado?.cancel();
    _temporizadorAutoCierreDestacado = Timer(_duracionAutoCierreAvisos, () {
      if (!mounted) return;
      _destacadoAutoCierreClave = null;
      _destacados.cerrar();
    });
  }

  /// Abre la ficha de un destacado (punto o evento).
  void _abrirDestacado(DestacadoCercano destacado) {
    switch (destacado.origen) {
      case Nodo nodo:
        _abrirFicha(nodo);
      case Evento evento:
        if (mounted) unawaited(mostrarFichaEvento(context, evento));
    }
  }

  Future<void> _cargarNodos() async {
    try {
      final List<Nodo> nodos = await _nodoApi.listar();
      // La recarga es periodica: si no cambio nada no se redibujan los pines.
      if (!mounted || _mismosNodos(_nodos, nodos)) return;
      setState(() => _nodos = nodos);
      _actualizarDestacables();
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
          a[i].destacado != b[i].destacado ||
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

  Future<void> _cargarRutas() async {
    try {
      final List<Ruta> rutas = await _rutaApi.explorar();
      // La recarga es periodica: si no cambio nada no se redibuja.
      if (!mounted || _mismasRutas(_rutas, rutas)) return;
      setState(() => _rutas = rutas);
      await _dibujarRutas();
    } catch (_) {
      // Sin datos por ahora: el mapa queda sin rutas, no bloquea la pantalla.
    }
  }

  bool _mismasRutas(List<Ruta> a, List<Ruta> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].puntos.length != b[i].puntos.length) {
        return false;
      }
    }
    return true;
  }

  /// El globito de la campana: si falla (sin red) se queda con el ultimo conteo.
  Future<void> _cargarNoLeidas() async {
    try {
      _noLeidasServidor = await _notificacionesApi.conteoNoLeidas();
    } catch (_) {
      // Sin red: se queda con el ultimo conteo del servidor.
    }
    final int locales = await _avisosLocales.conteoNoLeidas();
    final int conteo = _noLeidasServidor + locales;
    if (!mounted || conteo == _noLeidas) return;
    setState(() => _noLeidas = conteo);
  }

  /// Crea las capas del mapa, del fondo al frente. Se llama al crear el mapa y
  /// otra vez al cambiar de estilo (que se lleva las capas).
  Future<void> _crearCapas(MapboxMap controller) async {
    // Del fondo al frente: los eventos, las rutas, las alertas y, encima, los
    // puntos.
    _capaEventos = await CapaEventosMapa.crear(
      controller,
      alTocarEvento: _abrirEvento,
    );
    _capaRutas = await CapaRutasMapa.crear(
      controller,
      alTocarRuta: _abrirRutaPorId,
    );
    // El camino de "Como llegar" va debajo de los pines de puntos y alertas.
    _lineasGuia = await controller.annotations
        .createPolylineAnnotationManager();
    final PointAnnotationManager pinGuia = await controller.annotations
        .createPointAnnotationManager();
    await prepararPines(pinGuia);
    _pinGuia = pinGuia;
    final PointAnnotationManager nodos = await controller.annotations
        .createPointAnnotationManager();
    await prepararPines(nodos);
    _iconosNodos = nodos;
    _escuchaTapNodos = nodos.tapEvents(onTap: _onTapNodo);
    _capaDestacados = await CapaDestacadosMapa.crear(
      controller,
      alTocarNodo: _abrirNodoPorId,
    );
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _mapa = controller;
    await ocultarAdornos(controller);
    await _crearCapas(controller);
    // Lo que ya llego antes de que existiera el mapa se dibuja ahora.
    await _dibujarPines();
    await _dibujarEventos();
    await _dibujarRutas();
    await centrarEnUbicacionActual(controller);
  }

  /// Tras cambiar de estilo: quita las capas viejas, crea las nuevas y vuelve a
  /// dibujar todo lo que ya estaba (puntos, alertas, eventos, rutas y, si hay,
  /// el camino de "Como llegar"), sin volver a pedir nada al servidor.
  Future<void> _recrearCapas() async {
    final MapboxMap? mapa = _mapa;
    if (mapa == null || !mounted) return;
    _escuchaTapNodos?.cancel();
    _escuchaTapNodos = null;
    await _capaEventos?.quitar(mapa);
    await _capaRutas?.quitar(mapa);
    await _capaDestacados?.quitar(mapa);
    for (final BaseAnnotationManager? m in <BaseAnnotationManager?>[
      _lineasGuia,
      _pinGuia,
      _iconosNodos,
    ]) {
      if (m == null) continue;
      try {
        await mapa.annotations.removeAnnotationManager(m);
      } catch (_) {
        // Ya no estaba: no importa.
      }
    }
    await _crearCapas(mapa);
    if (!mounted) return;
    await _dibujarPines();
    await _dibujarEventos();
    await _dibujarRutas();
    final RutaVial? ruta = _rutaGuia;
    final DestinoNavegacion? destino = _destinoGuia;
    if (ruta != null && destino != null) await _dibujarGuia(ruta, destino);
  }

  // --- Como llegar (dentro de la app)

  void _alPedirDestino() {
    final DestinoNavegacion? d = NavegacionApp.instancia.destino.value;
    if (d != null) unawaited(_iniciarGuia(d));
  }

  /// Traza en el mapa el camino a pie desde donde estas hasta [d] y muestra
  /// cuanto falta. Una sola consulta a Mapbox; sin red, la linea directa.
  Future<void> _iniciarGuia(DestinoNavegacion d) async {
    if (_mapa == null || !mounted) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final PosicionGps? origen =
        _proximidad.ultimaPosicion ?? await obtenerPosicionActualRapida();
    if (!mounted) return;
    if (origen == null) {
      notificarInfo(l10n.planificarActivaUbicacion);
      return;
    }
    final RutaVial? ruta = await _directions.rutaHastaInicio(
      origen: origen,
      destino: (lat: d.lat, lng: d.lng),
      perfil: 'walking',
    );
    if (!mounted) return;
    if (ruta == null) {
      notificarInfo(l10n.guiaYaEstasAqui);
      return;
    }
    await _dibujarGuia(ruta, d);
    if (!mounted) return;
    _rutaGuia = ruta;
    _destinoGuia = d;
    _guia.value = GuiaActiva(
      nombre: d.nombre,
      metros: ruta.distanciaMetros,
      segundos: ruta.duracionSegundos,
      lineaRecta: ruta.esLineaRecta,
    );
    await _encuadrar(ruta.puntos);
  }

  Future<void> _dibujarGuia(RutaVial ruta, DestinoNavegacion d) async {
    final PolylineAnnotationManager? lineas = _lineasGuia;
    final PointAnnotationManager? pin = _pinGuia;
    if (lineas == null || pin == null) return;
    // Antes de las esperas: el context no se usa despues de un await.
    final double densidad = MediaQuery.devicePixelRatioOf(context);
    await lineas.deleteAll();
    await pin.deleteAll();
    await lineas.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: <Position>[
            for (final PosicionGps p in ruta.puntos) Position(p.lng, p.lat),
          ],
        ),
        lineColor: FqColors.river.toARGB32(),
        lineWidth: 6,
        lineOpacity: ruta.esLineaRecta ? 0.6 : 1,
      ),
    );
    if (!mounted) return;
    await pin.create(
      opcionesDePin(
        lat: d.lat,
        lng: d.lng,
        imagen: await imagenPin(TipoPin.rutaFin),
        densidad: densidad,
        etiqueta: d.nombre,
      ),
    );
  }

  Future<void> _cerrarGuia() async {
    _guia.value = null;
    _rutaGuia = null;
    _destinoGuia = null;
    try {
      await _lineasGuia?.deleteAll();
      await _pinGuia?.deleteAll();
    } catch (_) {
      // El mapa se cerro mientras tanto: no importa.
    }
  }

  /// Tocar el pin de un punto de interes abre su ficha (con foto, si tiene) y,
  /// si estas cerca, deja votar si sigue ahi o ya no existe.
  void _onTapNodo(PointAnnotation pin) {
    final Alerta? alerta = _alertaPorPin[pin.id];
    if (alerta != null) {
      _abrirAlerta(alerta);
      return;
    }
    _abrirFicha(_nodoPorPin[pin.id]);
  }

  void _abrirNodoPorId(int nodoId) {
    for (final Nodo n in _nodos) {
      if (n.id == nodoId) {
        _abrirFicha(n);
        return;
      }
    }
  }

  void _abrirFicha(Nodo? nodo) {
    if (nodo == null || !mounted) return;
    unawaited(
      mostrarFichaNodo(
        context,
        nodo,
        _nodoApi,
        posicionActual: () => _proximidad.ultimaPosicion,
        usuarioId: _usuarioId,
        alDestacar: _reemplazarNodo,
      ),
    );
  }

  /// Tocar el area, el recorrido o el pin de un evento abre su ficha.
  void _abrirEvento(int eventoId) {
    Evento? evento;
    for (final Evento e in _eventos) {
      if (e.id == eventoId) {
        evento = e;
        break;
      }
    }
    if (evento == null || !mounted) return;
    unawaited(mostrarFichaEvento(context, evento));
  }

  /// Tocar el trazo o el pin de una ruta abre su detalle.
  void _abrirRutaPorId(int rutaId) {
    for (final Ruta r in _rutas) {
      if (r.id == rutaId) {
        _abrirRuta(r);
        return;
      }
    }
  }

  void _abrirRuta(Ruta ruta) {
    if (!mounted) return;
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext _) =>
              RutaDetalleScreen(ruta: ruta, api: _rutaApi),
        ),
      ),
    );
  }

  void _abrirAlerta(Alerta alerta, {double? metros}) {
    if (!mounted) return;
    unawaited(mostrarFichaAlerta(context, alerta, metros: metros));
  }

  Future<void> _abrirNotificaciones() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) =>
            NotificacionesScreen(api: _notificacionesApi),
      ),
    );
    // Al volver ya leiste (o borraste) algunas: se cuenta de nuevo.
    if (mounted) unawaited(_cargarNoLeidas());
  }

  Future<void> _cargarEventos() async {
    try {
      final List<Evento> eventos = await _eventoApi.listar();
      // La recarga es periodica: si no cambio nada no se redibuja.
      if (!mounted || _mismosEventos(_eventos, eventos)) return;
      setState(() => _eventos = eventos);
      _actualizarDestacables();
      await _dibujarEventos();
    } catch (_) {
      // Sin datos por ahora: el mapa queda sin eventos, no bloquea la pantalla.
    }
  }

  bool _mismosEventos(List<Evento> a, List<Evento> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].destacado != b[i].destacado ||
          a[i].areas.length != b[i].areas.length ||
          a[i].recorridos.length != b[i].recorridos.length) {
        return false;
      }
    }
    return true;
  }

  // --- Dibujo del mapa. Cada `_dibujarX` pide un dibujo; `_pintarX` lo hace.

  Future<void> _dibujarEventos() => _redibujoEventos.pedir();

  Future<void> _pintarEventos() async {
    final CapaEventosMapa? capa = _capaEventos;
    if (capa == null || !mounted) return;
    final List<Evento> eventos = _filtro.muestra(CapaMapa.eventos)
        ? List<Evento>.of(_eventos)
        : <Evento>[];
    await capa.dibujar(
      densidad: MediaQuery.devicePixelRatioOf(context),
      areas: <ZonaEvento>[for (final Evento e in eventos) ...e.areasRotuladas],
      recorridos: <ZonaEvento>[
        for (final Evento e in eventos) ...e.recorridosRotulados,
      ],
      eventosDestacados: <int>{
        for (final Evento e in eventos)
          if (e.destacado) e.id,
      },
    );
  }

  Future<void> _dibujarRutas() => _redibujoRutas.pedir();

  Future<void> _pintarRutas() async {
    final CapaRutasMapa? capa = _capaRutas;
    if (capa == null || !mounted) return;
    await capa.dibujar(
      densidad: MediaQuery.devicePixelRatioOf(context),
      rutas: _filtro.muestra(CapaMapa.rutas) ? List<Ruta>.of(_rutas) : <Ruta>[],
    );
  }

  Future<void> _dibujarPines() => _redibujoPines.pedir();

  Future<void> _pintarPines() async {
    final PointAnnotationManager? nodosMgr = _iconosNodos;
    if (nodosMgr == null) return;
    await nodosMgr.deleteAll();
    _nodoPorPin.clear();
    _alertaPorPin.clear();
    // Copia: las listas pueden cambiar mientras se espera a Mapbox. Lo que el
    // filtro oculta se borra y no se vuelve a dibujar.
    final List<Nodo> nodos = _filtro.muestra(CapaMapa.pois)
        ? List<Nodo>.of(_nodos)
        : <Nodo>[];
    final List<Alerta> alertas = _filtro.muestra(CapaMapa.alertas)
        ? List<Alerta>.of(_alertas)
        : <Alerta>[];

    if (!mounted) return;
    final double densidad = MediaQuery.devicePixelRatioOf(context);

    // Las alertas van primero (debajo de los puntos): cada una con el icono de
    // su tipo y el color de su gravedad.
    if (alertas.isNotEmpty) {
      final List<PointAnnotationOptions> opcionesAlertas =
          <PointAnnotationOptions>[
            for (final Alerta a in alertas)
              opcionesDePin(
                lat: a.lat,
                lng: a.lng,
                imagen: await imagenPinAlerta(a.tipo, a.gravedad),
                densidad: densidad,
              ),
          ];
      final List<PointAnnotation?> pinesAlertas = await nodosMgr.createMulti(
        opcionesAlertas,
      );
      for (int i = 0; i < alertas.length && i < pinesAlertas.length; i++) {
        final PointAnnotation? pin = pinesAlertas[i];
        if (pin != null) _alertaPorPin[pin.id] = alertas[i];
      }
    }

    if (!mounted) return;
    // Los destacados van en su propia capa, encima de todo (y se borra si el
    // filtro oculta los puntos).
    final CapaDestacadosMapa? capaDestacados = _capaDestacados;
    await capaDestacados?.dibujar(densidad: densidad, nodos: nodos);
    final List<Nodo> normales = <Nodo>[
      for (final Nodo n in nodos)
        if (capaDestacados == null || !n.destacado) n,
    ];
    if (normales.isEmpty || !mounted) return;
    // Un local de empresa (nodo patrocinado) lleva su tienda; los demas puntos,
    // el icono de su categoria.
    final List<PointAnnotationOptions> opciones = <PointAnnotationOptions>[
      for (final Nodo n in normales)
        opcionesDePin(
          lat: n.lat,
          lng: n.lng,
          imagen: await (n.patrocinado
              ? imagenPin(TipoPin.local)
              : imagenPinNodo(n.categoria)),
          densidad: densidad,
        ),
    ];
    final List<PointAnnotation?> creados = await nodosMgr.createMulti(opciones);
    // Los pines salen en el orden de las opciones.
    for (int i = 0; i < normales.length && i < creados.length; i++) {
      final PointAnnotation? pin = creados[i];
      if (pin != null) _nodoPorPin[pin.id] = normales[i];
    }
  }

  // --- Filtros

  /// Tocar un chip lo activa; tocar otra vez el que ya esta activo vuelve a
  /// "Todo".
  void _cambiarFiltro(FiltroMapa elegido) {
    final FiltroMapa nuevo = elegido == _filtro ? FiltroMapa.todo : elegido;
    if (nuevo == _filtro) return;
    setState(() => _filtro = nuevo);
    unawaited(_dibujarPines());
    unawaited(_dibujarEventos());
    unawaited(_dibujarRutas());
  }

  // --- Buscador

  void _alCambiarFocoBusqueda() {
    // Volver a la barra con algo escrito vuelve a abrir la lista.
    setState(() {
      if (_focoBusqueda.hasFocus && _busqueda.text.trim().isNotEmpty) {
        _verResultados = true;
      }
    });
  }

  void _alEscribirBusqueda(String _) {
    setState(() => _verResultados = _busqueda.text.trim().isNotEmpty);
  }

  void _limpiarBusqueda() {
    _busqueda.clear();
    setState(() => _verResultados = false);
  }

  /// Tocar el mapa cierra el teclado y la lista de resultados.
  void _cerrarBusqueda() {
    if (_focoBusqueda.hasFocus) _focoBusqueda.unfocus();
    if (_verResultados) setState(() => _verResultados = false);
  }

  /// Lleva el mapa a lo elegido y abre su ficha.
  void _elegirResultado(ResultadoBusqueda resultado) {
    _focoBusqueda.unfocus();
    _busqueda.text = resultado.titulo;
    setState(() => _verResultados = false);
    switch (resultado.origen) {
      case Nodo nodo:
        unawaited(_irA(nodo.lat, nodo.lng));
        _abrirFicha(nodo);
      case Ruta ruta:
        unawaited(
          _encuadrar(<({double lat, double lng})>[
            for (final PuntoRuta p in ruta.puntos) (lat: p.lat, lng: p.lng),
          ]),
        );
        _abrirRuta(ruta);
      case Alerta alerta:
        unawaited(_irA(alerta.lat, alerta.lng));
        _abrirAlerta(alerta, metros: resultado.metros);
      case Evento evento:
        unawaited(
          _encuadrar(<({double lat, double lng})>[
            for (final PuntoGeo p in evento.todosLosPuntos)
              (lat: p.lat, lng: p.lng),
          ]),
        );
        unawaited(mostrarFichaEvento(context, evento));
    }
  }

  /// Mueve la camara hasta un punto. Sin mapa (todavia no se creo) no hace nada.
  Future<void> _irA(double lat, double lng) async {
    final MapboxMap? mapa = _mapa;
    if (mapa == null) return;
    try {
      await mapa.flyTo(
        CameraOptions(center: Point(coordinates: Position(lng, lat)), zoom: 16),
        MapAnimationOptions(duration: 900),
      );
    } catch (_) {
      // El mapa se cerro mientras se movia: no importa.
    }
  }

  /// Mueve la camara para que quepan todos los [puntos], con espacio para la
  /// barra de arriba y el cuadro de abajo.
  Future<void> _encuadrar(List<({double lat, double lng})> puntos) async {
    final MapboxMap? mapa = _mapa;
    if (mapa == null || puntos.isEmpty) return;
    if (puntos.length == 1) return _irA(puntos.single.lat, puntos.single.lng);
    try {
      final CameraOptions camara = await mapa.cameraForCoordinatesPadding(
        <Point>[
          for (final ({double lat, double lng}) p in puntos)
            Point(coordinates: Position(p.lng, p.lat)),
        ],
        CameraOptions(),
        MbxEdgeInsets(top: 170, left: 40, bottom: 260, right: 40),
        17, // tope de zoom: una ruta cortita no se acerca hasta perder contexto
        null,
      );
      await mapa.flyTo(camara, MapAnimationOptions(duration: 900));
    } catch (_) {
      // El mapa se cerro mientras se movia: no importa.
    }
  }

  // --- Reportar

  Future<void> _onLongTap(MapContentGestureContext contexto) async {
    final Position posicion = contexto.point.coordinates;
    await _reportarEn(
      lat: posicion[1]!.toDouble(),
      lng: posicion[0]!.toDouble(),
    );
  }

  /// El "+" del cuadro "Cerca de ti": lo mismo que mantener presionado el mapa,
  /// pero justo donde estas.
  void _reportarAqui() {
    final PosicionGps? posicion = _proximidad.ultimaPosicion;
    if (posicion == null) {
      notificarInfo(AppLocalizations.of(context)!.homeSinUbicacionParaReportar);
      return;
    }
    unawaited(_reportarEn(lat: posicion.lat, lng: posicion.lng));
  }

  /// Pregunta que se quiere reportar en ([lat], [lng]) y abre el formulario.
  Future<void> _reportarEn({required double lat, required double lng}) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String? tipo = await _elegirQueReportar(l10n);
    if (tipo == null || !mounted) return;
    if (tipo == 'nodo') {
      final Nodo? creado = await _mostrarFormularioNodo(lat: lat, lng: lng);
      if (creado == null || !mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.homeNodoEnviadoExito)));
      // Sale publicado de inmediato: se trae de nuevo para que aparezca ya.
      unawaited(_cargarNodos());
    } else {
      final Alerta? creada = await _mostrarFormularioAlerta(lat: lat, lng: lng);
      if (creada == null || !mounted) return;
      setState(() => _alertas = <Alerta>[..._alertas, creada]);
      _proximidad.actualizarAlertas(_alertas);
      await _dibujarPines();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.homeAlertaPublicadaExito)));
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
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
              leading: const Icon(
                Icons.warning_amber_rounded,
                color: FqColors.risk,
              ),
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

  // --- Pantalla

  /// El cuadro "Cerca de ti": se recalcula con cada posicion del GPS.
  Widget _construirPanel(
    BuildContext context,
    PosicionGps? posicion,
    Widget? _,
  ) {
    final RutaCercana? ruta = posicion == null
        ? null
        : rutaMasCercana(lat: posicion.lat, lng: posicion.lng, rutas: _rutas);
    final AlertaCercana? alerta = posicion == null
        ? null
        : alertaMasCercana(
            lat: posicion.lat,
            lng: posicion.lng,
            alertas: _alertas,
          );
    final DestacadoCercano? destacado = posicion == null
        ? null
        : destacadoMasCercano(
            lat: posicion.lat,
            lng: posicion.lng,
            nodos: _nodos,
            eventos: _eventos,
          );
    return PanelCercano(
      hayUbicacion: posicion != null,
      ruta: ruta,
      alerta: alerta,
      destacado: destacado,
      onDestacado: destacado == null ? null : () => _abrirDestacado(destacado),
      onRuta: () {
        if (ruta == null) return;
        unawaited(
          _encuadrar(<({double lat, double lng})>[
            for (final PuntoRuta p in ruta.ruta.puntos)
              (lat: p.lat, lng: p.lng),
          ]),
        );
        _abrirRuta(ruta.ruta);
      },
      onAlerta: () {
        if (alerta == null) return;
        unawaited(_irA(alerta.alerta.lat, alerta.alerta.lng));
        _abrirAlerta(alerta.alerta, metros: alerta.metros);
      },
      onAgregar: _reportarAqui,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    // Con el teclado abierto no hay lugar para los avisos y el cuadro de abajo:
    // se esconden mientras se escribe.
    final bool escribiendo = _focoBusqueda.hasFocus;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (_accessToken.isNotEmpty)
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (PointerDownEvent _) => _cerrarBusqueda(),
            child: MapWidget(
              key: const ValueKey<String>('fitquest-map'),
              styleUri: PreferenciaEstiloMapa.instancia.estilo.value.uri,
              onStyleLoadedListener: _estilo.alEstiloCargado,
              cameraOptions: CameraOptions(
                center: Point(coordinates: Position(-84.0907, 9.9281)),
                zoom: 13.5,
              ),
              onMapCreated: _onMapCreated,
              onLongTapListener: _onLongTap,
            ),
          )
        else
          const _MissingTokenBackground(),
        SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: BarraBusquedaMapa(
                        controller: _busqueda,
                        focusNode: _focoBusqueda,
                        onChanged: _alEscribirBusqueda,
                        onLimpiar: _limpiarBusqueda,
                      ),
                    ),
                    const SizedBox(width: 9),
                    CampanaNotificaciones(
                      noLeidas: _noLeidas,
                      onTap: _abrirNotificaciones,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FiltrosMapa(seleccionado: _filtro, onCambio: _cambiarFiltro),
              ListenableBuilder(
                listenable: _clima,
                builder: (BuildContext context, Widget? _) {
                  final AlertaClima? aviso = _clima.principal;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: aviso == null
                        ? const SizedBox.shrink()
                        : BannerClima(
                            key: ValueKey<String>(
                              'banner-clima-${aviso.clave}',
                            ),
                            alerta: aviso,
                            fuente: _clima.fuente,
                            masAvisos: _clima.visibles.length - 1,
                            onCerrar: () => _clima.cerrar(aviso),
                          ),
                  );
                },
              ),
              const Spacer(),
              if (!escribiendo) ...<Widget>[
                // Como el de Google Maps: te trae a tu posicion y, ya centrado,
                // inclina el mapa.
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 10, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const BotonTipoMapa(),
                        const SizedBox(height: 8),
                        BotonMiUbicacion(mapa: () => _mapa),
                      ],
                    ),
                  ),
                ),
                ValueListenableBuilder<GuiaActiva?>(
                  valueListenable: _guia,
                  builder: (BuildContext context, GuiaActiva? guia, Widget? _) {
                    if (guia == null) return const SizedBox.shrink();
                    return BannerGuia(guia: guia, onCerrar: _cerrarGuia);
                  },
                ),
                ListenableBuilder(
                  listenable: _proximidad,
                  builder: (BuildContext context, Widget? _) {
                    final Alerta? alerta = _proximidad.alertaCercana;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: alerta == null
                          ? const SizedBox.shrink()
                          : BannerAlertaCercana(
                              key: ValueKey<int>(alerta.id),
                              alerta: alerta,
                              metros: _proximidad.metrosAlertaCercana ?? 0,
                              votando: _votando,
                              onSigue: () => _votar(sigueAhi: true),
                              onNoEsta: () => _votar(sigueAhi: false),
                              onCerrar: _proximidad.descartar,
                            ),
                    );
                  },
                ),
                // Un destacado nunca tapa una alerta de peligro: mientras haya
                // una alerta que avisar, el aviso del destacado espera.
                ListenableBuilder(
                  listenable: Listenable.merge(<Listenable>[
                    _proximidad,
                    _destacados,
                  ]),
                  builder: (BuildContext context, Widget? _) {
                    final DestacadoCercano? destacado = _destacados.cercano;
                    final bool visible =
                        destacado != null && _proximidad.alertaCercana == null;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: !visible
                          ? const SizedBox.shrink()
                          : BannerDestacadoCerca(
                              key: ValueKey<String>(
                                'banner-destacado-${destacado.clave}',
                              ),
                              destacado: destacado,
                              onTap: () {
                                _destacados.cerrar();
                                _abrirDestacado(destacado);
                              },
                              onCerrar: _destacados.cerrar,
                            ),
                    );
                  },
                ),
                ValueListenableBuilder<PosicionGps?>(
                  valueListenable: _proximidad.posicion,
                  builder: _construirPanel,
                ),
              ],
            ],
          ),
        ),
        if (_verResultados && _busqueda.text.trim().isNotEmpty)
          SafeArea(
            child: Padding(
              // Justo bajo la barra de busqueda (10 de margen + 50 de alto + 6).
              padding: const EdgeInsets.only(top: 66),
              child: Align(
                alignment: Alignment.topCenter,
                child: ResultadosBusqueda(
                  consulta: _busqueda.text,
                  resultados: buscarEnMapa(
                    consulta: _busqueda.text,
                    filtro: _filtro,
                    l10n: l10n,
                    nodos: _nodos,
                    rutas: _rutas,
                    alertas: _alertas,
                    eventos: _eventos,
                    posicion: _proximidad.ultimaPosicion,
                  ),
                  onElegir: _elegirResultado,
                ),
              ),
            ),
          ),
      ],
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
