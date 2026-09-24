import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/core/widgets/fq_tag.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';

/// RTE-01/02/03 · Rutas (vista de usuario).
/// - "Explorar" (RTE-01): rutas publicadas comunitarias (`/rutas/explorar`).
/// - "Mis rutas" (RTE-02): rutas propias (`/rutas/mias`).
/// - "Guardadas" (RTE-03): rutas favoritas / guardadas (`/rutas/favoritas`).
class RutasScreen extends StatefulWidget {
  const RutasScreen({super.key, this.api, this.initialTab = 0});

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final RutaApi? api;

  /// Pestaña inicial (0: Explorar, 1: Mis rutas, 2: Guardadas).
  final int initialTab;

  @override
  State<RutasScreen> createState() => _RutasScreenState();
}

class _RutasScreenState extends State<RutasScreen> {
  late final RutaApi _api = widget.api ?? RutaApi();
  late Future<List<Ruta>> _explorarFuturo;
  late Future<List<Ruta>> _misRutasFuturo;
  late Future<List<Ruta>> _favoritasFuturo;
  Set<int> _favoritasIds = <int>{};
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 2);
    _cargar();
  }

  void _cargar() {
    _explorarFuturo = _api.explorar();
    _misRutasFuturo = _api.misRutas();
    _favoritasFuturo = _api.favoritas();
    _api.favoritasIds().then((Set<int> ids) {
      if (mounted) setState(() => _favoritasIds = ids);
    }).catchError((_) {});
  }

  void _recargar() {
    setState(() {
      _cargar();
    });
  }

  Future<void> _toggleFavorita(int rutaId) async {
    final bool agregada = await _api.toggleFavorita(rutaId);
    if (!mounted) return;
    setState(() {
      if (agregada) {
        _favoritasIds.add(rutaId);
      } else {
        _favoritasIds.remove(rutaId);
      }
      _favoritasFuturo = _api.favoritas();
    });
    notificarExito(
      agregada ? 'Ruta guardada en tus favoritas' : 'Ruta eliminada de tus guardadas',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FqColors.paper,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Rutas',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Segmentado(
                opciones: const <String>['Explorar', 'Mis rutas', 'Guardadas'],
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
    if (_tab == 0) {
      return _ListaRutas(
        key: const ValueKey<String>('explorar'),
        api: _api,
        futuro: _explorarFuturo,
        favoritasIds: _favoritasIds,
        onToggleFavorita: _toggleFavorita,
        onReintentar: _recargar,
        onCambio: _recargar,
        vacioTitulo: 'Sin rutas publicadas',
        vacioMensaje: 'Cuando la comunidad publique rutas, apareceran aqui.',
      );
    }
    if (_tab == 1) {
      return _ListaRutas(
        key: const ValueKey<String>('mias'),
        api: _api,
        futuro: _misRutasFuturo,
        favoritasIds: _favoritasIds,
        onToggleFavorita: _toggleFavorita,
        onReintentar: _recargar,
        onCambio: _recargar,
        mostrarEstado: true,
        vacioTitulo: 'Todavia no tenes rutas',
        vacioMensaje: 'Las rutas que registres o planifiques apareceran aqui.',
      );
    }
    return _ListaRutas(
      key: const ValueKey<String>('guardadas'),
      api: _api,
      futuro: _favoritasFuturo,
      favoritasIds: _favoritasIds,
      onToggleFavorita: _toggleFavorita,
      onReintentar: _recargar,
      onCambio: _recargar,
      vacioTitulo: 'Sin rutas guardadas',
      vacioMensaje: 'Guarda tus rutas favoritas desde el catalogo para verlas aqui.',
    );
  }
}

class _Segmentado extends StatelessWidget {
  const _Segmentado({
    required this.opciones,
    required this.seleccion,
    required this.onSeleccion,
  });

