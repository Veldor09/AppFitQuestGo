
import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/catalogos/categorias_evento.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_list_scaffold.dart';

/// ADM-08: gestión administrativa de eventos.
///
/// Los eventos no requieren aprobación previa.
/// El administrador puede consultar todos los eventos y eliminarlos.
class EventosAdminScreen extends StatefulWidget {
  const EventosAdminScreen({super.key, this.api});

  /// Permite inyectar una API simulada durante las pruebas.
  final ApiClient? api;

  @override
  State<EventosAdminScreen> createState() => _EventosAdminScreenState();
}

class _EventosAdminScreenState extends State<EventosAdminScreen> {
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  late final ApiClient _api;
  late final bool _cerrarApi;

  final TextEditingController _busquedaController = TextEditingController();

  List<Map<String, dynamic>> _eventos = [];
  bool _cargando = true;
  bool _eliminando = false;
  String? _error;
  String _busqueda = '';
  int _filtro = 0;

  String? _categoriaFiltro;
  String? _organizadorFiltro;
  DateTimeRange? _rangoInicio;
  DateTimeRange? _rangoFin;
  String _areasFiltro = 'todos';
  String _recorridosFiltro = 'todos';

  static const Color _colorTexto = Color(0xFF374151);
  static const Color _colorBorde = Color(0xFF9CA3AF);
  static const Color _colorRojo = Color(0xFFB42318);
  static const Color _colorVerde = Color(0xFFB5E61D);
  static const Color _colorCrema = Color(0xFFFFFCF3);

  List<String> get _filtros => [
    _l10n.usuariosFiltroTodos,
    _l10n.admEvtFiltroProximos,
    _l10n.eventoEstadoEnCurso,
    _l10n.admEvtFiltroFinalizados,
  ];

  static const List<String> _categorias = [
    'benefico',
    'caminata',
    'carrera',
    'ciclismo',
    'senderismo',
    'otro',
  ];

  static const List<String> _opcionesPresencia = ['todos', 'con', 'sin'];

  String _nombrePresencia(String clave) => switch (clave) {
    'con' => _l10n.admEvtPresCon,
    'sin' => _l10n.admEvtPresSin,
    _ => _l10n.usuariosFiltroTodos,
  };

  /// El estado se calcula en español (es la clave interna); se muestra traducido.
  String _nombreEstado(String estado) => switch (estado) {
    'Próximo' => _l10n.admEvtEstadoProximo,
    'En curso' => _l10n.eventoEstadoEnCurso,
    'Finalizado' => _l10n.admEvtEstadoFinalizado,
    'Sin fechas' => _l10n.admEvtSinFechas,
    _ => estado,
  };

  @override
  void initState() {
    super.initState();

    _cerrarApi = widget.api == null;
    _api = widget.api ?? ApiClient();

    _cargarEventos();
  }

  @override
  void dispose() {
    _busquedaController.dispose();

    if (_cerrarApi) {
      _api.close();
    }

    super.dispose();
  }

  Future<void> _cargarEventos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final dynamic respuesta = await _api.get('/eventos/admin/todos');

      if (respuesta is! List) {
        throw FormatException(_l10n.admEvtFormatoInesperado);
      }

      final eventos = respuesta.map((dynamic item) {
        return Map<String, dynamic>.from(item as Map);
      }).toList();

      if (!mounted) return;

