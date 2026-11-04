import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/catalogos/categorias_nodo.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_list_scaffold.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_detail_dialog.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/nodos/presentation/ficha_nodo.dart';

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
  String _busqueda = '';
  int _filtroEstado = 0;

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

  Future<void> _decidir(AppLocalizations l10n, Nodo nodo, String estado) async {
    setState(() => _procesando.add(nodo.id));
    try {
      await _api.cambiarEstado(nodo.id, estado);
      if (!mounted) return;
      notificarExito(
        estado == 'Aprobado'
            ? l10n.nodosAprobadoExito(nodo.nombre)
            : l10n.nodosRechazadoExito(nodo.nombre),
      );
      _recargar();
    } on ApiException catch (e) {
      notificarError(e.message);
    } catch (_) {
      notificarError(l10n.usuariosAccionFallida);
    } finally {
      if (mounted) setState(() => _procesando.remove(nodo.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<Nodo>>(
      future: _futuro,
      builder: (BuildContext context, AsyncSnapshot<List<Nodo>> snap) {
        final bool cargando = snap.connectionState == ConnectionState.waiting;
        final String? error = snap.hasError
            ? _mensajeError(l10n, snap.error!)
            : null;
        final List<Nodo> nodos = snap.data ?? const <Nodo>[];
        final List<Nodo> visibles = nodos.where((nodo) {
          if (_filtroEstado == 1 && nodo.estado != 'Pendiente') return false;
          if (_filtroEstado == 2 && nodo.estado != 'Aprobado') return false;
          if (_filtroEstado == 3 &&
              nodo.estado != 'Rechazado' &&
              nodo.estado != 'Obsoleto') {
            return false;
          }
          final categoria = categoriaNodoLabel(
            l10n,
            nodo.categoria,
            otro: nodo.categoriaOtro,
          );
          return '${nodo.nombre} $categoria ${nodo.creadoPorNombre ?? ''} ${nodo.estado} ${nodo.descripcion ?? ''}'
              .toLowerCase()
              .contains(_busqueda);
        }).toList();

        return AdminListScaffold(
          searchHint: l10n.nodosSearchHint,
          onSearch: (value) =>
              setState(() => _busqueda = value.trim().toLowerCase()),
          tabs: const <String>[
            'Todos',
            'Pendientes',
            'Aprobados',
            'Desactivados',
          ],
          tabIndex: _filtroEstado,
          onTab: (indice) => setState(() => _filtroEstado = indice),
          child: AdminDataTable(
            loading: cargando,
            error: error,
            onRetry: _recargar,
            emptyTitle: nodos.isEmpty ? 'Sin nodos' : 'Sin resultados',
            emptyMessage: nodos.isEmpty
                ? 'Todavía no hay nodos registrados.'
                : 'No hay nodos que coincidan con la búsqueda o el filtro.',
            rows: <AdminRow>[
              for (final Nodo nodo in visibles)
                AdminRow(
                  icon: Icons.location_on_outlined,
                  title: nodo.nombre,
                  subtitle:
                      '${nodo.estado} · ${nodo.creadoPorNombre == null ? categoriaNodoLabel(l10n, nodo.categoria, otro: nodo.categoriaOtro) : l10n.nodosPropuestoPor(categoriaNodoLabel(l10n, nodo.categoria, otro: nodo.categoriaOtro), nodo.creadoPorNombre!)}',
                  // La ficha muestra la foto: lo que el admin necesita para decidir.
                  onTap: () => mostrarDetalleAdmin(
                    context,
                    titulo: nodo.nombre,
                    icono: Icons.location_on_outlined,
                    estado: nodo.estado,
                    campos: <String, String>{
                      'Nombre': nodo.nombre,
                      'Categoría': categoriaNodoLabel(
                        l10n,
                        nodo.categoria,
                        otro: nodo.categoriaOtro,
                      ),
                      'Creado por': nodo.creadoPorNombre ?? '—',
                      'Descripción': nodo.descripcion ?? '—',
                      'Beneficio': nodo.beneficio ?? '—',
                      'Ubicación':
                          '${nodo.lat.toStringAsFixed(5)}, ${nodo.lng.toStringAsFixed(5)}',
                      'Estado': nodo.estado,
                    },
                  ),
                  trailing: _procesando.contains(nodo.id)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : PopupMenuButton<String>(
                          tooltip: 'Acciones',
                          onSelected: (accion) {
                            if (accion == 'foto') {
                              mostrarFichaNodo(context, nodo, _api);
                            }
                            if (accion == 'aprobar') {
                              _decidir(l10n, nodo, 'Aprobado');
                            }
                            if (accion == 'desactivar') {
                              _decidir(l10n, nodo, 'Rechazado');
                            }
                          },
                          itemBuilder: (_) => <PopupMenuEntry<String>>[
                            const PopupMenuItem(
                              value: 'foto',
                              child: Text('Ver foto'),
                            ),
                            if (nodo.estado == 'Pendiente')
                              const PopupMenuItem(
                                value: 'aprobar',
                                child: Text('Aprobar'),
                              ),
                            if (nodo.estado == 'Pendiente' ||
                                nodo.estado == 'Aprobado')
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
