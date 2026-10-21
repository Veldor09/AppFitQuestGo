import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificaciones_api.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';
import 'package:fit_quest_go/core/db/daos/perfil_cache_dao.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/rutas_pendientes_banner.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/aportes_screen.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/insignias_screen.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/mapas_offline_screen.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/notificaciones_screen.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/preferencias_screen.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/widgets/actividades_modal.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/widgets/editar_perfil_modal.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/auth/data/sesion.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/widgets/intereses_modal.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/rutas_screen.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';


class PerfilScreen extends StatefulWidget {
  const PerfilScreen({
    super.key,
    this.api,
    this.notificacionesApi,
    this.cacheDao,
    this.onCerrarSesion,
  });

  final PerfilApi? api;
  final NotificacionesApi? notificacionesApi;
  final PerfilCacheDao? cacheDao;
  final Future<void> Function()? onCerrarSesion;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late final PerfilApi _api = widget.api ?? PerfilApi();
  late final NotificacionesApi _notifApi =
      widget.notificacionesApi ?? NotificacionesApi();
  late final PerfilCacheDao _cacheDao = widget.cacheDao ?? PerfilCacheDao();

  Usuario? _usuario;
  bool _cargando = true;
  bool _esOffline = false;
  String? _errorMensaje;
  int _noLeidas = 0;
  bool _inicializado = false;

  @override
  void initState() {
    super.initState();
    _cargarNoLeidas();
    _refrescarDesdeApi();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      final UsuarioSesion? sesion = AuthScope.maybeOf(context)?.usuario;
      if (sesion != null && _usuario == null) {
        _usuario = Usuario(
          id: sesion.id,
          nombreUser: sesion.nombre.isNotEmpty
              ? sesion.nombre
              : sesion.email.split('@').first,
          emailUser: sesion.email,
          idrol: sesion.rol,
        );
        _cargando = false;
      }
      _cargarDesdeCache();
    }
  }

  Future<void> _cargarDesdeCache() async {
    final UsuarioSesion? sesion = AuthScope.maybeOf(context)?.usuario;

    final Usuario? enCache = sesion != null
        ? await _cacheDao.leerUsuario(sesion.id)
        : await _cacheDao.leerUltimoUsuario();

    if (mounted && enCache != null) {
      setState(() {
        _usuario = enCache;
        _cargando = false;
      });
    }
  }

  Future<void> _refrescarDesdeApi() async {
    try {
      final Usuario remoto = await _api.miPerfil();
      if (!mounted) return;
      setState(() {
        _usuario = remoto;
        _cargando = false;
        _esOffline = false;
        _errorMensaje = null;
      });
      await _cacheDao.guardarUsuario(remoto);
    } catch (e) {
      if (!mounted) return;
      if (_usuario == null) {
        await _cargarDesdeCache();
      }
      if (!mounted) return;
      setState(() {
        _cargando = false;
        if (_usuario != null) {
          _esOffline = true;
        } else {
          _errorMensaje = e is ApiException ? e.message : null;
        }
      });
    }
  }

  /// Contador del buzón; si falla simplemente no se muestra el indicador.
  Future<void> _cargarNoLeidas() async {
    try {
      final int n = await _notifApi.conteoNoLeidas();
      if (mounted) setState(() => _noLeidas = n);
    } catch (_) {}
  }

  Future<void> _abrirNotificaciones() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NotificacionesScreen(api: _notifApi),
      ),
    );
    _cargarNoLeidas();
  }

  void _recargar() {
    setState(() {
      _esOffline = false;
    });
    _refrescarDesdeApi();
    _cargarNoLeidas();
  }

  Future<void> _editarPerfil(Usuario usuario) async {
    final bool? cambiado = await EditarPerfilModal.abrir(
      context,
      usuario: usuario,
      api: _api,
    );
    if (cambiado == true) {
      _recargar();
    }
  }

  Future<void> _gestionarActividades(Usuario usuario) async {
    final bool? cambiado = await GestionarActividadesModal.abrir(
      context,
      usuario: usuario,
      api: _api,
    );
    if (cambiado == true) {
      _recargar();
    }
  }

  Future<void> _gestionarIntereses(Usuario usuario) async {
    final bool? cambiado = await GestionarInteresesModal.abrir(
      context,
      usuario: usuario,
      api: _api,
    );
    if (cambiado == true) {
      _recargar();
    }
  }

  Future<void> _abrirPreferencias(Usuario usuario) async {
    final bool? ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => PreferenciasScreen(usuario: usuario, api: _api),
      ),
    );
    if (ok == true) {
      _recargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (_cargando && _usuario == null) {
      return const ColoredBox(
        color: FqColors.paper,
        child: _PerfilCargando(),
      );
    }

    if (_usuario == null) {
      return ColoredBox(
        color: FqColors.paper,
        child: _PerfilError(
          mensaje: _errorMensaje ?? l10n.perfilErrorGenerico,
          onReintentar: () {
            setState(() => _cargando = true);
            _recargar();
          },
        ),
      );
    }

    return ColoredBox(
      color: FqColors.paper,
      child: _PerfilContenido(
        usuario: _usuario!,
        api: _api,
        esOffline: _esOffline,
        onAjustes: () => _abrirAjustes(_usuario!),
        onEditar: () => _editarPerfil(_usuario!),
        onGestionarActividades: () => _gestionarActividades(_usuario!),
        onGestionarIntereses: () => _gestionarIntereses(_usuario!),
        onPreferencias: () => _abrirPreferencias(_usuario!),
        onNotificaciones: _abrirNotificaciones,
        noLeidas: _noLeidas,
        onRecargar: _recargar,
      ),
    );
  }

  Future<void> _abrirAjustes(Usuario usuario) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FqColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _HojaAjustes(
        usuario: usuario,
        onCerrarSesion: widget.onCerrarSesion,
        onEditar: () => _editarPerfil(usuario),
      ),
    );
  }
}

