import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/core/db/daos/rutas_offline_dao.dart';
import 'package:fit_quest_go/core/mapa/mapas_offline_servicio.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/ficha_lugar.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_icono_dificultad.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion.dart';
import 'package:fit_quest_go/Modulos/calificaciones/data/calificacion_api.dart';
import 'package:fit_quest_go/Modulos/calificaciones/presentation/pulgares.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/recorrido_ruta_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/etiqueta_estado_ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/mapa_trazo_ruta.dart';

/// RTE-08 / RTE-04 · Detalle de ruta (diseño oficial FitQuest Go).
/// Muestra el mapa superior con el trazo real, etiquetas de estado, métricas
/// clave (distancia, desnivel estimado, tiempo estimado), notas de seguridad y
/// botones de acción: "Editar" e "Iniciar recorrido".
class RutaDetalleScreen extends StatefulWidget {
  const RutaDetalleScreen({
    super.key,
    required this.ruta,
    this.api,
    this.puedeEnviarARevision = false,
    this.onCambio,
    this.recorridoBuilder,
    this.calificaciones,
    this.abrirUrl,
  });

  final Ruta ruta;
  final RutaApi? api;
  final bool puedeEnviarARevision;
  final VoidCallback? onCambio;
  final Widget Function(BuildContext, Ruta)? recorridoBuilder;

  /// Pulgares de la ruta, inyectable para pruebas.
  final CalificacionApi? calificaciones;

  /// Abre "Como llegar"; por defecto lanza la app de mapas (inyectable para pruebas).
  final Future<bool> Function(Uri uri)? abrirUrl;

  @override
  State<RutaDetalleScreen> createState() => _RutaDetalleScreenState();
}

class _RutaDetalleScreenState extends State<RutaDetalleScreen> {
  late final RutaApi _api = widget.api ?? RutaApi();
  late final CalificacionApi _calificaciones =
      widget.calificaciones ?? CalificacionApi.predeterminada();

  /// Pulgares de la ruta; null mientras carga (la pantalla funciona sin ellos).
  ResumenCalificacion? _resumen;
  bool _enviando = false;
  bool _esFavorita = false;
  final RutasOfflineDao _offlineDao = RutasOfflineDao();
  bool _guardadaOffline = false;
  bool _descargando = false;
  double _progresoDescarga = 0;

  bool get _esPrivada => widget.ruta.estado == 'Privada';
  bool get _sePuedeEnviar =>
      widget.puedeEnviarARevision && widget.ruta.estado == 'Privada';

  @override
  void initState() {
    super.initState();
    _api.favoritasIds().then((Set<int> ids) {
      if (mounted) {
        setState(() => _esFavorita = ids.contains(widget.ruta.id));
      }
    }).catchError((_) {});
    _calificaciones
        .resumen(TipoCalificable.ruta, widget.ruta.id)
        .then((ResumenCalificacion r) {
      if (mounted) setState(() => _resumen = r);
    }).catchError((_) {});
    _offlineDao.estaGuardada(widget.ruta.id).then((bool g) {
      if (mounted) setState(() => _guardadaOffline = g);
    });
  }

  /// Guarda (o quita) la ruta para verla sin conexion: datos en SQLite y
  /// teselas del mapa de la zona en el almacen de Mapbox.
  Future<void> _toggleOffline() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (_descargando) return;
    if (_guardadaOffline) {
      await _offlineDao.eliminar(widget.ruta.id);
      await MapasOfflineServicio.instancia.eliminarZonaDeRuta(widget.ruta.id);
      if (!mounted) return;
      setState(() => _guardadaOffline = false);
      notificarExito(l10n.mapasOfflineRutaEliminada);
      return;
    }

    // Tope de seguridad: maximo 3 rutas offline simultaneas (protege almacenamiento y cuota gratuita)
    final List<Ruta> guardadas = await _offlineDao.listar();
    if (guardadas.length >= 3) {
      if (!mounted) return;
      notificarInfo(l10n.rutaDetalleLimiteOffline);
      return;
    }

