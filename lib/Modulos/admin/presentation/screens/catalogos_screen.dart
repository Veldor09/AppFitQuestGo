
import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogo_item.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogos_api.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_list_scaffold.dart';

/// ADM-11 · Gestión administrativa de catálogos.
class CatalogosScreen extends StatefulWidget {
  const CatalogosScreen({
    super.key,
    this.api,
  });

  /// Permite utilizar un servicio simulado durante las pruebas.
  final CatalogosApi? api;

  @override
  State<CatalogosScreen> createState() => _CatalogosScreenState();
}

class _CatalogosScreenState extends State<CatalogosScreen> {
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  String _nombreCatalogo(String clave) => switch (clave) {
    'alertas' => _l10n.admCatTipoAlertas,
    'nodos' => _l10n.admCatCategoriasNodos,
    'actividades' => _l10n.admCatActividadesRutas,
    _ => clave,
  };

  late final CatalogosApi _api;

  final TextEditingController _busquedaController = TextEditingController();

  static const List<String> _catalogos = <String>[
    'alertas',
    'nodos',
    'actividades',
  ];

  String _catalogoSeleccionado = 'alertas';
  String _busqueda = '';
  int _filtroEstado = 0;

  List<CatalogoItem> _items = <CatalogoItem>[];
  bool _cargando = false;
  String? _error;
  int _versionCarga = 0;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? CatalogosApi();
    _cargarItems();
  }

  @override
  void dispose() {
    _versionCarga++;
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarItems() async {
    final int version = ++_versionCarga;
    final String catalogo = _catalogoSeleccionado;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final List<CatalogoItem> items = await _api.listarItems(catalogo);

      if (!mounted || version != _versionCarga) return;

      setState(() {
        _items = items;
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

  void _seleccionarCatalogo(String catalogo) {
    if (catalogo == _catalogoSeleccionado) return;

    setState(() {
      _catalogoSeleccionado = catalogo;
      _filtroEstado = 0;
      _busqueda = '';
      _items = <CatalogoItem>[];
      _busquedaController.clear();
    });

    _cargarItems();
  }

  List<CatalogoItem> get _itemsFiltrados {
    final String termino = _busqueda.trim().toLowerCase();

    return _items.where((CatalogoItem item) {
      if (_filtroEstado == 1 && !item.activo) return false;
      if (_filtroEstado == 2 && item.activo) return false;

      if (termino.isEmpty) return true;

      return item.nombre.toLowerCase().contains(termino) ||
          item.clave.toLowerCase().contains(termino);
    }).toList();
  }

  Future<void> _abrirFormulario({CatalogoItem? item}) async {
    final String catalogo = _catalogoSeleccionado;

    final bool? guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _FormularioCatalogo(
          api: _api,
          catalogo: catalogo,
          nombreCatalogo: _nombreCatalogo(catalogo),
          item: item,
        );
      },
    );

    if (!mounted || guardado != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          item == null
              ? _l10n.admCatCreado
              : _l10n.admCatActualizado,
        ),
      ),
    );

    // Evita recargar otro catálogo si el usuario cambió de sección.
    if (_catalogoSeleccionado == catalogo) {
      await _cargarItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final List<CatalogoItem> filtrados = _itemsFiltrados;

    final List<AdminRow> filas = filtrados.map((CatalogoItem item) {
      return AdminRow(
        icon: _iconoCatalogo(),
        title: item.nombre,
        subtitle: item.clave,
        trailing: Chip(
          label: Text(item.activo ? _l10n.admActivo : _l10n.admInactivo),
          backgroundColor: item.activo
              ? Colors.green.shade50
              : Colors.grey.shade200,
          labelStyle: TextStyle(
            color: item.activo
                ? Colors.green.shade800
                : Colors.grey.shade800,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        onTap: () => _abrirFormulario(item: item),
      );
    }).toList();

    return AdminListScaffold(
      searchHint: l10n.admCatalogosSearchHint,
      searchController: _busquedaController,
      onSearch: (String valor) {
        setState(() => _busqueda = valor);
      },
      tabs: <String>[l10n.usuariosFiltroTodos, l10n.admTabActivos, l10n.admTabInactivos],
      tabIndex: _filtroEstado,
      onTab: (int indice) {
        setState(() => _filtroEstado = indice);
      },
      toolbarTrailing: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          DropdownButton<String>(
            value: _catalogoSeleccionado,
            items: _catalogos.map((String clave) {
              return DropdownMenuItem<String>(
                value: clave,
                child: Text(_nombreCatalogo(clave)),
              );
            }).toList(),
            onChanged: (String? valor) {
              if (valor != null) _seleccionarCatalogo(valor);
            },
          ),
          FqButton.primary(
            label: l10n.comunNuevo,
            icon: Icons.add,
            expand: false,
            dense: true,
            onPressed: () => _abrirFormulario(),
          ),
        ],
      ),
      child: AdminDataTable(
        rows: filas,
        loading: _cargando,
        error: _error,
        onRetry: _cargarItems,
        emptyTitle: _l10n.admSinElementos,
        emptyMessage: _l10n.admSinElementosMsg,
      ),
    );
  }

  IconData _iconoCatalogo() {
    switch (_catalogoSeleccionado) {
      case 'alertas':
        return Icons.warning_amber_outlined;
      case 'nodos':
        return Icons.location_on_outlined;
      case 'actividades':
        return Icons.directions_run_outlined;
      default:
        return Icons.category_outlined;
    }
  }
}

