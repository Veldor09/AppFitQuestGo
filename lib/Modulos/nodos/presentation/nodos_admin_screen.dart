import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_list_scaffold.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

/// ADM-07 · Gestion de nodos / POIs. Pantalla **funcional**: consume
/// `GET /nodos/pendientes` y aprueba/rechaza via `PATCH /nodos/:id/estado`
/// (ambos protegidos por JWT + rol Admin).
class NodosAdminScreen extends StatefulWidget {
  const NodosAdminScreen({super.key, this.api});

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final NodoApi? api;

  @override
  State<NodosAdminScreen> createState() => _NodosAdminScreenState();
}

class _NodosAdminScreenState extends State<NodosAdminScreen> {
  late final NodoApi _api = widget.api ?? NodoApi();
  late Future<List<Nodo>> _futuro;
  final Set<int> _procesando = <int>{};

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

  Future<void> _decidir(Nodo nodo, String estado) async {
    setState(() => _procesando.add(nodo.id));
    try {
      await _api.cambiarEstado(nodo.id, estado);
      if (!mounted) return;
      notificarExito(
        estado == 'Aprobado' ? '${nodo.nombre} aprobado' : '${nodo.nombre} rechazado',
      );
      _recargar();
    } on ApiException catch (e) {
      notificarError(e.message);
    } catch (_) {
      notificarError('No se pudo completar la accion');
    } finally {
      if (mounted) setState(() => _procesando.remove(nodo.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Nodo>>(
      future: _futuro,
      builder: (BuildContext context, AsyncSnapshot<List<Nodo>> snap) {
        final bool cargando = snap.connectionState == ConnectionState.waiting;
        final String? error = snap.hasError ? _mensajeError(snap.error!) : null;
        final List<Nodo> nodos = snap.data ?? const <Nodo>[];

        return AdminListScaffold(
          searchHint: 'Buscar en nodos / pois',
          child: AdminDataTable(
            loading: cargando,
            error: error,
            onRetry: _recargar,
            emptyTitle: 'Sin puntos propuestos',
            emptyMessage:
                'Los puntos de interes propuestos por la comunidad llegaran aqui.',
            rows: <AdminRow>[
              for (final Nodo nodo in nodos)
                AdminRow(
                  icon: Icons.location_on_outlined,
                  title: nodo.nombre,
                  subtitle: nodo.creadoPorNombre == null
                      ? nodo.categoria
                      : '${nodo.categoria} · propuesto por ${nodo.creadoPorNombre}',
                  trailing: _procesando.contains(nodo.id)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            _accionIcono(
                              icon: Icons.close_rounded,
                              color: FqColors.risk,
                              tooltip: 'Rechazar',
                              onPressed: () => _decidir(nodo, 'Rechazado'),
                            ),
                            _accionIcono(
                              icon: Icons.check_rounded,
                              color: FqColors.trail,
                              tooltip: 'Aprobar',
                              onPressed: () => _decidir(nodo, 'Aprobado'),
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

  Widget _accionIcono({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onPressed,
    );
  }

  String _mensajeError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return 'Tu sesion no tiene permiso para ver esta seccion.';
      }
      return error.message;
    }
    return 'No se pudo conectar con el servidor.';
  }
}
