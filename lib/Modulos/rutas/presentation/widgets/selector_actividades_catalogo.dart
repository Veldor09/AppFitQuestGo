
import 'package:flutter/material.dart';

import 'package:fit_quest_go/Modulos/admin/data/catalogo_item.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogos_api.dart';
import 'package:fit_quest_go/core/catalogos/actividades_ruta.dart';
import 'package:fit_quest_go/core/widgets/fq_selector_opciones.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

/// Selector de actividades administradas desde ADM-11.
///
/// Solo permite seleccionar claves activas en el backend.
/// Conserva los iconos y traducciones de las actividades originales.
class SelectorActividadesCatalogo extends StatefulWidget {
  const SelectorActividadesCatalogo({
    super.key,
    required this.seleccion,
    required this.onChanged,
    this.errorTexto,
    this.catalogosApi,
    this.onEstadoCarga,
    this.onActividadesDisponibles,
  });

  final Set<String> seleccion;
  final ValueChanged<Set<String>> onChanged;
  final String? errorTexto;
  final CatalogosApi? catalogosApi;

  /// Indica si el catálogo está disponible para guardar.
  final ValueChanged<bool>? onEstadoCarga;

  /// Entrega las claves activas en el orden recibido del backend.
  final ValueChanged<List<String>>? onActividadesDisponibles;

  @override
  State<SelectorActividadesCatalogo> createState() =>
      _SelectorActividadesCatalogoState();
}

class _SelectorActividadesCatalogoState
    extends State<SelectorActividadesCatalogo> {
  late final CatalogosApi _api = widget.catalogosApi ?? CatalogosApi();

  List<CatalogoItem> _items = <CatalogoItem>[];
  bool _cargando = true;
  String? _error;
  int _solicitud = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _cargar();
      }
    });
  }

  Future<void> _cargar() async {
    final int solicitudActual = ++_solicitud;

    setState(() {
      _cargando = true;
      _error = null;
      _items = <CatalogoItem>[];
    });

    widget.onEstadoCarga?.call(false);
    widget.onActividadesDisponibles?.call(<String>[]);

    try {
      final List<CatalogoItem> resultado =
          await _api.listarItemsActivos('actividades');

      if (!mounted || solicitudActual != _solicitud) return;

      final List<CatalogoItem> activos = resultado
          .where((CatalogoItem item) => item.activo)
          .toList();

      final Set<String> clavesActivas = activos
          .map((CatalogoItem item) => item.clave)
          .toSet();

      final Set<String> seleccionValida = widget.seleccion
          .where((String clave) => clavesActivas.contains(clave))
          .toSet();

      setState(() {
        _items = activos;
        _cargando = false;
        _error = null;
      });

      if (seleccionValida.length != widget.seleccion.length) {
        widget.onChanged(seleccionValida);
      }

      widget.onActividadesDisponibles?.call(
        activos.map((CatalogoItem item) => item.clave).toList(),
      );

      widget.onEstadoCarga?.call(activos.isNotEmpty);
    } catch (_) {
      if (!mounted || solicitudActual != _solicitud) return;

      setState(() {
        _items = <CatalogoItem>[];
        _cargando = false;
        _error = 'No se pudieron cargar las actividades.';
      });

      widget.onActividadesDisponibles?.call(<String>[]);
      widget.onEstadoCarga?.call(false);
    }
  }

  @override
  void dispose() {
    _solicitud++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null || _items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _error ?? 'No hay actividades disponibles.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }

    final Map<String, CatalogoItem> itemsPorClave =
        <String, CatalogoItem>{
      for (final CatalogoItem item in _items)
        item.clave: item,
    };

    final Map<String, IconData> iconosOriginales =
        <String, IconData>{
      for (final OpcionCatalogo opcion in actividadesRuta)
        opcion.clave: opcion.icono,
    };

    final List<OpcionCatalogo> opciones =
        <OpcionCatalogo>[
      for (final CatalogoItem item in _items)
        OpcionCatalogo(
          item.clave,
          iconosOriginales[item.clave] ??
              Icons.directions_outlined,
        ),
    ];

    return FqSelectorOpciones(
      opciones: opciones,
      etiqueta: (String clave) {
        if (iconosOriginales.containsKey(clave)) {
          return actividadLabel(l10n, clave);
        }

        return itemsPorClave[clave]?.nombre ?? clave;
      },
      seleccion: widget.seleccion,
      onToggle: (String clave) {
        final Set<String> nuevaSeleccion =
            Set<String>.of(widget.seleccion);

        if (!nuevaSeleccion.remove(clave)) {
          nuevaSeleccion.add(clave);
        }

        widget.onChanged(nuevaSeleccion);
      },
      errorTexto: widget.errorTexto,
    );
  }
}
