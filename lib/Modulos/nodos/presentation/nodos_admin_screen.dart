import 'dart:async';

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

/// ADM-07 · Gestion de nodos / POIs.
/// Consulta todos los nodos mediante GET /nodos/admin.
/// Permite filtrar, buscar, aprobar y rechazar nodos.
/// Los endpoints administrativos estan protegidos por JWT y rol Admin.
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

  static const List<String> _estados = <String>[
    'Todos',
    'Pendiente',
    'Aprobado',
    'Rechazado',
    'Obsoleto',
  ];

  int _indiceEstado = 0;
  String _busqueda = '';

  static const Duration _intervaloActualizacion = Duration(seconds: 5);

  Timer? _temporizador;
  bool _consultando = false;
  List<Nodo>? _nodosActuales;

  @override
  void initState() {
    super.initState();

    _futuro = _cargarInicial();

    _temporizador = Timer.periodic(_intervaloActualizacion, (_) {
      if (mounted && !_consultando && _procesando.isEmpty) {
        _actualizarSilenciosamente();
      }
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  Future<List<Nodo>> _cargarInicial() async {
    _consultando = true;

    try {
      final List<Nodo> nodos = await _api.listarTodosAdmin();
      _nodosActuales = nodos;
      return nodos;
    } finally {
      _consultando = false;
    }
  }

  void _recargar() {
    if (_consultando) return;

    if (_nodosActuales == null) {
      setState(() {
        _futuro = _cargarInicial();
      });
      return;
    }

    _actualizarSilenciosamente();
  }

  Future<void> _actualizarSilenciosamente() async {
    if (_consultando || !mounted) return;

    _consultando = true;

    try {
      final List<Nodo> nodos = await _api.listarTodosAdmin();

      if (!mounted) return;

      setState(() {
        _nodosActuales = nodos;
      });
    } on ApiException catch (e) {
      if (mounted) {
        debugPrint('ADM-07: error al actualizar nodos: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('ADM-07: error de conexion al actualizar nodos: $e');
      }
    } finally {
      _consultando = false;
    }
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
      if (mounted) {
        setState(() => _procesando.remove(nodo.id));
      }
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

        final List<Nodo> todos = _nodosActuales ?? snap.data ?? const <Nodo>[];

        final String texto = _busqueda.trim().toLowerCase();

        final List<Nodo> nodos = todos.where((Nodo nodo) {
          if (_indiceEstado != 0 && nodo.estado != _estados[_indiceEstado]) {
            return false;
          }

          if (texto.isEmpty) return true;

          final String categoria = categoriaNodoLabel(
            l10n,
            nodo.categoria,
            otro: nodo.categoriaOtro,
          );

          return nodo.nombre.toLowerCase().contains(texto) ||
              categoria.toLowerCase().contains(texto) ||
              nodo.categoria.toLowerCase().contains(texto) ||
              (nodo.creadoPorNombre ?? '').toLowerCase().contains(texto);
        }).toList();

        return AdminListScaffold(
          searchHint: l10n.nodosSearchHint,

          onSearch: (String valor) {
            setState(() {
              _busqueda = valor;
            });
          },

          tabs: <String>[
            l10n.usuariosFiltroTodos,
            l10n.admTabPendientes,
            l10n.admNodosTabAprobados,
            l10n.admTabRechazados,
            l10n.admNodosTabObsoletos,
          ],

          tabIndex: _indiceEstado,

          onTab: (int indice) {
            setState(() {
              _indiceEstado = indice;
            });
          },

          child: AdminDataTable(
            loading: cargando,
            error: error,
            onRetry: _recargar,

            emptyTitle: texto.isNotEmpty
                ? l10n.nodosBusquedaSinResultados
                : l10n.nodosSinPropuestos,

            emptyMessage: texto.isNotEmpty
                ? ''
                : l10n.nodosSinPropuestosMensaje,

            rows: <AdminRow>[
              for (final Nodo nodo in nodos)
                AdminRow(
                  icon: Icons.location_on_outlined,
                  title: nodo.nombre,

                  subtitle:
                      '${nodo.creadoPorNombre == null ? categoriaNodoLabel(l10n, nodo.categoria, otro: nodo.categoriaOtro) : l10n.nodosPropuestoPor(categoriaNodoLabel(l10n, nodo.categoria, otro: nodo.categoriaOtro), nodo.creadoPorNombre!)} | ${nodo.estado}',

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
                              PopupMenuItem(
                                value: 'aprobar',
                                child: Text(l10n.comunAprobar),
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
