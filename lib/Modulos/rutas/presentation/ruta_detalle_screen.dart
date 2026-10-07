import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';
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
  });

  final Ruta ruta;
  final RutaApi? api;
  final bool puedeEnviarARevision;
  final VoidCallback? onCambio;

  @override
  State<RutaDetalleScreen> createState() => _RutaDetalleScreenState();
}

class _RutaDetalleScreenState extends State<RutaDetalleScreen> {
  late final RutaApi _api = widget.api ?? RutaApi();
  bool _enviando = false;
  bool _esFavorita = false;

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
  }

  Future<void> _toggleFavorita() async {
    final bool nueva = await _api.toggleFavorita(widget.ruta.id);
    if (!mounted) return;
    setState(() => _esFavorita = nueva);
    widget.onCambio?.call();
    notificarExito(
      nueva
          ? 'Ruta guardada en tus favoritas'
          : 'Ruta eliminada de tus guardadas',
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
                      // Score / Rating
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const <Widget>[
                            Text(
                              '4.8',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF92400E),
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(Icons.star_rounded,
                                size: 14, color: Color(0xFFD97706)),
                          ],
                        ),
                      ),
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
                            subtitulo: 'Distancia',
                            icono: Icons.straighten_rounded,
                          ),
                        ),
                        Container(width: 1, height: 36, color: FqColors.border),
                        Expanded(
                          child: _MetricaDetalle(
                            valor: '$desnivelEstimadoM',
                            unidad: 'm elev.',
                            subtitulo: dificultadLabel(l10n, ruta.dificultad),
                            icono: Icons.terrain_rounded,
                          ),
                        ),
                        Container(width: 1, height: 36, color: FqColors.border),
                        Expanded(
                          child: _MetricaDetalle(
                            valor: '$tiempoEstimadoMin',
                            unidad: 'min',
                            subtitulo: 'Estimado',
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
                                ? 'Ruta verificada por la comunidad · Apta para entrenar'
                                : 'Ruta propia creada por ti · Lista para recorrer o editar',
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
                                ? 'Editar'
                                : (_esFavorita ? 'Guardada' : 'Guardar'),
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
                                  'Editar ruta: función disponible próximamente');
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
                          label: const Text(
                            'Iniciar recorrido',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          onPressed: () {
                            notificarInfo('Iniciar recorrido: función disponible próximamente');
                          },
                        ),
                      ),
                    ],
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
  });

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
        Text(
          subtitulo,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: FqColors.muted,
          ),
        ),
      ],
    );
  }
}