/// Formulario independiente para que los TextEditingController se liberen
/// cuando Flutter desmonte el diálogo, no antes.
class _FormularioCatalogo extends StatefulWidget {
  const _FormularioCatalogo({
    required this.api,
    required this.catalogo,
    required this.nombreCatalogo,
    this.item,
  });

  final CatalogosApi api;
  final String catalogo;
  final String nombreCatalogo;
  final CatalogoItem? item;

  @override
  State<_FormularioCatalogo> createState() => _FormularioCatalogoState();
}

class _FormularioCatalogoState extends State<_FormularioCatalogo> {
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  late final TextEditingController _claveController;
  late final TextEditingController _nombreController;

  bool _activo = true;
  bool _guardando = false;
  String? _errorFormulario;

  bool get _creando => widget.item == null;

  @override
  void initState() {
    super.initState();

    _claveController = TextEditingController(
      text: widget.item?.clave ?? '',
    );

    _nombreController = TextEditingController(
      text: widget.item?.nombre ?? '',
    );

    _activo = widget.item?.activo ?? true;
  }

  @override
  void dispose() {
    _claveController.dispose();
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;

    final String clave = _claveController.text.trim();
    final String nombre = _nombreController.text.trim();

    if (nombre.isEmpty || (_creando && clave.isEmpty)) {
      setState(() {
        _errorFormulario = _l10n.admCatCompletaCampos;
      });
      return;
    }

    setState(() {
      _guardando = true;
      _errorFormulario = null;
    });

    try {
      if (_creando) {
        await widget.api.crearItem(
          catalogo: widget.catalogo,
          clave: clave,
          nombre: nombre,
        );
      } else {
        await widget.api.editarItem(
          catalogo: widget.catalogo,
          id: widget.item!.id,
          nombre: nombre,
          activo: _activo,
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
    return AlertDialog(
      title: Text(
        _creando ? _l10n.admCatNuevo : _l10n.admCatEditar,
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.nombreCatalogo,
                style: const TextStyle(
                  color: FqColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _claveController,
                enabled: _creando && !_guardando,
                decoration: InputDecoration(
                  labelText: _l10n.admCatClave,
                  hintText: 'ejemplo_nuevo',
                  helperText: _l10n.admCatClaveAyuda,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nombreController,
                enabled: !_guardando,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: _l10n.comunNombre,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (!_creando) ...<Widget>[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_l10n.admCatActivoTitulo),
                  subtitle: Text(
                    _activo
                        ? _l10n.admDisponibleUsuarios
                        : _l10n.admCatActivoNo,
                  ),
                  value: _activo,
                  onChanged: _guardando
                      ? null
                      : (bool valor) {
                          setState(() => _activo = valor);
                        },
                ),
              ],
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : Text(_creando ? _l10n.admCrear : _l10n.comunGuardarCambios),
        ),
      ],
    );
  }
}
