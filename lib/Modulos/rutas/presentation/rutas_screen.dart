import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/red/conexion_servicio.dart';
import 'package:fit_quest_go/core/widgets/carga_lista.dart';
import 'package:fit_quest_go/core/widgets/fq_icono_dificultad.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/core/db/daos/rutas_offline_dao.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/ruta_detalle_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/eliminar_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/etiqueta_estado_ruta.dart';

/// RTE-01/02/03 · Rutas (vista de usuario).
/// - "Explorar" (RTE-01): rutas publicadas comunitarias (`/rutas/explorar`).
/// - "Mis rutas" (RTE-02): rutas propias (`/rutas/mias`).
/// - "Guardadas" (RTE-03): rutas favoritas / guardadas (`/rutas/favoritas`) o descargadas offline.
class RutasScreen extends StatefulWidget {
  const RutasScreen({
    super.key,
    this.api,
    this.offlineDao,
    this.initialTab = 0,
    this.showBackButton,
  });

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final RutaApi? api;

  /// DAO de rutas descargadas para uso offline.
  final RutasOfflineDao? offlineDao;

  /// Pestaña inicial (0: Explorar, 1: Mis rutas, 2: Guardadas).
  final int initialTab;

  /// Si es true muestra la cabecera oscura con botón de retroceso (estilo "Mis Insignias" / "Mis Contribuciones").
  /// Si es null, detecta automáticamente si la pantalla fue abierta mediante push (Navigator.canPop).
  final bool? showBackButton;

  @override
  State<RutasScreen> createState() => _RutasScreenState();
}

