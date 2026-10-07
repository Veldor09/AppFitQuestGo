import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

import 'package:fit_quest_go/Modulos/rutas/presentation/ruta_detalle_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/etiqueta_estado_ruta.dart';

/// PRF-02 / RTE-02 - Mis aportes: Rutas creadas, Alertas y Nodos.
class AportesScreen extends StatefulWidget {
  const AportesScreen({
    super.key,
    this.rutaApi,
    this.alertaApi,
    this.nodoApi,
  });

  final RutaApi? rutaApi;
  final AlertaApi? alertaApi;
  final NodoApi? nodoApi;

  @override
  State<AportesScreen> createState() => _AportesScreenState();
}

class _AportesScreenState extends State<AportesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  late final RutaApi _rutaApi = widget.rutaApi ?? RutaApi();
  late final AlertaApi _alertaApi = widget.alertaApi ?? AlertaApi();
  late final NodoApi _nodoApi = widget.nodoApi ?? NodoApi();
  int _recargarContador = 0;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _recargarRutas() {
    setState(() {
      _recargarContador++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: FqColors.paper,
      body: Column(
        children: <Widget>[
          // ── Cabecera ──────────────────────────────────────────────────────
          Container(
            color: FqColors.night,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(4, top + 4, 16, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: FqColors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Mis aportes',
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
                TabBar(
                  controller: _tabs,
                  indicatorColor: FqColors.volt,
                  labelColor: FqColors.volt,
                  unselectedLabelColor: FqColors.stone,
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  tabs: const <Tab>[
                    Tab(text: 'Rutas'),
                    Tab(text: 'Alertas'),
                    Tab(text: 'Puntos / Nodos'),
                  ],
                ),
              ],
            ),
          ),
          // ── Contenido ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[
                _TabMisRutas(
                  key: ValueKey<int>(_recargarContador),
                  rutaApi: _rutaApi,
                  onCambio: _recargarRutas,
                ),
                _TabMisAlertas(alertaApi: _alertaApi),
                _TabMisNodos(nodoApi: _nodoApi),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Rutas Creadas ──────────────────────────────────────────────────────

class _TabMisRutas extends StatelessWidget {
  const _TabMisRutas({
    super.key,
    required this.rutaApi,
    required this.onCambio,
  });

  final RutaApi rutaApi;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Ruta>>(
      future: rutaApi.misRutas(),
      builder: (BuildContext ctx, AsyncSnapshot<List<Ruta>> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError) {
          return FqEmptyState(
            icon: Icons.error_outline,
            title: 'Error al cargar rutas',
            message: snap.error.toString(),
          );
        }
        final List<Ruta> rutas = snap.data ?? <Ruta>[];
        if (rutas.isEmpty) {
          return const FqEmptyState(
            icon: Icons.route_outlined,
            title: 'Aún no has creado rutas',
            message: 'Diseña tu primera ruta trazándola en el mapa.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rutas.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, int i) => _RutaFila(
            ruta: rutas[i],
            rutaApi: rutaApi,
            onCambio: onCambio,
          ),
        );
      },
    );
  }
}

class _RutaFila extends StatelessWidget {
  const _RutaFila({
    required this.ruta,
    required this.rutaApi,
    required this.onCambio,
  });

  final Ruta ruta;
  final RutaApi rutaApi;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    final String acts = l10n != null
        ? actividadesLabel(l10n, ruta.actividades)
        : ruta.actividades.join(', ');
    final String subtitulo = acts.isNotEmpty
        ? '$acts  ·  ${ruta.distanciaKm.toStringAsFixed(1)} km'
        : '${ruta.distanciaKm.toStringAsFixed(1)} km';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (BuildContext _) => RutaDetalleScreen(
              ruta: ruta,
              api: rutaApi,
              puedeEnviarARevision: ruta.estado == 'Privada',
              onCambio: onCambio,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FqColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FqColors.border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: FqColors.listIconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.route_outlined,
                  size: 18, color: FqColors.night),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    ruta.nombre,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: FqColors.ink,
                    ),
                  ),
                  Text(
                    subtitulo,
                    style: const TextStyle(fontSize: 10, color: FqColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            EtiquetaEstadoRuta(ruta.estado),
          ],
        ),
      ),
    );
  }
}

// ── Tab 2: Alertas Comunitarias ───────────────────────────────────────────────

class _TabMisAlertas extends StatelessWidget {
  const _TabMisAlertas({required this.alertaApi});
  final AlertaApi alertaApi;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Alerta>>(
      future: alertaApi.misAlertas(),
      builder: (BuildContext ctx, AsyncSnapshot<List<Alerta>> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError) {
          return FqEmptyState(
            icon: Icons.error_outline,
            title: 'Error al cargar alertas',
            message: snap.error.toString(),
          );
        }
        final List<Alerta> alertas = snap.data ?? <Alerta>[];
        if (alertas.isEmpty) {
          return const FqEmptyState(
            icon: Icons.warning_amber_rounded,
            title: 'No has reportado alertas',
            message:
                'Reporta incidencias en el camino (baches, árboles, etc.) para ayudar a la comunidad.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: alertas.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, int i) => _AlertaFila(alerta: alertas[i]),
        );
      },
    );
  }
}

class _AlertaFila extends StatelessWidget {
  const _AlertaFila({required this.alerta});
  final Alerta alerta;

  Color get _colorGravedad {
    switch (alerta.gravedad.toLowerCase()) {
      case 'grave':
        return Colors.red;
      case 'moderada':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FqColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _colorGravedad.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.warning_amber_rounded,
                size: 18, color: _colorGravedad),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  alerta.tipo,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FqColors.ink,
                  ),
                ),
                Text(
                  alerta.descripcion ?? 'Sin descripción adicional',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: FqColors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: FqColors.paper,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FqColors.border),
            ),
            child: Text(
              alerta.estado,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: FqColors.stone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 3: Nodos / Puntos de Interés ──────────────────────────────────────────

class _TabMisNodos extends StatelessWidget {
  const _TabMisNodos({required this.nodoApi});
  final NodoApi nodoApi;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Nodo>>(
      future: nodoApi.misNodos(),
      builder: (BuildContext ctx, AsyncSnapshot<List<Nodo>> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError) {
          return FqEmptyState(
            icon: Icons.error_outline,
            title: 'Error al cargar puntos de interés',
            message: snap.error.toString(),
          );
        }
        final List<Nodo> nodos = snap.data ?? <Nodo>[];
        if (nodos.isEmpty) {
          return const FqEmptyState(
            icon: Icons.location_on_outlined,
            title: 'Aún no has propuesto puntos de interés',
            message:
                'Propón fuentes de agua, miradores o talleres en el mapa para compartirlos.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: nodos.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, int i) => _NodoFila(nodo: nodos[i]),
        );
      },
    );
  }
}

class _NodoFila extends StatelessWidget {
  const _NodoFila({required this.nodo});
  final Nodo nodo;

  Color get _colorEstado {
    switch (nodo.estado.toLowerCase()) {
      case 'aprobado':
        return FqColors.trail;
      case 'rechazado':
        return Colors.red;
      default:
        return FqColors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FqColors.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: FqColors.listIconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.place_outlined,
                size: 18, color: FqColors.night),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  nodo.nombre,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FqColors.ink,
                  ),
                ),
                Text(
                  nodo.categoria,
                  style: const TextStyle(fontSize: 10, color: FqColors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _colorEstado.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              nodo.estado,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _colorEstado,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
