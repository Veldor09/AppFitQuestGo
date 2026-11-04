import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/revision_ruta_screen.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_list_scaffold.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_detail_dialog.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';

/// ADM-04 · Gestion de rutas. Pantalla **funcional**: consume
/// `GET /rutas/pendientes` (JWT + rol Admin). Tocar una fila abre ADM-05
/// (Revision de ruta) con esa ruta cargada.
class RutasAdminScreen extends StatefulWidget {
  const RutasAdminScreen({super.key, this.api});

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final RutaApi? api;

  @override
  State<RutasAdminScreen> createState() => _RutasAdminScreenState();
}

class _RutasAdminScreenState extends State<RutasAdminScreen> {
  late final RutaApi _api = widget.api ?? RutaApi();
  late Future<List<Ruta>> _futuro;
  String _busqueda = '';
  final Set<int> _procesando = <int>{};

  @override
  void initState() {
    super.initState();
    _futuro = _api.listarAdmin();
  }

  void _recargar() {
    // Bloque, no expresion: `=> _futuro = x` devuelve el Future asignado,
    // y setState no acepta un callback que devuelva un Future.
    setState(() {
      _futuro = _api.listarAdmin();
    });
  }

  Future<void> _abrirRevision(Ruta ruta) async {
    final bool? decidida = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(ruta.nombre)),
          body: RevisionRutaScreen(ruta: ruta, api: _api),
        ),
      ),
    );
    if (decidida == true) _recargar();
  }

  Future<void> _desactivar(Ruta ruta) async {
    setState(() => _procesando.add(ruta.id));
    try {
      await _api.cambiarEstado(ruta.id, 'Rechazada');
      if (mounted) _recargar();
    } catch (_) {
      if (mounted) notificarError('No se pudo desactivar la ruta');
    } finally {
      if (mounted) setState(() => _procesando.remove(ruta.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<Ruta>>(
      future: _futuro,
      builder: (BuildContext context, AsyncSnapshot<List<Ruta>> snap) {
        final bool cargando = snap.connectionState == ConnectionState.waiting;
        final String? error = snap.hasError
            ? _mensajeError(l10n, snap.error!)
            : null;
        final List<Ruta> rutas = snap.data ?? const <Ruta>[];

        return AdminListScaffold(
          searchHint: l10n.rutasAdminSearchHint,
          onSearch: (value) =>
              setState(() => _busqueda = value.trim().toLowerCase()),
          child: AdminDataTable(
            loading: cargando,
            error: error,
            onRetry: _recargar,
            emptyTitle: l10n.rutasAdminSinCola,
            emptyMessage: l10n.rutasAdminSinColaMensaje,
            rows: <AdminRow>[
              for (final Ruta ruta in rutas)
                if ('${ruta.nombre} ${ruta.creadoPorNombre ?? ''} ${ruta.estado} ${ruta.actividades.join(' ')}'
                    .toLowerCase()
                    .contains(_busqueda))
                  AdminRow(
                    icon: Icons.route_outlined,
                    title: ruta.nombre,
                    subtitle: ruta.creadoPorNombre == null
                        ? '${actividadesLabel(l10n, ruta.actividades)} · ${ruta.distanciaKm.toStringAsFixed(1)} km'
                        : l10n.rutasAdminSubtituloPropuesta(
                            actividadesLabel(l10n, ruta.actividades),
                            ruta.distanciaKm.toStringAsFixed(1),
                            ruta.creadoPorNombre!,
                          ),
                    onTap: () => mostrarDetalleAdmin(
                      context,
                      titulo: ruta.nombre,
                      icono: Icons.route_outlined,
                      estado: ruta.estado,
                      campos: <String, String>{
                        'Nombre': ruta.nombre,
                        'Actividades': actividadesLabel(l10n, ruta.actividades),
                        'Dificultad': ruta.dificultad,
                        'Distancia':
                            '${ruta.distanciaKm.toStringAsFixed(1)} km',
                        'Creada por': ruta.creadoPorNombre ?? '—',
                        'Puntos': '${ruta.puntos.length}',
                        'Estado': ruta.estado,
                      },
                    ),
                    trailing: _procesando.contains(ruta.id)
                        ? const CircularProgressIndicator()
                        : PopupMenuButton<String>(
                            tooltip: 'Acciones',
                            onSelected: (accion) {
                              if (accion == 'revision') _abrirRevision(ruta);
                              if (accion == 'desactivar') _desactivar(ruta);
                            },
                            itemBuilder: (_) => <PopupMenuEntry<String>>[
                              if (ruta.estado == 'Pendiente')
                                const PopupMenuItem(
                                  value: 'revision',
                                  child: Text('Revisar'),
                                ),
                              if (ruta.estado == 'Publicada' ||
                                  ruta.estado == 'Pendiente')
                                const PopupMenuItem(
                                  value: 'desactivar',
                                  child: Text('Desactivar'),
                                ),
                            ],
                          ),
                  ),
            ],
          ),
        );
      },
    );
  }

  String _mensajeError(AppLocalizations l10n, Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return l10n.admSinPermisoSeccion;
      }
      return error.message;
    }
    return l10n.rutasErrorConexionGenerico;
  }
}
