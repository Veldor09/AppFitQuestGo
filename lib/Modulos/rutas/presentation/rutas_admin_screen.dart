import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/detalle_ruta_admin_screen.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_list_scaffold.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta.dart';
import 'package:fit_quest_go/Modulos/rutas/data/ruta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';

/// ADM-04 · Gestion de rutas publicadas. Consulta `GET /rutas/explorar`.
/// Permite buscar, filtrar y consultar detalles sin acciones de moderacion.
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
  final TextEditingController _busquedaController = TextEditingController();
  String _busqueda = '';
  String? _filtroActividad;
  String? _filtroDificultad;

  @override
  void initState() {
    super.initState();
    _futuro = _api.explorar();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  void _recargar() {
    // Bloque, no expresion: `=> _futuro = x` devuelve el Future asignado,
    // y setState no acepta un callback que devuelva un Future.
    setState(() {
      _futuro = _api.explorar();
    });
  }

  Future<void> _abrirFiltros() async {
    final l10n = AppLocalizations.of(context)!;
    String? actividad = _filtroActividad;
    String? dificultad = _filtroDificultad;

    final resultado = await showDialog<(String?, String?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, actualizar) => AlertDialog(
          title: const Text('Filtros de rutas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<String>(
                initialValue: actividad,
                decoration: const InputDecoration(labelText: 'Actividad'),
                items: <DropdownMenuItem<String>>[
                  for (final opcion in actividadesRuta)
                    DropdownMenuItem<String>(
                      value: opcion.clave,
                      child: Text(actividadLabel(l10n, opcion.clave)),
                    ),
                ],
                onChanged: (valor) => actualizar(() => actividad = valor),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: dificultad,
                decoration: const InputDecoration(labelText: 'Dificultad'),
                items: <DropdownMenuItem<String>>[
                  for (final clave in <String>['facil', 'moderada', 'dificil'])
                    DropdownMenuItem<String>(
                      value: clave,
                      child: Text(dificultadLabel(l10n, clave)),
                    ),
                ],
                onChanged: (valor) => actualizar(() => dificultad = valor),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, (null, null)),
              child: const Text('Limpiar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, (actividad, dificultad)),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || resultado == null) return;
    setState(() {
      _filtroActividad = resultado.$1;
      _filtroDificultad = resultado.$2;
    });
  }

  Future<void> _abrirDetalle(Ruta ruta) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DetalleRutaAdminScreen(ruta: ruta),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<Ruta>>(
      future: _futuro,
      builder: (BuildContext context, AsyncSnapshot<List<Ruta>> snap) {
        final bool cargando = snap.connectionState == ConnectionState.waiting;
        final String? error =
            snap.hasError ? _mensajeError(l10n, snap.error!) : null;
        final String termino = _busqueda.trim().toLowerCase();
        final List<Ruta> rutas = (snap.data ?? const <Ruta>[]).where((ruta) {
          if (_filtroActividad != null &&
              !ruta.actividades.contains(_filtroActividad)) {
            return false;
          }
          if (_filtroDificultad != null &&
              ruta.dificultad != _filtroDificultad) {
            return false;
          }
          if (termino.isEmpty) return true;
          final String actividades = actividadesLabel(l10n, ruta.actividades);
          return ruta.nombre.toLowerCase().contains(termino) ||
              actividades.toLowerCase().contains(termino);
        }).toList();

        return AdminListScaffold(
          searchHint: l10n.rutasAdminSearchHint,
          onFilters: _abrirFiltros,
          searchController: _busquedaController,
          onSearch: (valor) => setState(() => _busqueda = valor),
          child: AdminDataTable(
            loading: cargando,
            error: error,
            onRetry: _recargar,
            emptyTitle: l10n.rutasAdminSinCola,
            emptyMessage: l10n.rutasAdminSinColaMensaje,
            rows: <AdminRow>[
              for (final Ruta ruta in rutas)
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
                  onTap: () => _abrirDetalle(ruta),
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
