import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_list_scaffold.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';

/// ADM-06 · Gestion de alertas. Pantalla **funcional**: consume `GET /alertas`
/// (mismas alertas vigentes que ve el mapa, no hay cola de moderacion previa
/// porque una alerta se publica de inmediato) y permite marcarla resuelta o
/// eliminarla (`PATCH .../estado`, `DELETE`), ambos protegidos por rol Admin.
class AlertasAdminScreen extends StatefulWidget {
  const AlertasAdminScreen({super.key, this.api});

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final AlertaApi? api;

  @override
  State<AlertasAdminScreen> createState() => _AlertasAdminScreenState();
}

class _AlertasAdminScreenState extends State<AlertasAdminScreen> {
  late final AlertaApi _api = widget.api ?? AlertaApi();
  late Future<List<Alerta>> _futuro;
  final Set<int> _procesando = <int>{};

  @override
  void initState() {
    super.initState();
    _futuro = _api.listar();
  }

  void _recargar() {
    // Bloque, no expresion: `=> _futuro = x` devuelve el Future asignado,
    // y setState no acepta un callback que devuelva un Future.
    setState(() {
      _futuro = _api.listar();
    });
  }

  Future<void> _resolver(Alerta alerta) async {
    setState(() => _procesando.add(alerta.id));
    try {
      await _api.cambiarEstado(alerta.id, 'Resuelta');
      if (!mounted) return;
      notificarExito('${alerta.tipo} marcada como resuelta');
      _recargar();
    } catch (_) {
      if (mounted) notificarError('No se pudo completar la accion');
    } finally {
      if (mounted) setState(() => _procesando.remove(alerta.id));
    }
  }

  Future<void> _eliminar(Alerta alerta) async {
    setState(() => _procesando.add(alerta.id));
    try {
      await _api.eliminar(alerta.id);
      if (!mounted) return;
      notificarExito('${alerta.tipo} eliminada');
      _recargar();
    } catch (_) {
      if (mounted) notificarError('No se pudo completar la accion');
    } finally {
      if (mounted) setState(() => _procesando.remove(alerta.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Alerta>>(
      future: _futuro,
      builder: (BuildContext context, AsyncSnapshot<List<Alerta>> snap) {
        final bool cargando = snap.connectionState == ConnectionState.waiting;
        final String? error = snap.hasError ? _mensajeError(snap.error!) : null;
        final List<Alerta> alertas = snap.data ?? const <Alerta>[];

        return AdminListScaffold(
          searchHint: 'Buscar en alertas activas',
          child: AdminDataTable(
            loading: cargando,
            error: error,
            onRetry: _recargar,
            emptyTitle: 'Sin alertas activas',
            emptyMessage:
                'Los reportes comunitarios en vivo se listaran aqui en tiempo real.',
            rows: <AdminRow>[
              for (final Alerta alerta in alertas)
                AdminRow(
                  icon: _iconoPorGravedad(alerta.gravedad),
                  title: alerta.tipo,
                  subtitle: alerta.creadoPorNombre == null
                      ? 'Gravedad ${alerta.gravedad}'
                      : 'Gravedad ${alerta.gravedad} · reportada por ${alerta.creadoPorNombre}',
                  // Menu con texto en vez de check/X: esta pantalla no aprueba
                  // ni rechaza (la alerta ya esta publicada), asi que un par
                  // de iconos check+X se lee como "aprobar/rechazar" por el
                  // mismo patron visual que usan Nodos y Rutas. Con texto no
                  // hay ambiguedad posible.
                  trailing: _procesando.contains(alerta.id)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : PopupMenuButton<String>(
                          tooltip: 'Acciones',
                          onSelected: (String accion) {
                            if (accion == 'resolver') {
                              _resolver(alerta);
                            } else {
                              _eliminar(alerta);
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                              const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'resolver',
                              child: Text('Marcar resuelta'),
                            ),
                            PopupMenuItem<String>(
                              value: 'eliminar',
                              child: Text(
                                'Eliminar',
                                style: TextStyle(color: FqColors.risk),
                              ),
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

  IconData _iconoPorGravedad(String gravedad) {
    switch (gravedad) {
      case 'alta':
        return Icons.report_rounded;
      case 'media':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
    }
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