  final List<String> opciones;
  final int seleccion;
  final ValueChanged<int> onSeleccion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: FqColors.cloud,
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
                    color: i == seleccion ? FqColors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: i == seleccion ? FqColors.panelShadow : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    opciones[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: i == seleccion ? FqColors.ink : FqColors.muted,
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
    required this.futuro,
    required this.favoritasIds,
    required this.onToggleFavorita,
    required this.onReintentar,
    required this.onCambio,
    required this.vacioTitulo,
    required this.vacioMensaje,
    this.mostrarEstado = false,
  });

  final RutaApi api;
  final Future<List<Ruta>> futuro;
  final Set<int> favoritasIds;
  final ValueChanged<int> onToggleFavorita;
  final VoidCallback onReintentar;
  final VoidCallback onCambio;
  final bool mostrarEstado;
  final String vacioTitulo;
  final String vacioMensaje;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Ruta>>(
      future: futuro,
      builder: (BuildContext context, AsyncSnapshot<List<Ruta>> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return FqEmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'No se pudo cargar',
            message: _mensajeError(snap.error!),
            action: TextButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          );
        }
        final List<Ruta> rutas = snap.data ?? const <Ruta>[];
        if (rutas.isEmpty) {
          return FqEmptyState(
            icon: Icons.route_outlined,
            title: vacioTitulo,
            message: vacioMensaje,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: rutas.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (BuildContext context, int i) => _TarjetaRuta(
            api: api,
            ruta: rutas[i],
            esFavorita: favoritasIds.contains(rutas[i].id),
            onToggleFavorita: () => onToggleFavorita(rutas[i].id),
            mostrarEstado: mostrarEstado,
            onCambio: onCambio,
          ),
        );
      },
    );
  }

  String _mensajeError(Object error) {
    if (error is ApiException) return error.message;
    return 'No se pudo conectar con el servidor.';
  }
}

class _TarjetaRuta extends StatelessWidget {
  const _TarjetaRuta({
    required this.api,
    required this.ruta,
    required this.esFavorita,
    required this.onToggleFavorita,
    required this.mostrarEstado,
    required this.onCambio,
  });

  final RutaApi api;
  final Ruta ruta;
  final bool esFavorita;
  final VoidCallback onToggleFavorita;
  final bool mostrarEstado;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _mostrarDetalle(context, ruta),
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
                  Text(
                    '${ruta.actividad} · ${ruta.distanciaKm.toStringAsFixed(1)} km · ${ruta.dificultad}',
                    style: const TextStyle(fontSize: 10, color: FqColors.muted),
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
              tooltip: esFavorita ? 'Quitar de guardadas' : 'Guardar ruta',
              splashRadius: 18,
              onPressed: onToggleFavorita,
            ),
            if (mostrarEstado) ...<Widget>[
              const SizedBox(width: 4),
              FqTag(ruta.estado, tone: _tonoEstado(ruta.estado)),
            ],
          ],
        ),
      ),
    );
  }

  FqTagTone _tonoEstado(String estado) {
    switch (estado) {
      case 'Publicada':
        return FqTagTone.green;
      case 'Pendiente':
        return FqTagTone.amber;
      case 'Rechazada':
        return FqTagTone.red;
      default:
        return FqTagTone.neutral;
    }
  }

  void _mostrarDetalle(BuildContext context, Ruta ruta) {
    final bool puedePublicar = mostrarEstado && ruta.estado == 'Privada';
    bool enviando = false;
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  ruta.nombre,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                FqTag(ruta.estado, tone: _tonoEstado(ruta.estado)),
                const SizedBox(height: 14),
                _fila('Actividad', ruta.actividad),
                _fila('Dificultad', ruta.dificultad),
                _fila('Distancia', '${ruta.distanciaKm.toStringAsFixed(1)} km'),
                _fila('Puntos del trazo', '${ruta.puntos.length}'),
                if (ruta.creadoPorNombre != null)
                  _fila('Propuesta por', ruta.creadoPorNombre!),
                if (puedePublicar) ...<Widget>[
                  const SizedBox(height: 16),
                  FqButton.primary(
                    label: enviando ? 'Enviando...' : 'Enviar a revision',
                    dense: true,
                    onPressed: enviando
                        ? null
                        : () async {
                            setSheetState(() => enviando = true);
                            try {
                              await api.solicitarPublicacion(ruta.id);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              onCambio();
                              notificarExito('Ruta enviada a revision');
                            } catch (_) {
                              setSheetState(() => enviando = false);
                              if (ctx.mounted) {
                                notificarError('No se pudo enviar la ruta');
                              }
                            }
                          },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _fila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 11, color: FqColors.muted)),
          Text(
            valor,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
