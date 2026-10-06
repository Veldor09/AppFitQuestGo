import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/screens/revision_ruta_screen.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_list_scaffold.dart';
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

  @override
  void initState() {
    super.initState();
    _futuro = _api.listarPendientes();
  }

  void _recargar() {
    // Bloque, no expresion: `=> _futuro = x` devuelve el Future asignado,
    // y setState no acepta un callback que devuelva un Future.
    setState(() {
      _futuro = _api.listarPendientes();
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<Ruta>>(
      future: _futuro,
      builder: (BuildContext context, AsyncSnapshot<List<Ruta>> snap) {
        final bool cargando = snap.connectionState == ConnectionState.waiting;
        final String? error =
            snap.hasError ? _mensajeError(l10n, snap.error!) : null;
        final List<Ruta> rutas = snap.data ?? const <Ruta>[];

        return AdminListScaffold(
          searchHint: l10n.rutasAdminSearchHint,
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
                  onTap: () => _abrirRevision(ruta),
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
