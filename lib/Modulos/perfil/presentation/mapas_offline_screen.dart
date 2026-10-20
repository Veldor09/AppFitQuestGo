import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/db/daos/rutas_offline_dao.dart';
import 'package:fit_quest_go/core/mapa/mapas_offline_servicio.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/ruta_detalle_screen.dart';

/// Rutas descargadas para usar sin conexion (datos en SQLite + teselas del
/// mapa de su zona). Se abre desde Perfil > Mapas offline.
class MapasOfflineScreen extends StatefulWidget {
  const MapasOfflineScreen({super.key, this.dao});

  final RutasOfflineDao? dao;

  @override
  State<MapasOfflineScreen> createState() => _MapasOfflineScreenState();
}

class _MapasOfflineScreenState extends State<MapasOfflineScreen> {
  late final RutasOfflineDao _dao = widget.dao ?? RutasOfflineDao();
  late Future<List<Ruta>> _futuro = _dao.listar();

  void _recargar() => setState(() => _futuro = _dao.listar());

  Future<void> _quitar(Ruta ruta) async {
    await _dao.eliminar(ruta.id);
    await MapasOfflineServicio.instancia.eliminarZonaDeRuta(ruta.id);
    if (!mounted) return;
    notificarExito('Ruta eliminada del uso offline');
    _recargar();
  }

  Future<void> _abrir(Ruta ruta) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RutaDetalleScreen(ruta: ruta),
      ),
    );
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.of(context).padding.top;
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
                  child: Text(
                    'Mapas offline',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: FqColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Ruta>>(
              future: _futuro,
              builder: (BuildContext ctx, AsyncSnapshot<List<Ruta>> snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }
                final List<Ruta> rutas = snap.data ?? <Ruta>[];
                if (rutas.isEmpty) {
                  return const FqEmptyState(
                    icon: Icons.download_outlined,
                    title: 'Aún no tienes rutas offline',
                    message:
                        'Abre una ruta y pulsa "Guardar para uso offline" para '
                        'verla sin conexión.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rutas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext c, int i) {
                    final Ruta r = rutas[i];
                    return Material(
                      color: FqColors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _abrir(r),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: FqColors.border),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(Icons.download_done_rounded,
                                  color: Color(0xFF0D9488)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      r.nombre,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${r.distanciaKm.toStringAsFixed(1)} km · '
                                      '${r.puntos.length} puntos',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: FqColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Quitar de offline',
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () => _quitar(r),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
