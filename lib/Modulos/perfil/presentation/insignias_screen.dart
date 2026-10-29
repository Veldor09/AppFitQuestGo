import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/db/daos/insignias_cache_dao.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/red/conexion_servicio.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/perfil/data/insignia.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';

/// BDG-01 - Insignias del usuario, consumidas desde el backend o caché local offline.
///
/// Si se indica [idUsuario] muestra las insignias de ese usuario (perfil
/// público); si no, las del usuario autenticado.
class InsigniasScreen extends StatefulWidget {
  const InsigniasScreen({
    super.key,
    this.api,
    this.cacheDao,
    this.idUsuario,
    this.nombre,
  });

  final PerfilApi? api;
  final InsigniasCacheDao? cacheDao;
  final int? idUsuario;
  final String? nombre;

  @override
  State<InsigniasScreen> createState() => _InsigniasScreenState();
}

class _InsigniasScreenState extends State<InsigniasScreen> {
  late final PerfilApi _api = widget.api ?? PerfilApi();
  late final InsigniasCacheDao _cacheDao =
      widget.cacheDao ?? InsigniasCacheDao();
  late Future<List<Insignia>> _futuro = _cargar();
  bool _esOffline = false;

  @override
  void initState() {
    super.initState();
    ConexionServicio.instancia.reconectado.addListener(_alReconectar);
  }

  @override
  void dispose() {
    ConexionServicio.instancia.reconectado.removeListener(_alReconectar);
    super.dispose();
  }

  void _alReconectar() {
    if (mounted) _recargar();
  }

  Future<List<Insignia>> _cargar() async {
    final bool propio = widget.idUsuario == null;
    if (propio) {
      try {
        final List<Insignia> remotas = await _api.misInsignias();
        if (mounted) setState(() => _esOffline = false);
        await _cacheDao.guardarTodas(remotas);
        return remotas;
      } catch (_) {
        final List<Insignia> enCache = await _cacheDao.listar();
        if (mounted) setState(() => _esOffline = true);
        if (enCache.isNotEmpty) {
          return enCache;
        }
        rethrow;
      }
    } else {
      if (mounted) setState(() => _esOffline = false);
      return _api.insigniasDeUsuario(widget.idUsuario!);
    }
  }

  Future<void> _recargar() async {
    final Future<List<Insignia>> nuevo = _cargar();
    setState(() => _futuro = nuevo);
    try {
      await nuevo;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final double top = MediaQuery.of(context).padding.top;
    final bool propio = widget.idUsuario == null;
    return Scaffold(
      backgroundColor: FqColors.paper,
      body: Column(
        children: <Widget>[
          Container(
            color: FqColors.night,
            padding: EdgeInsets.fromLTRB(4, top + 4, 16, 12),
            child: Row(
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: FqColors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    propio
                        ? l10n.insigniasTitulo
                        : (widget.nombre != null
                            ? l10n.insigniasDeUsuario(widget.nombre!)
                            : l10n.perfilInsignias),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: FqColors.white),
                  ),
                ),
              ],
            ),
          ),
          if (_esOffline)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                      l10n.insigniasModoSinConexion,
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
            child: FutureBuilder<List<Insignia>>(
              future: _futuro,
              builder: (BuildContext ctx, AsyncSnapshot<List<Insignia>> snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }
                if (snap.hasError) {
                  return FqEmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: l10n.insigniasErrorCarga,
                    message: _esOffline
                        ? l10n.insigniasSinConexionMensaje
                        : l10n.insigniasErrorCargaMsg,
                    action: TextButton(onPressed: _recargar, child: Text(l10n.comunReintentar)),
                  );
                }
                final List<Insignia> todas = snap.data!;
                final List<Insignia> ganadas =
                    todas.where((Insignia i) => i.desbloqueada).toList();
                final List<Insignia> pendientes =
                    todas.where((Insignia i) => !i.desbloqueada).toList();

                if (todas.isEmpty) {
                  return FqEmptyState(
                    icon: Icons.military_tech_outlined,
                    title: l10n.insigniasVacioTitulo,
                    message: l10n.insigniasVacioMsg,
                  );
                }

                return RefreshIndicator(
                  onRefresh: _recargar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      _ResumenInsignias(ganadas: ganadas.length, total: todas.length),
                      const SizedBox(height: 16),
                      if (ganadas.isNotEmpty) ...<Widget>[
                        _SeccionTitulo(titulo: l10n.insigniasGanadas),
                        const SizedBox(height: 8),
                        _Grilla(insignias: ganadas),
                        const SizedBox(height: 16),
                      ] else if (propio)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            l10n.insigniasSinGanadas,
                            style: const TextStyle(fontSize: 12, color: FqColors.muted),
                          ),
                        ),
                      if (pendientes.isNotEmpty) ...<Widget>[
                        _SeccionTitulo(titulo: l10n.insigniasPorDesbloquear),
                        const SizedBox(height: 8),
                        _Grilla(insignias: pendientes),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Grilla extends StatelessWidget {
  const _Grilla({required this.insignias});
  final List<Insignia> insignias;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.8,
      children: insignias.map((Insignia i) => _InsigniaCard(data: i)).toList(),
    );
  }
}

class _ResumenInsignias extends StatelessWidget {
  const _ResumenInsignias({required this.ganadas, required this.total});
  final int ganadas;
  final int total;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: FqColors.night, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: <Widget>[
          _Stat(valor: '$ganadas', etiqueta: l10n.insigniasDesbloqueadasStat),
          Container(width: 1, height: 40, color: const Color(0xFF2A4060)),
          _Stat(valor: '${total - ganadas}', etiqueta: l10n.insigniasPorDesbloquearStat),
        ],
      ),
    );
  }
}


class _Stat extends StatelessWidget {
  const _Stat({required this.valor, required this.etiqueta});
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: FqColors.volt)),
          Text(etiqueta, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: FqColors.stone, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  const _SeccionTitulo({required this.titulo});
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Text(titulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: FqColors.muted, letterSpacing: 0.3));
  }
}

class _InsigniaCard extends StatelessWidget {
  const _InsigniaCard({required this.data});
  final Insignia data;

  @override
  Widget build(BuildContext context) {
    final bool pendiente = !data.desbloqueada;
    final double? p = data.progreso;
    final double? m = data.meta;
    final bool conProgreso = pendiente && p != null && m != null && m > 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: pendiente ? FqColors.cloud : FqColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pendiente ? FqColors.border : FqColors.volt.withOpacity(0.6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Opacity(
            opacity: pendiente ? 0.3 : 1.0,
            child: Text(data.emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 4),
          Text(data.nombre, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: pendiente ? FqColors.stone : FqColors.ink)),
          Text(data.descripcion, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, color: FqColors.muted, height: 1.3)),
          if (conProgreso) ...<Widget>[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (p / m).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: FqColors.border,
                color: FqColors.voltDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