      setState(() {
        _eventos = eventos;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = _mensajeError(error);
        _cargando = false;
      });
    }
  }

  String _mensajeError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) {
        return _l10n.admEvtSesionExpiro;
      }

      if (error.statusCode == 403) {
        return _l10n.admEvtSinPermisos;
      }

      return error.message;
    }

    if (error is FormatException) {
      return error.message;
    }

    return _l10n.admEvtErrorCarga;
  }

  DateTime? _fecha(dynamic valor) {
    if (valor == null) return null;

    return DateTime.tryParse(valor.toString())?.toLocal();
  }

  String _formatearFecha(dynamic valor) {
    final fecha = _fecha(valor);

    if (fecha == null) return _l10n.admEvtSinFecha;

    String dos(int numero) => numero.toString().padLeft(2, '0');

    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
        '${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  String _formatearDia(DateTime fecha) {
    String dos(int numero) => numero.toString().padLeft(2, '0');

    return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year}';
  }

  String _estado(Map<String, dynamic> evento) {
    final inicio = _fecha(evento['fechaInicio']);
    final fin = _fecha(evento['fechaFin']);

    if (inicio == null || fin == null) {
      return 'Sin fechas';
    }

    final ahora = DateTime.now();

    if (ahora.isBefore(inicio)) {
      return 'Próximo';
    }

    if (!ahora.isBefore(fin)) {
      return 'Finalizado';
    }

    return 'En curso';
  }

  String _empresa(Map<String, dynamic> evento) {
    final creador = evento['creadoPor'];

    if (creador is Map) {
      final datos = Map<String, dynamic>.from(creador);

      for (final campo in [
        'nombreEmpresa',
        'nombreComercial',
        'nombre',
        'username',
        'email',
      ]) {
        final valor = datos[campo]?.toString().trim();

        if (valor != null && valor.isNotEmpty) {
          return valor;
        }
      }

      final id = datos['id'];

      if (id != null) {
        return _l10n.admEvtUsuarioN('$id');
      }
    }

    return _l10n.admEvtNoDisponible;
  }

  String _claveOrganizador(Map<String, dynamic> evento) {
    final creador = evento['creadoPor'];

    if (creador is Map) {
      final datos = Map<String, dynamic>.from(creador);
      final id = datos['id'];

      if (id != null) return 'id:$id';
    }

    return 'nombre:${_empresa(evento)}';
  }

  Map<String, String> get _organizadores {
    final resultado = <String, String>{};

    for (final evento in _eventos) {
      resultado[_claveOrganizador(evento)] = _empresa(evento);
    }

    return resultado;
  }

  bool _enRango(dynamic valor, DateTimeRange? rango) {
    if (rango == null) return true;

    final fecha = _fecha(valor);
    if (fecha == null) return false;

    final dia = DateUtils.dateOnly(fecha);

    return !dia.isBefore(DateUtils.dateOnly(rango.start)) &&
        !dia.isAfter(DateUtils.dateOnly(rango.end));
  }

  bool _cumplePresencia(dynamic valor, String filtro) {
    if (filtro == 'todos') return true;

    final tieneElementos = valor is List && valor.isNotEmpty;

    if (filtro == 'con') return tieneElementos;
    if (filtro == 'sin') return !tieneElementos;

    return true;
  }

  int get _cantidadFiltrosActivos {
    var cantidad = 0;

    if (_categoriaFiltro != null) cantidad++;
    if (_organizadorFiltro != null) cantidad++;
    if (_rangoInicio != null) cantidad++;
    if (_rangoFin != null) cantidad++;
    if (_areasFiltro != 'todos') cantidad++;
    if (_recorridosFiltro != 'todos') cantidad++;

    return cantidad;
  }

  void _limpiarFiltrosAplicados() {
    setState(() {
      _categoriaFiltro = null;
      _organizadorFiltro = null;
      _rangoInicio = null;
      _rangoFin = null;
      _areasFiltro = 'todos';
      _recorridosFiltro = 'todos';
    });
  }

  List<Map<String, dynamic>> get _eventosFiltrados {
    final texto = _busqueda.trim().toLowerCase();

    return _eventos.where((evento) {
      final estado = _estado(evento);

      if (_filtro == 1 && estado != 'Próximo') return false;
      if (_filtro == 2 && estado != 'En curso') return false;
      if (_filtro == 3 && estado != 'Finalizado') return false;

      if (_categoriaFiltro != null &&
          evento['categoria']?.toString() != _categoriaFiltro) {
        return false;
      }

      if (_organizadorFiltro != null &&
          _claveOrganizador(evento) != _organizadorFiltro) {
        return false;
      }

      if (!_enRango(evento['fechaInicio'], _rangoInicio)) {
        return false;
      }

      if (!_enRango(evento['fechaFin'], _rangoFin)) {
        return false;
      }

      if (!_cumplePresencia(evento['areas'], _areasFiltro)) {
        return false;
      }

      if (!_cumplePresencia(evento['recorridos'], _recorridosFiltro)) {
        return false;
      }

      if (texto.isEmpty) return true;

      final nombre = (evento['nombre'] ?? '').toString().toLowerCase();
      final categoria =
          (evento['categoria'] ?? '').toString().toLowerCase();
      final categoriaVisible =
          categoriaEventoLabel(
            _l10n,
            '${evento['categoria'] ?? ''}',
          ).toLowerCase();
      final empresa = _empresa(evento).toLowerCase();

      return nombre.contains(texto) ||
          categoria.contains(texto) ||
          categoriaVisible.contains(texto) ||
          empresa.contains(texto);
    }).toList();
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Próximo':
        return const Color(0xFF2563EB);
      case 'En curso':
        return const Color(0xFF15803D);
      case 'Finalizado':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _etiquetaEstado(String estado) {
    final color = _colorEstado(estado);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _nombreEstado(estado),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _detalle(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(valor),
        ],
      ),
    );
  }

  Future<void> _mostrarFiltros() async {
    String? categoria = _categoriaFiltro;
    String? organizador = _organizadorFiltro;
    DateTimeRange? rangoInicio = _rangoInicio;
    DateTimeRange? rangoFin = _rangoFin;
    String areas = _areasFiltro;
    String recorridos = _recorridosFiltro;

    final organizadores = _organizadores;

    final aplicar = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: _colorCrema,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, actualizarModal) {
            Future<void> elegirRango({
              required bool esInicio,
            }) async {
              final actual = esInicio ? rangoInicio : rangoFin;

              final seleccionado = await showDateRangePicker(
                context: sheetContext,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialDateRange: actual,
                initialEntryMode: DatePickerEntryMode.calendar,
                helpText: esInicio
                    ? _l10n.admEvtRangoInicio
                    : _l10n.admEvtRangoFin,
              );

              if (!sheetContext.mounted || seleccionado == null) return;

              actualizarModal(() {
                if (esInicio) {
                  rangoInicio = seleccionado;
                } else {
                  rangoFin = seleccionado;
                }
              });
            }

            Widget selectorPresencia({
              required String titulo,
              required String valor,
              required ValueChanged<String> cambiar,
            }) {
              return DropdownButtonFormField<String>(
                key: ValueKey('$titulo:$valor'),
                initialValue: valor,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ).copyWith(labelText: titulo),
                items: _opcionesPresencia.map((clave) {
                  return DropdownMenuItem<String>(
                    value: clave,
                    child: Text(_nombrePresencia(clave)),
                  );
                }).toList(),
                onChanged: (nuevo) {
                  if (nuevo != null) {
                    actualizarModal(() => cambiar(nuevo));
                  }
                },
              );
            }

            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _l10n.admEvtFiltrosAvanzados,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _l10n.admEvtFiltrosSub,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: ListView(
                        children: [
                          DropdownButtonFormField<String>(
                            key: ValueKey('categoria:$categoria'),
                            initialValue: categoria,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: _l10n.admEvtCategoria,
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(_l10n.admEvtTodasCategorias),
                              ),
                              ..._categorias.map((clave) {
                                return DropdownMenuItem<String>(
                                  value: clave,
                                  child: Text(
                                    categoriaEventoLabel(_l10n, clave),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (nuevo) {
                              actualizarModal(() => categoria = nuevo);
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            key: ValueKey('organizador:$organizador'),
                            initialValue:
                                organizadores.containsKey(organizador)
                                    ? organizador
                                    : null,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: _l10n.admEvtOrganizador,
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(_l10n.admEvtTodosOrganizadores),
                              ),
                              ...organizadores.entries.map((opcion) {
                                return DropdownMenuItem<String>(
                                  value: opcion.key,
                                  child: Text(opcion.value),
                                );
                              }),
                            ],
                            onChanged: (nuevo) {
                              actualizarModal(() => organizador = nuevo);
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _l10n.admEvtFechas,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _colorTexto,
                              side: const BorderSide(color: _colorBorde),
                            ),
                            onPressed: () => elegirRango(esInicio: true),
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(
                              rangoInicio == null
                                  ? _l10n.admEvtSelRangoInicio
                                  : _l10n.admEvtInicioRango(
                                      _formatearDia(rangoInicio!.start),
                                      _formatearDia(rangoInicio!.end),
                                    ),
                            ),
                          ),
                          if (rangoInicio != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: _colorTexto,
                                ),
                                onPressed: () {
                                  actualizarModal(() => rangoInicio = null);
                                },
                                child: Text(_l10n.admEvtQuitarInicio),
                              ),
                            ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _colorTexto,
                              side: const BorderSide(color: _colorBorde),
                            ),
                            onPressed: () => elegirRango(esInicio: false),
                            icon: const Icon(Icons.event_available_outlined),
                            label: Text(
                              rangoFin == null
                                  ? _l10n.admEvtSelRangoFin
                                  : _l10n.admEvtFinRango(
                                      _formatearDia(rangoFin!.start),
                                      _formatearDia(rangoFin!.end),
                                    ),
                            ),
                          ),
                          if (rangoFin != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: _colorTexto,
                                ),
                                onPressed: () {
                                  actualizarModal(() => rangoFin = null);
                                },
                                child: Text(_l10n.admEvtQuitarFin),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Text(
                            _l10n.admEvtAreasRecorridos,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          selectorPresencia(
                            titulo: _l10n.admEvtAreas,
                            valor: areas,
                            cambiar: (nuevo) => areas = nuevo,
                          ),
                          const SizedBox(height: 16),
                          selectorPresencia(
                            titulo: _l10n.admEvtRecorridos,
                            valor: recorridos,
                            cambiar: (nuevo) => recorridos = nuevo,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _colorRojo,
                              side: const BorderSide(color: _colorRojo),
                            ),
                            onPressed: () {
                              actualizarModal(() {
                                categoria = null;
                                organizador = null;
                                rangoInicio = null;
                                rangoFin = null;
                                areas = 'todos';
                                recorridos = 'todos';
                              });
                            },
                            icon: const Icon(Icons.filter_alt_off_outlined),
                            label: Text(_l10n.admLimpiarFiltros),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _colorVerde,
                              foregroundColor: const Color(0xFF172017),
                            ),
                            onPressed: () {
                              Navigator.pop(sheetContext, true);
                            },
                            child: Text(_l10n.admAplicarFiltros),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || aplicar != true) return;

    setState(() {
      _categoriaFiltro = categoria;
      _organizadorFiltro = organizador;
      _rangoInicio = rangoInicio;
      _rangoFin = rangoFin;
      _areasFiltro = areas;
      _recorridosFiltro = recorridos;
    });
  }

  Future<void> _mostrarDetalle(Map<String, dynamic> evento) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _colorCrema,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            (evento['nombre'] ?? _l10n.admEvtEvento).toString(),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _detalle(
                    _l10n.perfilEstado,
                    _nombreEstado(_estado(evento)),
                  ),
                  _detalle(
                    _l10n.admEvtCategoria,
                    evento['categoria'] == null
                        ? '-'
                        : categoriaEventoLabel(
                            _l10n,
                            evento['categoria'].toString(),
                          ),
                  ),
                  _detalle(_l10n.rolEmpresa, _empresa(evento)),
                  _detalle(
                    _l10n.admEvtInicio,
                    _formatearFecha(evento['fechaInicio']),
                  ),
                  _detalle(
                    _l10n.admEvtFin,
                    _formatearFecha(evento['fechaFin']),
                  ),
                  _detalle(
                    _l10n.admDescripcion,
                    evento['descripcion']?.toString() ??
                        _l10n.admRepSinDescripcion,
                  ),
                  _detalle(
                    _l10n.admEvtAreas,
                    '${(evento['areas'] as List?)?.length ?? 0}',
                  ),
                  _detalle(
                    _l10n.admEvtRecorridos,
                    '${(evento['recorridos'] as List?)?.length ?? 0}',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_l10n.comunCerrar),
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: Text(_l10n.admEvtEliminar),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade700,
              ),
              onPressed: _eliminando
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                      _confirmarEliminacion(evento);
                    },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmarEliminacion(
    Map<String, dynamic> evento,
  ) async {
    final id = evento['id'];

    if (id is! int || _eliminando) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _colorCrema,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(_l10n.admEvtConfirmarTitulo),
          content: Text(
            _l10n.admEvtConfirmarMsg('${evento['nombre']}'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_l10n.comunCancelar),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_l10n.admEvtEliminarDef),
            ),
          ],
        );
      },
    );

    if (confirmado != true || !mounted || _eliminando) {
      return;
    }

    setState(() => _eliminando = true);

    try {
      await _api.delete('/eventos/$id');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.admEvtEliminado),
        ),
      );

      await _cargarEventos();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mensajeError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _eliminando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventos = _eventosFiltrados;

    return AdminListScaffold(
      searchHint: _l10n.admEvtBuscar,
      searchController: _busquedaController,
      onSearch: (texto) {
        setState(() => _busqueda = texto);
      },
      onFilters: _mostrarFiltros,
      tabs: _filtros,
      tabIndex: _filtro,
      onTab: (indice) {
        setState(() => _filtro = indice);
      },
      toolbarTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_cantidadFiltrosActivos > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(
                  _l10n.admEvtFiltrosActivos(_cantidadFiltrosActivos),
                  style: const TextStyle(fontSize: 11),
                ),
                onDeleted: _limpiarFiltrosAplicados,
                deleteIcon: const Icon(Icons.close, size: 16),
              ),
            ),
          IconButton(
            tooltip: _l10n.admEvtActualizar,
            icon: const Icon(Icons.refresh),
            onPressed: _cargando || _eliminando ? null : _cargarEventos,
          ),
        ],
      ),
      child: AdminDataTable(
        loading: _cargando,
        error: _error,
        onRetry: _cargarEventos,
        emptyTitle: _l10n.admEvtSin,
        emptyMessage: _busqueda.isNotEmpty ||
                _filtro != 0 ||
                _cantidadFiltrosActivos > 0
            ? _l10n.admEvtSinCoincidencias
            : _l10n.admEvtSinRegistrados,
        rows: eventos.map((evento) {
          final nombre = (evento['nombre'] ?? _l10n.admEvtSinNombre).toString();
          final categoria = evento['categoria'] == null
              ? '-'
              : categoriaEventoLabel(_l10n, evento['categoria'].toString());
          final empresa = _empresa(evento);
          final estado = _estado(evento);

          return AdminRow(
            icon: Icons.event_outlined,
            title: nombre,
            subtitle: '$categoria · $empresa · '
                '${_formatearFecha(evento['fechaInicio'])}',
            trailing: _etiquetaEstado(estado),
            onTap: _eliminando ? null : () => _mostrarDetalle(evento),
          );
        }).toList(),
      ),
    );
  }
}
