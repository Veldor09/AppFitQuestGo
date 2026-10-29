import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/insignia_admin_item.dart';
import 'package:fit_quest_go/Modulos/admin/data/insignias_admin_api.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_list_scaffold.dart';

/// ADM-10 · Gestión administrativa de insignias.
class InsigniasAdminScreen extends StatefulWidget {
  const InsigniasAdminScreen({super.key, this.api});

  /// Permite inyectar un servicio simulado durante las pruebas.
  final InsigniasAdminApi? api;

  @override
  State<InsigniasAdminScreen> createState() => _InsigniasAdminScreenState();
}

class _InsigniasAdminScreenState extends State<InsigniasAdminScreen> {
  late final InsigniasAdminApi _api;

  final TextEditingController _busquedaController = TextEditingController();

  List<InsigniaAdminItem> _insignias = <InsigniaAdminItem>[];

  String _busqueda = '';
  int _filtroEstado = 0;
  static const int _insigniasPorPagina = 8;
  int _paginaActual = 0;
  int _versionCarga = 0;

  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? InsigniasAdminApi();
    _cargarInsignias();
  }

  @override
  void dispose() {
    _versionCarga++;
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarInsignias() async {
    final int version = ++_versionCarga;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final List<InsigniaAdminItem> insignias = await _api.listarInsignias();

      if (!mounted || version != _versionCarga) return;

      setState(() {
        _insignias = insignias;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted || version != _versionCarga) return;

      setState(() {
        _error = error.toString();
        _cargando = false;
      });
    }
  }

  List<InsigniaAdminItem> get _insigniasFiltradas {
    final String termino = _busqueda.trim().toLowerCase();

    return _insignias.where((InsigniaAdminItem insignia) {
      if (_filtroEstado == 1 && !insignia.activa) return false;
      if (_filtroEstado == 2 && insignia.activa) return false;

      if (termino.isEmpty) return true;

      return insignia.nombre.toLowerCase().contains(termino) ||
          insignia.codigo.toLowerCase().contains(termino) ||
          insignia.descripcion.toLowerCase().contains(termino);
    }).toList();
  }

  Future<void> _abrirFormulario({InsigniaAdminItem? insignia}) async {
    final bool? guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _FormularioInsignia(api: _api, insignia: insignia);
      },
    );

    if (!mounted || guardado != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          insignia == null
              ? AppLocalizations.of(context)!.admInsCreada
              : AppLocalizations.of(context)!.admInsActualizada,
        ),
      ),
    );

    await _cargarInsignias();
  }

  String _formatearMeta(AppLocalizations l10n, double? meta) {
    if (meta == null) return l10n.admInsSinMeta;

    if (meta == meta.roundToDouble()) {
      return meta.toStringAsFixed(0);
    }

    return meta.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final List<InsigniaAdminItem> filtradas = _insigniasFiltradas;
    final int totalPaginas = (filtradas.length / _insigniasPorPagina).ceil();
    final int paginaVisible = totalPaginas == 0
        ? 0
        : _paginaActual.clamp(0, totalPaginas - 1);
    final int inicio = paginaVisible * _insigniasPorPagina;
    final int fin = (inicio + _insigniasPorPagina).clamp(0, filtradas.length);

    final List<AdminRow> filas = filtradas.sublist(inicio, fin).map((
      InsigniaAdminItem insignia,
    ) {
      final String descripcion = l10n.admInsResumen(
        insignia.codigo,
        insignia.metrica ?? l10n.admInsSinMetrica,
        _formatearMeta(l10n, insignia.meta),
      );

      return AdminRow(
        icon: Icons.military_tech_outlined,
        title: '${insignia.emoji} ${insignia.nombre}',
        subtitle: descripcion,
        trailing: Chip(
          label: Text(insignia.activa ? l10n.admActiva : l10n.admInactiva),
          backgroundColor: insignia.activa
              ? Colors.green.shade50
              : Colors.grey.shade200,
          labelStyle: TextStyle(
            color: insignia.activa
                ? Colors.green.shade800
                : Colors.grey.shade800,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        onTap: () => _abrirFormulario(insignia: insignia),
      );
    }).toList();

    return AdminListScaffold(
      searchHint: l10n.admInsigniasSearchHint,
      searchController: _busquedaController,
      onSearch: (String valor) {
        setState(() {
          _busqueda = valor;
          _paginaActual = 0;
        });
      },
      tabs: <String>[
        l10n.notificacionesFiltroTodas,
        l10n.admTabActivas,
        l10n.admTabInactivas,
      ],
      tabIndex: _filtroEstado,
      onTab: (int indice) {
        setState(() {
          _filtroEstado = indice;
          _paginaActual = 0;
        });
      },
      toolbarTrailing: FqButton.primary(
        label: l10n.comunNuevo,
        icon: Icons.add,
        expand: false,
        dense: true,
        onPressed: () => _abrirFormulario(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AdminDataTable(
            rows: filas,
            loading: _cargando,
            error: _error,
            onRetry: _cargarInsignias,
            emptyTitle: l10n.admInsigniasVacioTitulo,
            emptyMessage: l10n.admInsigniasVacioMensaje,
          ),
          if (!_cargando && _error == null && totalPaginas > 1) ...<Widget>[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: paginaVisible > 0
                      ? () => setState(() => _paginaActual = paginaVisible - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: Text(l10n.admAnterior),
                ),
                Text(l10n.admPaginaDe(paginaVisible + 1, totalPaginas)),
                OutlinedButton.icon(
                  onPressed: paginaVisible < totalPaginas - 1
                      ? () => setState(() => _paginaActual = paginaVisible + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: Text(l10n.admSiguiente),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

/// Formulario independiente para crear y editar insignias.
class _FormularioInsignia extends StatefulWidget {
  const _FormularioInsignia({required this.api, this.insignia});

  final InsigniasAdminApi api;
  final InsigniaAdminItem? insignia;

  @override
  State<_FormularioInsignia> createState() => _FormularioInsigniaState();
}

class _FormularioInsigniaState extends State<_FormularioInsignia> {
  late final TextEditingController _codigoController;
  late final TextEditingController _nombreController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _emojiController;
  late final TextEditingController _metaController;

  static const List<String> _tipos = <String>['hito', 'km'];

  static const List<String> _metricas = <String>[
    'km',
    'rutas',
    'alertas',
    'nodos',
    'especial',
  ];

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  String _nombreTipo(String clave) => switch (clave) {
    'hito' => _l10n.admInsTipoHito,
    'km' => _l10n.admInsTipoKm,
    _ => clave,
  };

  String _nombreMetrica(String clave) => switch (clave) {
    'km' => _l10n.admInsMetricaKm,
    'rutas' => _l10n.admInsMetricaRutas,
    'alertas' => _l10n.admInsMetricaAlertas,
    'nodos' => _l10n.admInsMetricaNodos,
    'especial' => _l10n.admInsMetricaEspecial,
    _ => clave,
  };

  String _tipo = 'hito';
  String _metrica = 'rutas';

  bool _activa = true;
  bool _guardando = false;
  String? _errorFormulario;

  bool get _creando => widget.insignia == null;

  @override
  void initState() {
    super.initState();

    final InsigniaAdminItem? insignia = widget.insignia;

    _codigoController = TextEditingController(text: insignia?.codigo ?? '');

    _nombreController = TextEditingController(text: insignia?.nombre ?? '');

    _descripcionController = TextEditingController(
      text: insignia?.descripcion ?? '',
    );

    _emojiController = TextEditingController(text: insignia?.emoji ?? '');

    _metaController = TextEditingController(
      text: insignia?.meta?.toString() ?? '',
    );

    _tipo = _tipos.contains(insignia?.tipo) ? insignia!.tipo : 'hito';

    _metrica = _metricas.contains(insignia?.metrica)
        ? insignia!.metrica!
        : 'rutas';

    if (_tipo == 'km') {
      _metrica = 'km';
    }

    _activa = insignia?.activa ?? true;
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nombreController.dispose();
    _descripcionController.dispose();
    _emojiController.dispose();
    _metaController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;

    final String codigo = _codigoController.text.trim().toUpperCase();
    final String nombre = _nombreController.text.trim();
    final String descripcion = _descripcionController.text.trim();
    final String emoji = _emojiController.text.trim();
    final String textoMeta = _metaController.text.trim();

    if (nombre.isEmpty ||
        descripcion.isEmpty ||
        emoji.isEmpty ||
        (_creando && codigo.isEmpty)) {
      setState(() {
        _errorFormulario = _l10n.admInsErrCampos;
      });
      return;
    }

    if (_creando && !RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(codigo)) {
      setState(() {
        _errorFormulario = _l10n.admInsErrCodigo;
      });
      return;
    }

    if (codigo.length > 50 || nombre.length > 100 || emoji.runes.length > 10) {
      setState(() {
        _errorFormulario = _l10n.admInsErrLongitudes;
      });
      return;
    }

    final double? meta = double.tryParse(textoMeta.replaceAll(',', '.'));

    // Una insignia especial existente con meta nula
    // puede conservar ese valor durante la edición.
    // Para crear insignias nuevas, la meta es obligatoria.
    final bool permiteMetaNula =
        !_creando &&
        widget.insignia?.meta == null &&
        _tipo == 'hito' &&
        _metrica == 'especial' &&
        textoMeta.isEmpty;

    if (!permiteMetaNula &&
        (meta == null ||
            !meta.isFinite ||
            meta < 0.01 ||
            meta > 99999999.99 ||
            ((meta * 100) - (meta * 100).round()).abs() > 0.000001)) {
      setState(() {
        _errorFormulario = _l10n.admInsErrMeta;
      });
      return;
    }

    if (_tipo == 'km' && _metrica != 'km') {
      setState(() {
        _errorFormulario = _l10n.admInsErrKm;
      });
      return;
    }

    setState(() {
      _guardando = true;
      _errorFormulario = null;
    });

    try {
      if (_creando) {
        // La validación anterior garantiza que meta
        // no sea nula al crear una insignia.
        await widget.api.crearInsignia(
          codigo: codigo,
          nombre: nombre,
          descripcion: descripcion,
          emoji: emoji,
          tipo: _tipo,
          metrica: _metrica,
          meta: meta!,
          activa: _activa,
        );
      } else {
        // Si meta es nula, la API omite ese campo
        // y el backend conserva el valor existente.
        await widget.api.editarInsignia(
          id: widget.insignia!.id,
          nombre: nombre,
          descripcion: descripcion,
          emoji: emoji,
          tipo: _tipo,
          metrica: _metrica,
          meta: meta,
          activa: _activa,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _guardando = false;
        _errorFormulario = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Color(0xFF757575)),
          floatingLabelStyle: TextStyle(color: Color(0xFF424242)),
          hintStyle: TextStyle(color: Color(0xFF9E9E9E)),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF616161), width: 1.5),
          ),
        ),
      ),
      child: AlertDialog(
        title: Text(_creando ? _l10n.admInsNueva : _l10n.admInsEditar),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _l10n.admInsConfig,
                  style: const TextStyle(
                    color: FqColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codigoController,
                  enabled: _creando && !_guardando,
                  maxLength: 50,
                  decoration: InputDecoration(
                    labelText: _l10n.admInsCodigo,
                    hintText: 'RUTAS_10',
                    helperText: _l10n.admInsCodigoAyuda,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nombreController,
                  enabled: !_guardando,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: _l10n.comunNombre,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descripcionController,
                  enabled: !_guardando,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: _l10n.admDescripcion,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emojiController,
                  enabled: !_guardando,
                  decoration: InputDecoration(
                    labelText: _l10n.admEmoji,
                    hintText: '🏅',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  decoration: InputDecoration(
                    labelText: _l10n.admInsTipo,
                    border: const OutlineInputBorder(),
                  ),
                  items: _tipos.map((String clave) {
                    return DropdownMenuItem<String>(
                      value: clave,
                      child: Text(_nombreTipo(clave)),
                    );
                  }).toList(),
                  onChanged: _guardando
                      ? null
                      : (String? valor) {
                          if (valor == null) return;

                          setState(() {
                            _tipo = valor;

                            if (_tipo == 'km') {
                              _metrica = 'km';
                            }
                          });
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  // Fuerza la actualización visual de la métrica
                  // cuando cambia el tipo de insignia.
                  key: ValueKey<String>('metrica_$_tipo'),
                  initialValue: _metrica,
                  decoration: InputDecoration(
                    labelText: _l10n.admMetrica,
                    border: const OutlineInputBorder(),
                  ),
                  items: _metricas
                      .where((String clave) => _tipo != 'km' || clave == 'km')
                      .map((String clave) {
                        return DropdownMenuItem<String>(
                          value: clave,
                          child: Text(_nombreMetrica(clave)),
                        );
                      })
                      .toList(),
                  onChanged: _guardando
                      ? null
                      : (String? valor) {
                          if (valor != null) {
                            setState(() => _metrica = valor);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _metaController,
                  enabled: !_guardando,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _l10n.admMeta,
                    hintText: '10',
                    helperText:
                        !_creando &&
                            widget.insignia?.meta == null &&
                            _tipo == 'hito' &&
                            _metrica == 'especial'
                        ? _l10n.admInsMetaAyudaVacia
                        : _l10n.admInsMetaAyuda,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_l10n.admInsActivoTitulo),
                  subtitle: Text(
                    _activa
                        ? _l10n.admDisponibleUsuarios
                        : _l10n.admInsActivoNo,
                  ),
                  value: _activa,
                  onChanged: _guardando
                      ? null
                      : (bool valor) {
                          setState(() => _activa = valor);
                        },
                ),
                if (_errorFormulario != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _errorFormulario!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            onPressed: _guardando
                ? null
                : () => Navigator.of(context).pop(false),
            child: Text(_l10n.comunCancelar),
          ),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _creando ? _l10n.admInsCrear : _l10n.comunGuardarCambios,
                  ),
          ),
        ],
      ),
    );
  }
}