    setState(() {
      _descargando = true;
      _progresoDescarga = 0;
    });
    final bool datosOk = await _offlineDao.guardar(widget.ruta);
    if (!datosOk) {
      if (!mounted) return;
      setState(() => _descargando = false);
      notificarError(l10n.rutaDetalleErrorGuardarOffline);
      return;
    }
    final bool mapaOk = await MapasOfflineServicio.instancia.descargarZonaDeRuta(
      widget.ruta,
      alProgresar: (double p) {
        if (mounted) setState(() => _progresoDescarga = p);
      },
    );
    if (!mounted) return;
    setState(() {
      _descargando = false;
      _guardadaOffline = true;
    });
    if (mapaOk) {
      notificarExito(l10n.rutaDetalleOfflineGuardadoExito);
    } else {
      notificarInfo(l10n.rutaDetalleOfflineSinMapa);
    }
  }

  Future<void> _toggleFavorita() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool nueva = await _api.toggleFavorita(widget.ruta.id);
    if (!mounted) return;
    setState(() => _esFavorita = nueva);
    widget.onCambio?.call();
    notificarExito(
      nueva
          ? l10n.rutaDetalleFavoritaGuardada
          : l10n.rutaDetalleFavoritaEliminada,
    );
  }

  Future<void> _enviarARevision() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    setState(() => _enviando = true);
    try {
      await _api.solicitarPublicacion(widget.ruta.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onCambio?.call();
      notificarExito(l10n.rutasEnviadaARevision);
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      notificarError(l10n.rutasNoSePudoEnviarRuta);
    }
  }

  Future<void> _iniciarRecorrido() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (widget.ruta.puntos.length < 2) {
      notificarInfo(
        l10n.rutaDetalleSinPuntosSuficientes,
      );
      return;
    }
    final bool? guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext ctx) =>
            widget.recorridoBuilder?.call(ctx, widget.ruta) ??
            RecorridoRutaScreen(ruta: widget.ruta),
      ),
    );
    if (guardado == true && mounted) {
      widget.onCambio?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Ruta ruta = widget.ruta;
    final double top = MediaQuery.of(context).padding.top;

    final int tiempoEstimadoMin = (ruta.distanciaKm * 6).round().clamp(5, 360);
    final int desnivelEstimadoM = (ruta.distanciaKm * 28).round().clamp(10, 1500);

    return Scaffold(
      backgroundColor: FqColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ── Cabecera oscura con mapa y barra superior ─────────────────────
          Stack(
            children: <Widget>[
              // Mapa con el trazo
              SizedBox(
                height: 280,
                width: double.infinity,
                child: MapaTrazoRuta(puntos: ruta.puntos),
              ),
              // Barra de navegación flotante
              Container(
                padding: EdgeInsets.fromLTRB(6, top + 4, 12, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xCC0B1220),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0x660B1220),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: FqColors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ruta.nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: FqColors.white,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0x660B1220),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _esFavorita
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: _esFavorita ? FqColors.volt : FqColors.white,
                        ),
                        onPressed: _toggleFavorita,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Cuerpo de la pantalla (RTE-08 / RTE-04) ───────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Fila de título, tag y puntuación
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                EtiquetaEstadoRuta(ruta.estado),
                                const SizedBox(width: 6),
                                if (ruta.actividades.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      actividadesLabel(l10n, ruta.actividades),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0369A1),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ruta.nombre,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: FqColors.ink,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_resumen != null) ...<Widget>[
                        const SizedBox(width: 8),
                        Pulgares(resumen: _resumen!, compacto: true),
                      ],
                    ],
                  ),

                  if (ruta.creadoPorNombre != null &&
                      ruta.creadoPorNombre!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Creada por ${ruta.creadoPorNombre}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: FqColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  FilaAccionesFicha(
                    acciones: <Widget>[
                      AccionFicha(
                        key: const ValueKey<String>('ruta-como-llegar'),
                        icono: Icons.directions_rounded,
                        etiqueta: l10n.fichaComoLlegar,
                        principal: true,
                        onTap: ruta.puntos.isEmpty
                            ? null
                            : () => abrirComoLlegar(
                                context,
                                lat: ruta.puntos.first.lat,
                                lng: ruta.puntos.first.lng,
                                abrir: widget.abrirUrl,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Cuadrícula de 3 Métricas clave
                  Container(
                    decoration: BoxDecoration(
                      color: FqColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: FqColors.border),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 8),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _MetricaDetalle(
                            valor: ruta.distanciaKm.toStringAsFixed(1),
                            unidad: 'km',
                            subtitulo: l10n.rutasDistancia,
                            icono: Icons.straighten_rounded,
                          ),
                        ),
                        Container(width: 1, height: 36, color: FqColors.border),
                        Expanded(
                          child: _MetricaDetalle(
                            valor: '$desnivelEstimadoM',
                            unidad: l10n.rutaDetalleElevacion,
                            subtitulo: dificultadLabel(l10n, ruta.dificultad),
                            dificultad: ruta.dificultad,
                            icono: Icons.terrain_rounded,
                          ),
                        ),
                        Container(width: 1, height: 36, color: FqColors.border),
                        Expanded(
                          child: _MetricaDetalle(
                            valor: '$tiempoEstimadoMin',
                            unidad: 'min',
                            subtitulo: l10n.rutaDetalleEstimado,
                            icono: Icons.timer_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Nota de Seguridad / Verificación Comunitaria (RTE-08 style)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.verified_user_rounded,
                          size: 18,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ruta.estado == 'Publicada'
                                ? l10n.rutaDetalleVerificadaComunidad
                                : l10n.rutaDetallePropia,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_resumen != null) ...<Widget>[
                    const SizedBox(height: 16),
                    SeccionFicha(
                      titulo: l10n.calificarPregunta,
                      hijo: PulgaresObjeto(
                        tipo: TipoCalificable.ruta,
                        id: ruta.id,
                        api: _calificaciones,
                        resumenInicial: _resumen,
                        alCambiar: (ResumenCalificacion r) =>
                            setState(() => _resumen = r),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Botones de acción principales (RTE-08) ────────────────
                  Row(
                    children: <Widget>[
                      // Botón 1: Editar (si es privada/propia) o Guardar (si es pública)
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: !_esPrivada && _esFavorita
                                  ? const Color(0xFF0D9488)
                                  : FqColors.border,
                            ),
                            backgroundColor: !_esPrivada && _esFavorita
                                ? const Color(0xFFF0FDFA)
                                : FqColors.white,
                          ),
                          icon: Icon(
                            _esPrivada
                                ? Icons.edit_outlined
                                : (_esFavorita
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded),
                            size: 16,
                            color: !_esPrivada && _esFavorita
                                ? const Color(0xFF0D9488)
                                : FqColors.ink,
                          ),
                          label: Text(
                            _esPrivada
                                ? l10n.perfilEditar
                                : (_esFavorita ? l10n.rutaDetalleGuardada : l10n.rutaDetalleGuardar),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: !_esPrivada && _esFavorita
                                    ? const Color(0xFF0D9488)
                                    : FqColors.ink,
                            ),
                          ),
                          onPressed: () {
                            if (_esPrivada) {
                              notificarInfo(
                                  l10n.rutaDetalleEditarPronto);
                            } else {
                              _toggleFavorita();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Botón 2: Iniciar recorrido (Primary Volt)
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FqColors.volt,
                            foregroundColor: FqColors.night,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: Text(
                            l10n.rutaDetalleIniciarRecorrido,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          onPressed: _iniciarRecorrido,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      side: BorderSide(
                        color: _guardadaOffline
                            ? const Color(0xFF0D9488)
                            : FqColors.border,
                      ),
                    ),
                    icon: _descargando
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: _progresoDescarga > 0 ? _progresoDescarga : null,
                            ),
                          )
                        : Icon(
                            _guardadaOffline
                                ? Icons.download_done_rounded
                                : Icons.download_outlined,
                            size: 16,
                            color: _guardadaOffline
                                ? const Color(0xFF0D9488)
                                : FqColors.ink,
                          ),
                    label: Text(
                      _descargando
                          ? l10n.rutaDetalleDescargando((_progresoDescarga * 100).round())
                          : (_guardadaOffline
                              ? l10n.rutaDetalleDisponibleOfflineQuitar
                              : l10n.rutaDetalleGuardarOffline),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FqColors.ink,
                      ),
                    ),
                    onPressed: _descargando ? null : _toggleOffline,
                  ),

                  // Enviar a revisión (si aplica)
                  if (_sePuedeEnviar) ...<Widget>[
                    const SizedBox(height: 12),
                    FqButton.ghost(
                      label: _enviando
                          ? l10n.comunEnviando
                          : l10n.rutasEnviarARevision,
                      icon: Icons.send_rounded,
                      onPressed: _enviando ? null : _enviarARevision,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricaDetalle extends StatelessWidget {
  const _MetricaDetalle({
    required this.valor,
    required this.unidad,
    required this.subtitulo,
    required this.icono,
    this.dificultad,
  });

  /// Si se da, el subtitulo lleva la carita de esa dificultad.
  final String? dificultad;
  final String valor;
  final String unidad;
  final String subtitulo;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              valor,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: FqColors.ink,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unidad,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: FqColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (dificultad != null) ...<Widget>[
              IconoDificultad(dificultad: dificultad!, size: 15),
              const SizedBox(width: 4),
            ],
            Text(
              subtitulo,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: FqColors.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
