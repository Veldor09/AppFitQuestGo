
import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/tipos_alerta.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_selector_opciones.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogo_item.dart';
import 'package:fit_quest_go/Modulos/admin/data/catalogos_api.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';

/// Formulario para reportar una alerta.
///
/// Los tipos disponibles se consultan desde ADM-11. Las claves conocidas
/// conservan sus iconos y traducciones; las nuevas usan su nombre del backend.
class FormularioAlerta extends StatefulWidget {
  const FormularioAlerta({
    super.key,
    required this.api,
    required this.lat,
    required this.lng,
    this.catalogosApi,
  });

  final AlertaApi api;
  final double lat;
  final double lng;

  /// Permite inyectar una API simulada en las pruebas.
  final CatalogosApi? catalogosApi;

  @override
  State<FormularioAlerta> createState() => _FormularioAlertaState();
}

class _FormularioAlertaState extends State<FormularioAlerta> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _tipoOtro = TextEditingController();
  final TextEditingController _descripcion = TextEditingController();

  late final CatalogosApi _catalogosApi;

  List<OpcionCatalogo> _opciones = <OpcionCatalogo>[];
  Map<String, String> _nombresCatalogo = <String, String>{};

  String? _tipo;
  String _gravedad = 'media';
  String? _errorCatalogo;

  bool _faltaTipo = false;
  bool _enviando = false;
  bool _cargandoCatalogo = true;

  int _versionCarga = 0;

  @override
  void initState() {
    super.initState();
    _catalogosApi = widget.catalogosApi ?? CatalogosApi();
    _cargarTiposAlerta();
  }

  @override
  void dispose() {
    _versionCarga++;
    _tipoOtro.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _cargarTiposAlerta() async {
    final int version = ++_versionCarga;

    setState(() {
      _cargandoCatalogo = true;
      _errorCatalogo = null;
      _opciones = <OpcionCatalogo>[];
      _nombresCatalogo = <String, String>{};
      _tipo = null;
      _faltaTipo = false;
    });

    try {
      final List<CatalogoItem> items =
          await _catalogosApi.listarItemsActivos('alertas');

      if (!mounted || version != _versionCarga) return;

      final Map<String, IconData> iconosConocidos =
          <String, IconData>{
        for (final OpcionCatalogo opcion in tiposAlerta)
          opcion.clave: opcion.icono,
      };

      final List<OpcionCatalogo> opciones = <OpcionCatalogo>[];
      final Map<String, String> nombres = <String, String>{};
      final Set<String> clavesAgregadas = <String>{};

      for (final CatalogoItem item in items) {
        if (!item.activo || !clavesAgregadas.add(item.clave)) {
          continue;
        }

        opciones.add(
          OpcionCatalogo(
            item.clave,
            iconosConocidos[item.clave] ?? Icons.category_outlined,
          ),
        );

        nombres[item.clave] = item.nombre;
      }

      setState(() {
        _opciones = opciones;
        _nombresCatalogo = nombres;
        _cargandoCatalogo = false;
      });
    } catch (error) {
      if (!mounted || version != _versionCarga) return;

      setState(() {
        _errorCatalogo = error.toString();
        _cargandoCatalogo = false;
      });
    }
  }

  String _etiquetaTipo(AppLocalizations l10n, String clave) {
    final bool esTipoConocido = tiposAlerta.any(
      (OpcionCatalogo opcion) => opcion.clave == clave,
    );

    if (esTipoConocido) {
      return tipoAlertaLabel(l10n, clave);
    }

    return _nombresCatalogo[clave] ?? clave;
  }

  Future<void> _publicar(AppLocalizations l10n) async {
    if (_enviando || _cargandoCatalogo || _errorCatalogo != null) {
      return;
    }

    final bool tipoDisponible = _tipo != null &&
        _opciones.any(
          (OpcionCatalogo opcion) => opcion.clave == _tipo,
        );

    final bool formularioOk =
        _formKey.currentState?.validate() ?? false;

    if (!tipoDisponible) {
      setState(() => _faltaTipo = true);
      return;
    }

    if (!formularioOk) return;

    setState(() => _enviando = true);

    try {
      final Alerta creada = await widget.api.reportar(
        tipo: _tipo!,
        tipoOtro: _tipo == claveOtro ? _tipoOtro.text : null,
        gravedad: _gravedad,
        lat: widget.lat,
        lng: widget.lng,
        descripcion: _descripcion.text,
      );

      if (mounted) {
        Navigator.of(context).pop(creada);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() => _enviando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.comunNoSePudoEnviar('$error'),
          ),
        ),
      );
    }
  }

  Widget _construirSelector(AppLocalizations l10n) {
    if (_cargandoCatalogo) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorCatalogo != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'No se pudieron cargar los tipos de alerta.',
            style: TextStyle(
              color: FqColors.risk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _cargarTiposAlerta,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }

    if (_opciones.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'No hay tipos de alerta disponibles.',
            style: TextStyle(
              color: FqColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _cargarTiposAlerta,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar'),
          ),
        ],
      );
    }

    return FqSelectorOpciones(
      opciones: _opciones,
      etiqueta: (String clave) => _etiquetaTipo(l10n, clave),
      seleccion: _tipo == null
          ? const <String>{}
          : <String>{_tipo!},
      onToggle: (String clave) {
        if (_enviando) return;

        setState(() {
          _tipo = clave;
          _faltaTipo = false;
        });
      },
      errorTexto: _faltaTipo ? l10n.alertasElegiUnTipo : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    final bool puedePublicar = !_enviando &&
        !_cargandoCatalogo &&
        _errorCatalogo == null &&
        _opciones.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.homeReportarAlerta,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.lat.toStringAsFixed(5)}, '
                '${widget.lng.toStringAsFixed(5)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: FqColors.muted,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.homeTipo,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: FqColors.muted,
                ),
              ),
              const SizedBox(height: 8),

              _construirSelector(l10n),

              if (_tipo == claveOtro &&
                  !_cargandoCatalogo &&
                  _errorCatalogo == null) ...<Widget>[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tipoOtro,
                  maxLength: 50,
                  decoration: InputDecoration(
                    labelText: l10n.alertasTipoOtroLabel,
                    hintText: l10n.alertasTipoOtroHint,
                  ),
                  validator: (String? valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return l10n.comunObligatorio;
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _gravedad,
                decoration: InputDecoration(
                  labelText: l10n.homeGravedad,
                ),
                items: <DropdownMenuItem<String>>[
                  for (final String gravedad
                      in const <String>['baja', 'media', 'alta'])
                    DropdownMenuItem<String>(
                      value: gravedad,
                      child: Text(
                        gravedadLabel(l10n, gravedad),
                      ),
                    ),
                ],
                onChanged: _enviando
                    ? null
                    : (String? valor) {
                        setState(() {
                          _gravedad = valor ?? _gravedad;
                        });
                      },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descripcion,
                enabled: !_enviando,
                decoration: InputDecoration(
                  labelText: l10n.comunDescripcionOpcional,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: puedePublicar
                    ? () => _publicar(l10n)
                    : null,
                child: Text(
                  _enviando
                      ? l10n.comunEnviando
                      : l10n.homePublicarAlerta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
