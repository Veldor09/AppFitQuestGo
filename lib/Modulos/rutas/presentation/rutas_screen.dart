import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/ruta_detalle_screen.dart';
import 'package:fit_quest_go/Modulos/rutas/presentation/widgets/etiqueta_estado_ruta.dart';

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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Segmentado(
                opciones: <String>[l10n.rutasExplorar, l10n.rutasMisRutas, 'Guardadas'],
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<Ruta>>(
      future: futuro,
      builder: (BuildContext context, AsyncSnapshot<List<Ruta>> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return FqEmptyState(
            icon: Icons.wifi_off_rounded,
            title: l10n.rutasNoSePudoCargar,
            message: _mensajeError(l10n, snap.error!),
            action: TextButton(
              onPressed: onReintentar,
              child: Text(l10n.rutasReintentar),
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

  String _mensajeError(AppLocalizations l10n, Object error) {
    if (error is ApiException) return error.message;
    return l10n.rutasErrorConexionGenerico;
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
                  Text(
                    '${actividadesLabel(l10n, ruta.actividades)} · ${ruta.distanciaKm.toStringAsFixed(1)} km · '
                    '${dificultadLabel(l10n, ruta.dificultad)}',
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
              const SizedBox(width: 8),
              EtiquetaEstadoRuta(ruta.estado),
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
          onCambio: onCambio,
        ),
      ),
    );
  }
}