class _PerfilContenido extends StatelessWidget {
  const _PerfilContenido({
    required this.usuario,
    required this.api,
    required this.onAjustes,
    required this.onEditar,
    required this.onGestionarIntereses,
    required this.onGestionarActividades,
    required this.onPreferencias,
    required this.onNotificaciones,
    required this.noLeidas,
    required this.onRecargar,
    this.esOffline = false,
  });

  final Usuario usuario;
  final PerfilApi api;
  final VoidCallback onAjustes;
  final VoidCallback onEditar;
  final VoidCallback onGestionarIntereses;
  final VoidCallback onGestionarActividades;
  final VoidCallback onPreferencias;
  final VoidCallback onNotificaciones;
  final int noLeidas;
  final VoidCallback onRecargar;
  final bool esOffline;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Hero(
          usuario: usuario,
          api: api,
          onAjustes: onAjustes,
          onEditar: onEditar,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            child: Column(
              children: <Widget>[
                if (esOffline) ...<Widget>[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 18,
                          color: Color(0xFF92400E),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Modo sin conexión: mostrando datos guardados. Tus rutas descargadas siguen disponibles.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF92400E)),
                          onPressed: onRecargar,
                          tooltip: 'Reintentar',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
                RutasPendientesBanner(alSincronizar: onRecargar),
                _SeccionActividades(
                  actividades: usuario.actividades,
                  onGestionar: onGestionarActividades,
                ),
                const SizedBox(height: 8),
                _SeccionIntereses(
                  intereses: usuario.intereses,
                  onGestionar: onGestionarIntereses,
                ),
                const SizedBox(height: 12),
                _MenuFila(
                  icono: Icons.route_outlined,
                  texto: l10n.rutasMisRutas,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RutasScreen(
                          initialTab: 1,
                          showBackButton: true,
                        ),
                      ),
                    );
                  },
                ),
                _MenuFila(
                  icono: Icons.send_outlined,
                  texto: l10n.perfilMisAportes,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AportesScreen()),
                  ),
                ),
                _MenuFila(
                  icono: Icons.military_tech_outlined,
                  texto: l10n.perfilInsignias,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const InsigniasScreen()),
                  ),
                ),
                _MenuFila(
                  icono: Icons.notifications_none_rounded,
                  texto: l10n.permisoNotificacionesTitulo,
                  badge: noLeidas,
                  onTap: onNotificaciones,
                ),
                _MenuFila(
                  icono: Icons.download_outlined,
                  texto: l10n.perfilMapasOffline,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const MapasOfflineScreen()),
                  ),
                ),
                _MenuFila(
                  icono: Icons.tune_rounded,
                  texto: l10n.perfilPreferencias,
                  onTap: onPreferencias,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Cabecera azul oscura: avatar + datos + botón unificado de editar + métricas.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.usuario,
    required this.api,
    required this.onAjustes,
    required this.onEditar,
  });

  final Usuario usuario;
  final PerfilApi api;
  final VoidCallback onAjustes;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final double topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      color: FqColors.night,
      child: Stack(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 14, 16, 14),
            child: Column(
              children: <Widget>[
                _Avatar(
                  iniciales: usuario.iniciales,
                ),
                const SizedBox(height: 10),
                Text(
                  usuario.nombreUser,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    color: FqColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  usuario.emailUser,
                  style: const TextStyle(
                    color: Color(0xFFB7C3D1),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                // Botón único, claro y prominente para editar el perfil
                Material(
                  color: const Color(0x24FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: onEditar,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0x40FFFFFF)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const <Widget>[
                          Icon(Icons.edit_outlined, size: 14, color: FqColors.white),
                          SizedBox(width: 6),
                          Text(
                            'Editar perfil',
                            style: TextStyle(
                              color: FqColors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _MetricasEjemplo(api: api, usuario: usuario),
              ],
            ),
          ),
          Positioned(
            top: topInset + 2,
            right: 8,
            child: IconButton(
              onPressed: onAjustes,
              icon: const Icon(Icons.tune_rounded, size: 20),
              color: FqColors.white,
              tooltip: l10n.perfilAjustesCuenta,
              splashRadius: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.iniciales,
  });

  final String iniciales;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FqColors.volt,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              iniciales,
              style: const TextStyle(
                color: FqColors.night,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF28A36D),
                shape: BoxShape.circle,
                border: Border.all(color: FqColors.night, width: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tira blanca de 3 métricas reales (PRF-01 / NAV-07).
class _MetricasEjemplo extends StatefulWidget {
  const _MetricasEjemplo({required this.api, required this.usuario});

  final PerfilApi api;
  final Usuario usuario;

  @override
  State<_MetricasEjemplo> createState() => _MetricasEjemploState();
}

/// Muestra primero las ultimas metricas guardadas en SQLite (al instante, y
/// tambien sin red) y las reemplaza por las del backend cuando llegan.
class _MetricasEjemploState extends State<_MetricasEjemplo> {
  final PerfilCacheDao _cache = PerfilCacheDao();
  MetricasCache? _enCache;
  Map<String, dynamic>? _remotas;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final MetricasCache? guardadas = await _cache.leer(widget.usuario.id);
    if (mounted && _remotas == null && guardadas != null) {
      setState(() => _enCache = guardadas);
    }
    try {
      final Map<String, dynamic> datos = await widget.api.estadisticasPropias();
      if (mounted) setState(() => _remotas = datos);
      await _cache.guardar(
        idUsuario: widget.usuario.id,
        nombreUser: widget.usuario.nombreUser,
        emailUser: widget.usuario.emailUser,
        km: (datos['kmRecorridos'] as num? ?? 0).toDouble(),
        rutas: (datos['rutasCompletadas'] as num? ?? 0).toInt(),
        insignias: (datos['insignias'] as num? ?? 0).toInt(),
      );
    } catch (_) {
      // Sin red o error del servidor: se queda lo que hubiera en caché.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Map<String, dynamic>? r = _remotas;
    final MetricasCache? c = _enCache;
    final String km = r != null
        ? (r['kmRecorridos'] as num? ?? 0).toStringAsFixed(0)
        : c != null
            ? c.km.toStringAsFixed(0)
            : '—';
    final String rutas = r != null
        ? '${(r['rutasCompletadas'] as num?)?.toInt() ?? 0}'
        : c != null
            ? '${c.rutas}'
            : '—';
    final String insignias = r != null
        ? '${(r['insignias'] as num?)?.toInt() ?? 0}'
        : c != null
            ? '${c.insignias}'
            : '—';
    return Container(
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FqColors.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: <Widget>[
            Expanded(child: _Metrica(valor: km, etiqueta: l10n.perfilKm)),
            Container(width: 1, color: FqColors.border),
            Expanded(child: _Metrica(valor: rutas, etiqueta: l10n.perfilMetricaRutas)),
            Container(width: 1, color: FqColors.border),
            Expanded(child: _Metrica(valor: insignias, etiqueta: l10n.perfilMetricaInsignias)),
          ],
        ),
      ),
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            valor,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: FqColors.ink,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: FqColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuFila extends StatelessWidget {
  const _MenuFila({
    required this.icono,
    required this.texto,
    this.onTap,
    this.badge = 0,
  });

  final IconData icono;
  final String texto;
  final VoidCallback? onTap;

  /// Contador (p. ej. notificaciones sin leer). No se muestra si es 0.
  final int badge;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap ?? () => notificarInfo(l10n.perfilDisponiblePronto(texto)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE7EBE5)),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FqColors.listIconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icono, size: 17, color: FqColors.night),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: FqColors.ink,
                ),
              ),
            ),
            if (badge > 0) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: FqColors.risk,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: FqColors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: FqColors.stone,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Estados de carga / error
// ---------------------------------------------------------------------------

class _PerfilCargando extends StatelessWidget {
  const _PerfilCargando();

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          color: FqColors.night,
          padding: EdgeInsets.fromLTRB(14, topInset + 24, 14, 24),
          child: Column(
            children: <Widget>[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: FqColors.night2,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 12),
              Container(width: 120, height: 12, color: FqColors.night2),
              const SizedBox(height: 8),
              Container(width: 80, height: 8, color: FqColors.night2),
            ],
          ),
        ),
        const Expanded(
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _PerfilError extends StatelessWidget {
  const _PerfilError({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return FqEmptyState(
      icon: Icons.person_off_outlined,
      title: l10n.perfilNoSePudoCargar,
      message: mensaje,
      action: TextButton(
        onPressed: onReintentar,
        child: Text(l10n.rutasReintentar),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hoja de ajustes de la cuenta (Información, Accesos y Cerrar Sesión)
// ---------------------------------------------------------------------------

class _HojaAjustes extends StatelessWidget {
  const _HojaAjustes({
    required this.usuario,
    this.onCerrarSesion,
    required this.onEditar,
  });

  final Usuario usuario;
  final Future<void> Function()? onCerrarSesion;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: FqColors.stone,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.perfilAjustesCuenta,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: FqColors.ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.perfilDatosDeLaBd,
              style: const TextStyle(fontSize: 11, color: FqColors.muted),
            ),
            const SizedBox(height: 14),
            _Dato(label: l10n.comunNombre, valor: usuario.nombreUser),
            _Dato(
              label: l10n.comunCorreo,
              valor: usuario.emailUser,
              ultimo: true,
            ),
            const SizedBox(height: 16),
            _OpcionAjusteTile(
              icono: Icons.edit_outlined,
              titulo: l10n.perfilEditarInfo,
              subtitulo: l10n.perfilModificarSubtitulo,
              onTap: () {
                Navigator.of(context).pop();
                onEditar();
              },
            ),
            if (onCerrarSesion != null) ...<Widget>[
              const SizedBox(height: 16),
              FqButton.danger(
                label: l10n.perfilCerrarSesion,
                icon: Icons.logout_rounded,
                onPressed: () async {
                  Navigator.of(context).pop();
                  await onCerrarSesion!();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OpcionAjusteTile extends StatelessWidget {
  const _OpcionAjusteTile({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FqColors.cloud,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FqColors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, size: 17, color: FqColors.night),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: FqColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: const TextStyle(fontSize: 10, color: FqColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: FqColors.stone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.label, required this.valor, this.ultimo = false});

  final String label;
  final String valor;
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: ultimo
            ? null
            : const Border(bottom: BorderSide(color: FqColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 74,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: FqColors.fieldLabel,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: FqColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta para mostrar los intereses seleccionados del usuario.
class _SeccionIntereses extends StatelessWidget {
  const _SeccionIntereses({
    required this.intereses,
    required this.onGestionar,
  });

  final List<String> intereses;
  final VoidCallback onGestionar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FqColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.interests_rounded,
                size: 16,
                color: Color(0xFF0F766E),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.perfilMisInteresesHeader,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: FqColors.muted,
                  ),
                ),
              ),
              InkWell(
                onTap: onGestionar,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF0F766E)),
                      const SizedBox(width: 4),
                      Text(
                        l10n.perfilEditar,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (intereses.isEmpty)
            InkWell(
              onTap: onGestionar,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8DE)),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.add_circle_outline_rounded, size: 16, color: FqColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.perfilInteresesVacio,
                        style: const TextStyle(fontSize: 11, color: FqColors.muted, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String item in intereses)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF3EB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD6E0D3)),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: FqColors.ink,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Tarjeta para mostrar las actividades/deportes favoritos seleccionados del usuario.
class _SeccionActividades extends StatelessWidget {
  const _SeccionActividades({
    required this.actividades,
    required this.onGestionar,
  });

  final List<String> actividades;
  final VoidCallback onGestionar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FqColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.fitness_center_rounded,
                size: 16,
                color: Color(0xFF0369A1),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.perfilMisActividadesHeader,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: FqColors.muted,
                  ),
                ),
              ),
              InkWell(
                onTap: onGestionar,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF0369A1)),
                      const SizedBox(width: 4),
                      Text(
                        l10n.perfilEditar,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (actividades.isEmpty)
            InkWell(
              onTap: onGestionar,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.add_circle_outline_rounded, size: 16, color: FqColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.perfilActividadesVacio,
                        style: const TextStyle(fontSize: 11, color: FqColors.muted, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String item in actividades)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
