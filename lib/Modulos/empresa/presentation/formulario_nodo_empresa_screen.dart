import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/catalogos/categorias_nodo.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_selector_opciones.dart';
import 'package:fit_quest_go/core/widgets/selector_ubicacion_mapa.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/presentation/widgets/fq_app_header.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

/// Construye el selector de ubicacion. Las pruebas lo reemplazan por uno falso
/// que "toca" el mapa sin Mapbox.
typedef ConstructorSelectorUbicacion =
    Widget Function(
      BuildContext context,
      ({double lat, double lng})? inicial,
      void Function(double lat, double lng) onCambio,
    );

/// Alta o edicion de un nodo desde el panel "Mis nodos".
///
/// Como empresa (modulo 5, Nodo de Abastecimiento): pone el nombre del comercio,
/// elige la categoria, marca su local en el mapa y escribe el cupon o beneficio
/// que ofrece. Sale publicado al guardar.
///
/// Como deportista ([esEmpresa] en false): propone un punto de interes (nombre,
/// categoria, descripcion y lugar en el mapa), sin beneficio. Queda pendiente
/// hasta que un admin lo revisa.
class FormularioNodoEmpresaScreen extends StatefulWidget {
  const FormularioNodoEmpresaScreen({
    super.key,
    this.api,
    this.nodo,
    this.selectorBuilder,
    this.esEmpresa = true,
  });

  /// Inyectable para pruebas; en produccion se crea uno por defecto.
  final NodoApi? api;

  /// El nodo a editar; null para crear uno nuevo.
  final Nodo? nodo;

  final ConstructorSelectorUbicacion? selectorBuilder;

  /// Quien lo usa. Con false no hay beneficio y el punto queda pendiente.
  final bool esEmpresa;

  @override
  State<FormularioNodoEmpresaScreen> createState() =>
      _FormularioNodoEmpresaScreenState();
}

