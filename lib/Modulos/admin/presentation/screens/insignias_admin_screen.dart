
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
  const InsigniasAdminScreen({
    super.key,
    this.api,
  });

  /// Permite inyectar un servicio simulado durante las pruebas.
  final InsigniasAdminApi? api;

  @override
  State<InsigniasAdminScreen> createState() =>
      _InsigniasAdminScreenState();
}

class _InsigniasAdminScreenState extends State<InsigniasAdminScreen> {
  late final InsigniasAdminApi _api;

  final TextEditingController _busquedaController =
      TextEditingController();

  List<InsigniaAdminItem> _insignias = <InsigniaAdminItem>[];

  String _busqueda = '';
  int _filtroEstado = 0;
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
      final List<InsigniaAdminItem> insignias =
          await _api.listarInsignias();

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

  Future<void> _abrirFormulario({
    InsigniaAdminItem? insignia,
  }) async {
    final bool? guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _FormularioInsignia(
          api: _api,
          insignia: insignia,
        );
      },
    );

    if (!mounted || guardado != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          insignia == null
              ? 'Insignia creada correctamente.'
              : 'Insignia actualizada correctamente.',
        ),
      ),
    );

    await _cargarInsignias();
  }

  String _formatearMeta(double? meta) {
    if (meta == null) return 'Sin meta';

    if (meta == meta.roundToDouble()) {
      return meta.toStringAsFixed(0);
    }

    return meta.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final List<AdminRow> filas =
        _insigniasFiltradas.map((InsigniaAdminItem insignia) {
      final String descripcion =
          '${insignia.codigo} · ${insignia.metrica ?? "Sin métrica"}'
          ' · Meta: ${_formatearMeta(insignia.meta)}';

      return AdminRow(
        icon: Icons.military_tech_outlined,
        title: '${insignia.emoji} ${insignia.nombre}',
        subtitle: descripcion,
        trailing: Chip(
          label: Text(insignia.activa ? 'Activa' : 'Inactiva'),
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
        setState(() => _busqueda = valor);
      },
      tabs: const <String>['Todas', 'Activas', 'Inactivas'],
      tabIndex: _filtroEstado,
      onTab: (int indice) {
        setState(() => _filtroEstado = indice);
      },
      toolbarTrailing: FqButton.primary(
        label: l10n.comunNuevo,
        icon: Icons.add,
        expand: false,
        dense: true,
        onPressed: () => _abrirFormulario(),
      ),
      child: AdminDataTable(
        rows: filas,
        loading: _cargando,
        error: _error,
        onRetry: _cargarInsignias,
        emptyTitle: l10n.admInsigniasVacioTitulo,
        emptyMessage: l10n.admInsigniasVacioMensaje,
      ),
    );
  }
}

/// Formulario independiente para crear y editar insignias.
class _FormularioInsignia extends StatefulWidget {
  const _FormularioInsignia({
    required this.api,
    this.insignia,
  });

  final InsigniasAdminApi api;
  final InsigniaAdminItem? insignia;

  @override
  State<_FormularioInsignia> createState() =>
      _FormularioInsigniaState();
}

class _FormularioInsigniaState extends State<_FormularioInsignia> {
  late final TextEditingController _codigoController;
  late final TextEditingController _nombreController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _emojiController;
  late final TextEditingController _metaController;

  static const Map<String, String> _tipos = <String, String>{
    'hito': 'Hito',
    'km': 'Kilómetros',
  };

  static const Map<String, String> _metricas = <String, String>{
    'km': 'Kilómetros recorridos',
    'rutas': 'Rutas completadas',
    'alertas': 'Alertas registradas',
    'nodos': 'Nodos visitados',
    'especial': 'Especial',
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

    _codigoController = TextEditingController(
      text: insignia?.codigo ?? '',
    );

    _nombreController = TextEditingController(
      text: insignia?.nombre ?? '',
    );

    _descripcionController = TextEditingController(
      text: insignia?.descripcion ?? '',
    );

    _emojiController = TextEditingController(
      text: insignia?.emoji ?? '',
    );

    _metaController = TextEditingController(
      text: insignia?.meta?.toString() ?? '',
    );

    _tipo = _tipos.containsKey(insignia?.tipo)
        ? insignia!.tipo
        : 'hito';

    _metrica = _metricas.containsKey(insignia?.metrica)
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

    final String codigo =
        _codigoController.text.trim().toUpperCase();
    final String nombre = _nombreController.text.trim();
    final String descripcion = _descripcionController.text.trim();
    final String emoji = _emojiController.text.trim();
    final String textoMeta = _metaController.text.trim();

    if (nombre.isEmpty ||
        descripcion.isEmpty ||
        emoji.isEmpty ||
        (_creando && codigo.isEmpty)) {
      setState(() {
        _errorFormulario =
            'Completa todos los campos obligatorios.';
      });
      return;
    }

    if (_creando &&
        !RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(codigo)) {
      setState(() {
        _errorFormulario =
            'El código debe iniciar con una letra y contener '
            'solo letras mayúsculas, números o guiones bajos.';
      });
      return;
    }

    if (codigo.length > 50 ||
        nombre.length > 100 ||
        emoji.runes.length > 10) {
      setState(() {
        _errorFormulario =
            'Revisá las longitudes máximas de los campos.';
      });
      return;
    }

    final double? meta =
        double.tryParse(textoMeta.replaceAll(',', '.'));

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
            ((meta * 100) - (meta * 100).round()).abs() >
                0.000001)) {
      setState(() {
        _errorFormulario =
            'La meta debe ser positiva y tener como máximo '
            'dos decimales.';
      });
      return;
    }

    if (_tipo == 'km' && _metrica != 'km') {
      setState(() {
        _errorFormulario =
            'Las insignias de tipo kilómetros deben utilizar '
            'la métrica kilómetros.';
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
    return AlertDialog(
      title: Text(
        _creando ? 'Nueva insignia' : 'Editar insignia',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Configuración de la insignia',
                style: TextStyle(
                  color: FqColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codigoController,
                enabled: _creando && !_guardando,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'Código único',
                  hintText: 'RUTAS_10',
                  helperText:
                      'El código no se puede modificar después.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nombreController,
                enabled: !_guardando,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descripcionController,
                enabled: !_guardando,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emojiController,
                enabled: !_guardando,
                decoration: const InputDecoration(
                  labelText: 'Emoji',
                  hintText: '🏅',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                items: _tipos.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
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
                decoration: const InputDecoration(
                  labelText: 'Métrica',
                  border: OutlineInputBorder(),
                ),
                items: _metricas.entries
                    .where(
                      (entry) =>
                          _tipo != 'km' || entry.key == 'km',
                    )
                    .map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
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
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Meta',
                  hintText: '10',
                  helperText: !_creando &&
                          widget.insignia?.meta == null &&
                          _tipo == 'hito' &&
                          _metrica == 'especial'
                      ? 'Opcional: dejá vacío para conservar '
                          'la meta nula.'
                      : 'Número positivo, máximo dos decimales.',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Insignia activa'),
                subtitle: Text(
                  _activa
                      ? 'Disponible para los usuarios'
                      : 'No disponible para nuevos desbloqueos',
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
          onPressed: _guardando
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
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
              : Text(
                  _creando
                      ? 'Crear insignia'
                      : 'Guardar cambios',
                ),
        ),
      ],
    );
  }
}
