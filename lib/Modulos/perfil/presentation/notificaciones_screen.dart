import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificacion.dart';
import 'package:fit_quest_go/Modulos/perfil/data/notificaciones_api.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/aportes_screen.dart';
import 'package:fit_quest_go/Modulos/perfil/presentation/insignias_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/rutas_screen.dart';

/// NOT-01: Centro de notificaciones.
/// Muestra el buzón del usuario autenticado, consumido desde el backend.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key, this.api});

  final NotificacionesApi? api;

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  late final NotificacionesApi _api = widget.api ?? NotificacionesApi();
  List<Notificacion>? _items;
  String? _error;
  String _filtro = 'todas';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final List<Notificacion> datos = await _api.listar();
      if (!mounted) return;
      setState(() {
        _items = datos;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'No se pudieron cargar tus notificaciones.';
      });
    }
  }

  List<Notificacion> get _itemsFiltrados {
    final List<Notificacion> todos = _items ?? <Notificacion>[];
    if (_filtro == 'todas') return todos;
    return todos.where((Notificacion n) => n.categoria == _filtro).toList();
  }

  int _contar(String categoria) => (_items ?? <Notificacion>[])
      .where((Notificacion n) => n.categoria == categoria)
      .length;

  Future<void> _marcarTodasLeidas() async {
    final List<Notificacion> pendientes =
        (_items ?? <Notificacion>[]).where((Notificacion n) => !n.leida).toList();
    setState(() {
      for (final Notificacion n in pendientes) {
        n.leida = true;
      }
    });
    try {
      await _api.marcarTodasLeidas();
      notificarInfo('Todas las notificaciones marcadas como leídas');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        for (final Notificacion n in pendientes) {
          n.leida = false;
        }
      });
      notificarError('No se pudieron marcar como leídas');
    }
  }

  Future<void> _abrir(Notificacion n) async {
    if (!n.leida) {
      setState(() => n.leida = true);
      try {
        await _api.marcarLeida(n.id);
      } catch (_) {
        if (mounted) setState(() => n.leida = false);
      }
    }
    if (!mounted) return;
    final Widget? destino = _destino(n);
    if (destino != null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => destino),
      );
    }
  }

  Widget? _destino(Notificacion n) {
    switch (n.referenciaTipo ?? n.categoria) {
      case 'ruta':
      case 'rutas':
        return const RutasScreen(initialTab: 1, showBackButton: true);
      case 'insignia':
      case 'insignias':
        return const InsigniasScreen();
      case 'alerta':
      case 'alertas':
        return const AportesScreen();
    }
    return null;
  }

  Future<void> _eliminar(Notificacion n) async {
    final List<Notificacion> lista = _items!;
    final int indice = lista.indexOf(n);
    setState(() => lista.remove(n));
    try {
      await _api.eliminar(n.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => lista.insert(indice.clamp(0, lista.length), n));
      notificarError('No se pudo eliminar la notificación');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.of(context).padding.top;
    final List<Notificacion> lista = _itemsFiltrados;
    final int noLeidas =
        (_items ?? <Notificacion>[]).where((Notificacion n) => !n.leida).length;

    return Scaffold(
      backgroundColor: FqColors.paper,
      body: Column(
        children: <Widget>[
          // ── Cabecera ──────────────────────────────────────────────────────
          Container(
            color: FqColors.night,
            padding: EdgeInsets.fromLTRB(4, top + 4, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: FqColors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Centro de notificaciones',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: FqColors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (noLeidas > 0)
                      TextButton.icon(
                        onPressed: _marcarTodasLeidas,
                        icon: const Icon(Icons.done_all_rounded, size: 16, color: FqColors.volt),
                        label: const Text(
                          'Leídas',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: FqColors.volt,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        _FiltroPill(
                          label: 'Todas',
                          activo: _filtro == 'todas',
                          contador: _items?.length ?? 0,
                          onTap: () => setState(() => _filtro = 'todas'),
                        ),
                        for (final MapEntry<String, String> c in const <String, String>{
                          'rutas': 'Rutas',
                          'alertas': 'Alertas',
                          'insignias': 'Insignias',
                          'eventos': 'Eventos',
                        }.entries) ...<Widget>[
                          const SizedBox(width: 8),
                          _FiltroPill(
                            label: c.value,
                            activo: _filtro == c.key,
                            contador: _contar(c.key),
                            onTap: () => setState(() => _filtro = c.key),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Lista de notificaciones o estado vacío ─────────────────────────
          Expanded(child: _cuerpo(lista)),
        ],
      ),
    );
  }

  Widget _cuerpo(List<Notificacion> lista) {
    if (_items == null && _error == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_items == null) {
      return FqEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'No se pudieron cargar las notificaciones',
        message: _error!,
        action: TextButton(
          onPressed: () {
            setState(() => _error = null);
            _cargar();
          },
          child: const Text('Reintentar'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: lista.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                SizedBox(
                  height: 360,
                  child: FqEmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'No hay notificaciones',
                    message: _filtro == 'todas'
                        ? 'Estás al día. Te avisaremos cuando ocurra algo importante.'
                        : 'No tienes notificaciones en esta categoría.',
                    action: _filtro != 'todas'
                        ? TextButton(
                            onPressed: () => setState(() => _filtro = 'todas'),
                            child: const Text('Ver todas las notificaciones'),
                          )
                        : null,
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              itemCount: lista.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final Notificacion item = lista[index];
                return Dismissible(
                  key: ValueKey<int>(item.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _eliminar(item),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: FqColors.risk,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: FqColors.white),
                  ),
                  child: _NotificacionCard(item: item, onTap: () => _abrir(item)),
                );
              },
            ),
    );
  }
}

class _EstiloCategoria {
  const _EstiloCategoria(this.icono, this.color, this.fondo, this.accion);
  final IconData icono;
  final Color color;
  final Color fondo;
  final String? accion;
}

_EstiloCategoria _estiloDe(Notificacion n) {
  switch (n.categoria) {
    case 'rutas':
      return const _EstiloCategoria(
        Icons.route_rounded,
        Color(0xFF057A71),
        Color(0xFFE6F5F2),
        'Ver mis rutas',
      );
    case 'alertas':
      return const _EstiloCategoria(
        Icons.warning_amber_rounded,
        FqColors.risk,
        Color(0xFFFEECE9),
        'Ver mis aportes',
      );
    case 'insignias':
      return const _EstiloCategoria(
        Icons.military_tech_rounded,
        Color(0xFFB45309),
        Color(0xFFFEF3C7),
        'Ver insignias',
      );
    default:
      return const _EstiloCategoria(
        Icons.event_available_rounded,
        FqColors.river,
        Color(0xFFEBF5FF),
        null,
      );
  }
}

class _FiltroPill extends StatelessWidget {
  const _FiltroPill({
    required this.label,
    required this.activo,
    required this.contador,
    required this.onTap,
  });

  final String label;
  final bool activo;
  final int contador;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? FqColors.volt : const Color(0x28FFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? FqColors.voltDark : const Color(0x3DFFFFFF),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
                color: activo ? FqColors.night : FqColors.white,
              ),
            ),
            if (contador > 0) ...<Widget>[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: activo ? FqColors.night : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$contador',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: activo ? FqColors.volt : FqColors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificacionCard extends StatelessWidget {
  const _NotificacionCard({
    required this.item,
    required this.onTap,
  });

  final Notificacion item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final _EstiloCategoria estilo = _estiloDe(item);
    return Material(
      color: item.leida ? FqColors.white : const Color(0xFFF9FDF7),
      borderRadius: BorderRadius.circular(16),
      elevation: item.leida ? 0 : 2,
      shadowColor: const Color(0x1A000000),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.leida ? FqColors.border : FqColors.voltDark,
              width: item.leida ? 1 : 1.4,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: estilo.fondo,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(estilo.icono, size: 20, color: estilo.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.titulo,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: item.leida ? FontWeight.w700 : FontWeight.w800,
                              color: FqColors.ink,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (!item.leida) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: FqColors.voltDark,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.mensaje,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: FqColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          item.tiempoRelativo(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        if (estilo.accion != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                estilo.accion!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 14,
                                color: Color(0xFF0F766E),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
