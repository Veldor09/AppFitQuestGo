import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/Modulos/perfil/data/perfil_api.dart';

/// BDG-01 - Insignias del usuario.
class InsigniasScreen extends StatelessWidget {
  const InsigniasScreen({super.key, this.api});
  final PerfilApi? api;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.of(context).padding.top;
    final PerfilApi perfilApi = api ?? PerfilApi();
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
                const Expanded(
                  child: Text('Mis Insignias', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: FqColors.white)),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: perfilApi.estadisticasPropias(),
              builder: (BuildContext ctx, AsyncSnapshot<Map<String, dynamic>> snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }
                if (snap.hasError) {
                  return FqEmptyState(icon: Icons.error_outline, title: 'Error', message: snap.error.toString());
                }
                final int insignias = (snap.data!['insignias'] as int?) ?? 0;
                final double km = ((snap.data!['kmRecorridos'] as num?) ?? 0).toDouble();
                final int rutas = (snap.data!['rutasCompletadas'] as int?) ?? 0;

                final List<_InsigniaData> ganadas = <_InsigniaData>[
                  if (rutas >= 1) const _InsigniaData(emoji: '🥾', titulo: 'Primera ruta', sub: 'Completaste tu primera ruta'),
                  if (rutas >= 5) const _InsigniaData(emoji: '🏅', titulo: 'Explorador', sub: 'Completaste 5 rutas'),
                  if (rutas >= 10) const _InsigniaData(emoji: '🏆', titulo: 'Veterano', sub: '10 rutas completadas'),
                  if (km >= 100) const _InsigniaData(emoji: '🌍', titulo: '100 km', sub: 'Recorriste 100 km acumulados'),
                  if (km >= 500) const _InsigniaData(emoji: '🚀', titulo: '500 km', sub: '500 km acumulados'),
                ];

                final List<_InsigniaData> pendientes = <_InsigniaData>[
                  if (rutas < 1) const _InsigniaData(emoji: '🥾', titulo: 'Primera ruta', sub: 'Completa tu primera ruta', pendiente: true),
                  if (rutas < 5) const _InsigniaData(emoji: '🏅', titulo: 'Explorador', sub: 'Completa 5 rutas', pendiente: true),
                  if (rutas < 10) const _InsigniaData(emoji: '🏆', titulo: 'Veterano', sub: 'Completa 10 rutas', pendiente: true),
                  if (km < 100) const _InsigniaData(emoji: '🌍', titulo: '100 km', sub: 'Recorre 100 km acumulados', pendiente: true),
                  if (km < 500) const _InsigniaData(emoji: '🚀', titulo: '500 km', sub: 'Recorre 500 km acumulados', pendiente: true),
                ];

                if (insignias == 0 && rutas == 0) {
                  return const FqEmptyState(
                    icon: Icons.military_tech_outlined,
                    title: 'Aún no tienes insignias',
                    message: 'Completa rutas publicadas para ganar tus primeras insignias.',
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _StatsRow(km: km, rutas: rutas, insignias: insignias),
                    const SizedBox(height: 16),
                    if (ganadas.isNotEmpty) ...<Widget>[
                      const _SeccionTitulo(titulo: 'Insignias ganadas'),
                      const SizedBox(height: 8),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                        children: ganadas.map((d) => _InsigniaCard(data: d)).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (pendientes.isNotEmpty) ...<Widget>[
                      const _SeccionTitulo(titulo: 'Por desbloquear'),
                      const SizedBox(height: 8),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                        children: pendientes.map((d) => _InsigniaCard(data: d)).toList(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InsigniaData {
  const _InsigniaData({required this.emoji, required this.titulo, required this.sub, this.pendiente = false});
  final String emoji;
  final String titulo;
  final String sub;
  final bool pendiente;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.km, required this.rutas, required this.insignias});
  final double km;
  final int rutas;
  final int insignias;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: FqColors.night, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: <Widget>[
          _Stat(valor: '${km.toStringAsFixed(1)}', etiqueta: 'KM'),
          _sep(),
          _Stat(valor: '$rutas', etiqueta: 'RUTAS'),
          _sep(),
          _Stat(valor: '$insignias', etiqueta: 'INSIGNIAS'),
        ],
      ),
    );
  }

  Widget _sep() => Container(width: 1, height: 40, color: const Color(0xFF2A4060));
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
  final _InsigniaData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: data.pendiente ? FqColors.cloud : FqColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: data.pendiente ? FqColors.border : FqColors.volt.withOpacity(0.6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Opacity(
            opacity: data.pendiente ? 0.3 : 1.0,
            child: Text(data.emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 4),
          Text(data.titulo, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: data.pendiente ? FqColors.stone : FqColors.ink)),
          Text(data.sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: FqColors.muted, height: 1.3)),
        ],
      ),
    );
  }
}