class _RutasScreenState extends State<RutasScreen> {
  late final RutaApi _api = widget.api ?? RutaApi();
  late final RutasOfflineDao _offlineDao =
      widget.offlineDao ?? RutasOfflineDao();
  late final CargaLista<Ruta> _explorar = CargaLista<Ruta>(() => _api.explorar());
  late final CargaLista<Ruta> _misRutas = CargaLista<Ruta>(() => _api.misRutas());
  late final CargaLista<Ruta> _favoritas = CargaLista<Ruta>(_cargarFavoritas);
  Set<int> _favoritasIds = <int>{};
  bool _esOfflineGuardadas = false;
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 2);
    _cargar();
    ConexionServicio.instancia.reconectado.addListener(_alReconectar);
  }

  @override
  void dispose() {
    ConexionServicio.instancia.reconectado.removeListener(_alReconectar);
    _explorar.dispose();
    _misRutas.dispose();
    _favoritas.dispose();
    super.dispose();
  }

  Future<List<Ruta>> _cargarFavoritas() async {
    try {
      final List<Ruta> remotas = await _api.favoritas();
      if (mounted) setState(() => _esOfflineGuardadas = false);
      return remotas;
    } catch (_) {
      // Sin conexión: recurrir a las rutas guardadas/descargadas para offline
      final List<Ruta> offline = await _offlineDao.listar();
      if (mounted) setState(() => _esOfflineGuardadas = true);
      return offline;
    }
  }

  void _cargar({bool silencioso = false}) {
    _explorar.cargar(silencioso: silencioso);
    _misRutas.cargar(silencioso: silencioso);
    _favoritas.cargar(silencioso: silencioso);
    _api.favoritasIds().then((Set<int> ids) {
      if (mounted) setState(() => _favoritasIds = ids);
    }).catchError((_) async {
      final List<Ruta> offline = await _offlineDao.listar();
      if (mounted) {
        setState(() {
          _favoritasIds = offline.map((Ruta r) => r.id).toSet();
        });
      }
    });
  }

  void _recargar() => _cargar(silencioso: true);

  void _alReconectar() {
    if (mounted) _cargar(silencioso: true);
  }

  void _rutaEliminada(int id) {
    for (final CargaLista<Ruta> lista in <CargaLista<Ruta>>[
      _explorar,
      _misRutas,
      _favoritas,
    ]) {
      lista.quitar((Ruta r) => r.id == id);
    }
    setState(() => _favoritasIds.remove(id));
  }

  Future<void> _toggleFavorita(int rutaId) async {
    try {
      final bool agregada = await _api.toggleFavorita(rutaId);
      if (!mounted) return;
      setState(() {
        if (agregada) {
          _favoritasIds.add(rutaId);
        } else {
          _favoritasIds.remove(rutaId);
        }
      });
      _favoritas.cargar(silencioso: true);
      final AppLocalizations l10nOk = AppLocalizations.of(context)!;
      notificarExito(
        agregada ? l10nOk.rutasFavoritaAgregada : l10nOk.rutasFavoritaQuitada,
      );
    } catch (_) {
      if (!mounted) return;
      final AppLocalizations l10nErr = AppLocalizations.of(context)!;
      final bool estaOffline = await _offlineDao.estaGuardada(rutaId);
      if (estaOffline) {
        notificarInfo(l10nErr.rutasGuardadaSinConexion);
      } else {
        notificarError(l10nErr.rutasErrorGuardadasSinConexion);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool mostrarAtras =
        widget.showBackButton ?? Navigator.canPop(context);

    if (mostrarAtras) {
      final double top = MediaQuery.of(context).padding.top;
      return Scaffold(
        backgroundColor: FqColors.paper,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ── Cabecera oscura con botón Volver (estilo Mis Aportes / Mis Insignias)
            Container(
              color: FqColors.night,
              padding: EdgeInsets.fromLTRB(4, top + 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: FqColors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          l10n.rutasTitulo,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: FqColors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _Segmentado(
                      opciones: <String>[
                        l10n.rutasExplorar,
                        l10n.rutasMisRutas,
                        'Guardadas'
                      ],
                      seleccion: _tab,
                      onSeleccion: (int i) => setState(() => _tab = i),
                      enCabeceraOscura: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildCuerpoTab(),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: FqColors.paper,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                l10n.rutasTitulo,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Segmentado(
                opciones: <String>[
                  l10n.rutasExplorar,
                  l10n.rutasMisRutas,
                  'Guardadas'
                ],
                seleccion: _tab,
                onSeleccion: (int i) => setState(() => _tab = i),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildCuerpoTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCuerpoTab() {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (_tab == 0) {
      return _ListaRutas(
        key: const ValueKey<String>('explorar'),
        api: _api,
        carga: _explorar,
        favoritasIds: _favoritasIds,
        onToggleFavorita: _toggleFavorita,
        onCambio: _recargar,
        onEliminada: _rutaEliminada,
        vacioTitulo: l10n.rutasSinPublicadas,
        vacioMensaje: l10n.rutasSinPublicadasMensaje,
      );
    }
    if (_tab == 1) {
      return _ListaRutas(
        key: const ValueKey<String>('mias'),
        api: _api,
        carga: _misRutas,
        favoritasIds: _favoritasIds,
        onToggleFavorita: _toggleFavorita,
        onCambio: _recargar,
        onEliminada: _rutaEliminada,
        mostrarEstado: true,
        vacioTitulo: l10n.rutasSinPropias,
        vacioMensaje: l10n.rutasSinPropiasMensaje,
      );
    }
    return _ListaRutas(
      key: const ValueKey<String>('guardadas'),
      api: _api,
      carga: _favoritas,
      favoritasIds: _favoritasIds,
      onToggleFavorita: _toggleFavorita,
      onCambio: _recargar,
      onEliminada: _rutaEliminada,
      esOffline: _esOfflineGuardadas,
      vacioTitulo: l10n.rutasSinGuardadas,
      vacioMensaje: _esOfflineGuardadas
          ? l10n.rutasSinGuardadasOffline
          : l10n.rutasSinGuardadasMensaje,
    );
  }
}

class _Segmentado extends StatelessWidget {
  const _Segmentado({
    required this.opciones,
    required this.seleccion,
    required this.onSeleccion,
    this.enCabeceraOscura = false,
  });

  final List<String> opciones;
  final int seleccion;
  final ValueChanged<int> onSeleccion;
  final bool enCabeceraOscura;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: enCabeceraOscura ? const Color(0x2AFFFFFF) : FqColors.cloud,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < opciones.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSeleccion(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: i == seleccion
                        ? (enCabeceraOscura ? FqColors.volt : FqColors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: (i == seleccion && !enCabeceraOscura)
                        ? FqColors.panelShadow
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    opciones[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: i == seleccion
                          ? (enCabeceraOscura ? FqColors.night : FqColors.ink)
                          : (enCabeceraOscura
                              ? const Color(0xFFB7C3D1)
                              : FqColors.muted),
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

class _ListaRutas extends StatelessWidget {
  const _ListaRutas({
    super.key,
    required this.api,
    required this.carga,
    required this.favoritasIds,
    required this.onToggleFavorita,
    required this.onCambio,
    required this.onEliminada,
    required this.vacioTitulo,
    required this.vacioMensaje,
    this.mostrarEstado = false,
    this.esOffline = false,
  });

  final RutaApi api;
  final CargaLista<Ruta> carga;
  final Set<int> favoritasIds;
  final ValueChanged<int> onToggleFavorita;
  final VoidCallback onCambio;
  final ValueChanged<int> onEliminada;
  final bool mostrarEstado;
  final bool esOffline;
  final String vacioTitulo;
  final String vacioMensaje;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return CargaListaVista<Ruta>(
      carga: carga,
      error: (BuildContext context, Object error) => FqEmptyState(
        icon: Icons.wifi_off_rounded,
        title: l10n.rutasNoSePudoCargar,
        message: _mensajeError(l10n, error),
        action: TextButton(
          onPressed: carga.cargar,
          child: Text(l10n.rutasReintentar),
        ),
      ),
      datos: (BuildContext context, List<Ruta> rutas) {
        if (rutas.isEmpty) {
          return FqEmptyState(
            icon: esOffline ? Icons.wifi_off_rounded : Icons.route_outlined,
            title: vacioTitulo,
            message: vacioMensaje,
          );
        }
        return Column(
          children: <Widget>[
            if (esOffline)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
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
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.rutasModoSinConexion,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: rutas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int i) => _TarjetaRuta(
                  key: ValueKey<int>(rutas[i].id),
                  api: api,
                  ruta: rutas[i],
                  esFavorita: favoritasIds.contains(rutas[i].id),
                  onToggleFavorita: () => onToggleFavorita(rutas[i].id),
                  mostrarEstado: mostrarEstado,
                  onCambio: onCambio,
                  onEliminada: () => onEliminada(rutas[i].id),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _mensajeError(AppLocalizations l10n, Object error) {
    if (error is ApiException) return error.message;
    return l10n.rutasErrorConexionGenerico;
  }
}

class _TarjetaRuta extends StatelessWidget {
  const _TarjetaRuta({
    super.key,
    required this.api,
    required this.ruta,
    required this.esFavorita,
    required this.onToggleFavorita,
    required this.mostrarEstado,
    required this.onCambio,
    required this.onEliminada,
  });

  final RutaApi api;
  final Ruta ruta;
  final bool esFavorita;
  final VoidCallback onToggleFavorita;
  final bool mostrarEstado;
  final VoidCallback onCambio;
  final VoidCallback onEliminada;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _abrirDetalle(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FqColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FqColors.border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: FqColors.listIconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.route_rounded, color: FqColors.night),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    ruta.nombre,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: FqColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      IconoDificultad(dificultad: ruta.dificultad, size: 15),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          '${actividadesLabel(l10n, ruta.actividades)} · ${ruta.distanciaKm.toStringAsFixed(1)} km · '
                          '${dificultadLabel(l10n, ruta.dificultad)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: FqColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                esFavorita ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: esFavorita ? const Color(0xFF0F766E) : FqColors.muted,
                size: 22,
              ),
              tooltip: esFavorita ? l10n.rutasQuitarGuardada : l10n.rutasGuardarRuta,
              splashRadius: 18,
              onPressed: onToggleFavorita,
            ),
            if (mostrarEstado) ...<Widget>[
              const SizedBox(width: 8),
              EtiquetaEstadoRuta(ruta.estado),
              IconButton(
                key: ValueKey<String>('eliminar-ruta-${ruta.id}'),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: FqColors.risk,
                  size: 22,
                ),
                tooltip: AppLocalizations.of(context)!.rutasEliminar,
                splashRadius: 18,
                onPressed: () async {
                  final bool eliminada =
                      await confirmarYEliminarRuta(context, api, ruta);
                  if (eliminada) onEliminada();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Detalle a pantalla completa (mapa con el trazo + datos). Solo en "Mis
  /// rutas" se ofrece enviar a revision, y solo si la ruta sigue Privada.
  void _abrirDetalle(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => RutaDetalleScreen(
          ruta: ruta,
          api: api,
          puedeEnviarARevision: mostrarEstado,
          puedeEliminar: mostrarEstado,
          onCambio: onCambio,
          alEliminar: onEliminada,
        ),
      ),
    );
  }
}