class _FormularioNodoEmpresaScreenState
    extends State<FormularioNodoEmpresaScreen> {
  late final NodoApi _api = widget.api ?? NodoApi();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre = TextEditingController(
    text: widget.nodo?.nombre,
  );
  late final TextEditingController _categoriaOtro = TextEditingController(
    text: widget.nodo?.categoriaOtro,
  );
  late final TextEditingController _descripcion = TextEditingController(
    text: widget.nodo?.descripcion,
  );
  late final TextEditingController _beneficio = TextEditingController(
    text: widget.nodo?.beneficio,
  );

  late String? _categoria = widget.nodo?.categoria;
  late ({double lat, double lng})? _ubicacion = widget.nodo == null
      ? null
      : (lat: widget.nodo!.lat, lng: widget.nodo!.lng);
  bool _faltaCategoria = false;
  bool _faltaUbicacion = false;
  bool _guardando = false;

  bool get _esEdicion => widget.nodo != null;

  @override
  void dispose() {
    _nombre.dispose();
    _categoriaOtro.dispose();
    _descripcion.dispose();
    _beneficio.dispose();
    super.dispose();
  }

  void _alCambiarUbicacion(double lat, double lng) {
    setState(() {
      _ubicacion = (lat: lat, lng: lng);
      _faltaUbicacion = false;
    });
  }

  Future<void> _guardar() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    final bool formularioOk = _formKey.currentState?.validate() ?? false;
    final ({double lat, double lng})? ubicacion = _ubicacion;
    if (_categoria == null || ubicacion == null || !formularioOk) {
      setState(() {
        _faltaCategoria = _categoria == null;
        _faltaUbicacion = ubicacion == null;
      });
      notificarError(l10n.comunRevisaCampos);
      return;
    }

    setState(() => _guardando = true);
    try {
      final Nodo guardado = _esEdicion
          ? await _api.actualizar(
              widget.nodo!.id,
              nombre: _nombre.text.trim(),
              categoria: _categoria!,
              categoriaOtro: _categoriaOtro.text,
              lat: ubicacion.lat,
              lng: ubicacion.lng,
              descripcion: _descripcion.text,
              beneficio: _beneficio.text,
            )
          : await _api.proponer(
              nombre: _nombre.text.trim(),
              categoria: _categoria!,
              categoriaOtro: _categoriaOtro.text,
              lat: ubicacion.lat,
              lng: ubicacion.lng,
              descripcion: _descripcion.text,
              beneficio: widget.esEmpresa ? _beneficio.text : null,
            );
      if (!mounted) return;
      notificarExito(
        widget.esEmpresa ? l10n.nodoEmpresaGuardado : l10n.nodoUsuarioEnviado,
      );
      Navigator.of(context).pop(guardado);
    } on ApiException catch (e) {
      _fallar(e.message);
    } catch (_) {
      _fallar(l10n.nodoEmpresaErrorGuardar);
    }
  }

  void _fallar(String mensaje) {
    if (!mounted) return;
    setState(() => _guardando = false);
    notificarError(mensaje);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: FqColors.paper,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FqAppHeader(
              title: _esEdicion
                  ? l10n.nodoEmpresaEditarTitulo
                  : widget.esEmpresa
                  ? l10n.nodoEmpresaNuevoTitulo
                  : l10n.nodoUsuarioNuevoTitulo,
              onLeading: _guardando
                  ? null
                  : () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  FqGap.xl,
                  14,
                  FqGap.xl,
                  FqGap.xl,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextFormField(
                        key: const ValueKey<String>('campo-nombre-nodo'),
                        controller: _nombre,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: widget.esEmpresa
                              ? l10n.nodoEmpresaNombreLabel
                              : l10n.nodoUsuarioNombreLabel,
                        ),
                        validator: (String? v) =>
                            (v == null || v.trim().isEmpty)
                            ? l10n.comunObligatorio
                            : null,
                      ),
                      const SizedBox(height: 6),
                      _titulo(l10n.homeCategoria),
                      const SizedBox(height: 8),
                      FqSelectorOpciones(
                        opciones: categoriasNodo,
                        etiqueta: (String clave) =>
                            categoriaNodoLabel(l10n, clave),
                        seleccion: _categoria == null
                            ? const <String>{}
                            : <String>{_categoria!},
                        onToggle: (String clave) => setState(() {
                          _categoria = clave;
                          _faltaCategoria = false;
                        }),
                        errorTexto: _faltaCategoria
                            ? l10n.nodosElegiCategoria
                            : null,
                      ),
                      if (_categoria == claveOtro) ...<Widget>[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _categoriaOtro,
                          maxLength: 50,
                          decoration: InputDecoration(
                            labelText: l10n.nodosCategoriaOtroLabel,
                            hintText: l10n.nodosCategoriaOtroHint,
                          ),
                          validator: (String? v) =>
                              (v == null || v.trim().isEmpty)
                              ? l10n.comunObligatorio
                              : null,
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (widget.esEmpresa) ...<Widget>[
                        TextFormField(
                          key: const ValueKey<String>('campo-beneficio-nodo'),
                          controller: _beneficio,
                          maxLength: 300,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: l10n.nodoEmpresaBeneficioLabel,
                            hintText: l10n.nodoEmpresaBeneficioHint,
                            prefixIcon: const Icon(Icons.local_offer_outlined),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descripcion,
                        maxLength: 500,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: l10n.comunDescripcionOpcional,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _titulo(l10n.nodoEmpresaUbicacionTitulo),
                      const SizedBox(height: 4),
                      Text(
                        _ubicacion == null
                            ? l10n.nodoEmpresaUbicacionAyuda
                            : '${_ubicacion!.lat.toStringAsFixed(5)}, ${_ubicacion!.lng.toStringAsFixed(5)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _faltaUbicacion
                              ? FqColors.risk
                              : FqColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: FqRadius.allLg,
                        child: SizedBox(
                          height: 240,
                          child: widget.selectorBuilder != null
                              ? widget.selectorBuilder!(
                                  context,
                                  _ubicacion,
                                  _alCambiarUbicacion,
                                )
                              : SelectorUbicacionMapa(
                                  inicial: _ubicacion,
                                  onCambio: _alCambiarUbicacion,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FqGap.xl,
                8,
                FqGap.xl,
                FqGap.xl,
              ),
              child: FqButton.primary(
                key: const ValueKey<String>('guardar-nodo-empresa'),
                label: l10n.comunGuardar,
                loading: _guardando,
                onPressed: _guardando ? null : _guardar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titulo(String texto) => Text(
    texto,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: FqColors.muted,
    ),
  );
}
