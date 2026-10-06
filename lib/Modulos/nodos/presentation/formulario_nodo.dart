import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/categorias_nodo.dart';
import 'package:fit_quest_go/core/fotos/selector_foto.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_selector_opciones.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';

/// Formulario para proponer un punto de interes (contenido del bottom sheet
/// que abre la pulsacion larga del mapa). La categoria se elige de una lista
/// cerrada (solo "Otro" pide texto) y la foto es opcional: primero se crea el
/// punto y despues se sube la foto a su id. Si la foto falla, el punto igual
/// queda enviado y se avisa. Al terminar cierra la hoja con el [Nodo] creado.
class FormularioNodo extends StatefulWidget {
  const FormularioNodo({
    super.key,
    required this.api,
    required this.lat,
    required this.lng,
    this.selectorFoto,
  });

  final NodoApi api;
  final double lat;
  final double lng;

  /// Inyectable para pruebas; en produccion usa `image_picker`.
  final SelectorFoto? selectorFoto;

  @override
  State<FormularioNodo> createState() => _FormularioNodoState();
}

class _FormularioNodoState extends State<FormularioNodo> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _categoriaOtro = TextEditingController();
  final TextEditingController _descripcion = TextEditingController();

  late final SelectorFoto _selectorFoto =
      widget.selectorFoto ?? SelectorFotoImagePicker();

  String? _categoria;
  Uint8List? _foto;
  bool _faltaCategoria = false;
  bool _enviando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _categoriaOtro.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto(OrigenFoto origen) async {
    final Uint8List? bytes = await _selectorFoto.elegir(origen);
    if (bytes != null && mounted) setState(() => _foto = bytes);
  }

  Future<void> _enviar(AppLocalizations l10n) async {
    final bool formularioOk = _formKey.currentState?.validate() ?? false;
    if (_categoria == null) {
      setState(() => _faltaCategoria = true);
      return;
    }
    if (!formularioOk) return;

    setState(() => _enviando = true);
    Nodo nodo;
    try {
      nodo = await widget.api.proponer(
        nombre: _nombre.text.trim(),
        categoria: _categoria!,
        categoriaOtro: _categoria == claveOtro ? _categoriaOtro.text : null,
        lat: widget.lat,
        lng: widget.lng,
        descripcion: _descripcion.text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.comunNoSePudoEnviar('$e'))),
      );
      return;
    }

    final Uint8List? foto = _foto;
    if (foto != null) {
      try {
        nodo = await widget.api.subirFoto(nodo.id, foto);
      } catch (_) {
        // El punto ya esta enviado; solo la foto quedo pendiente.
        notificarError(l10n.nodosFotoNoSubida);
      }
    }
    if (mounted) Navigator.of(context).pop(nodo);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
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
                l10n.homeProponerPunto,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.lat.toStringAsFixed(5)}, ${widget.lng.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 11, color: FqColors.muted),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombre,
                decoration: InputDecoration(labelText: l10n.comunNombre),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? l10n.comunObligatorio : null,
              ),
              const SizedBox(height: 14),
              _etiquetaSeccion(l10n.homeCategoria),
              const SizedBox(height: 8),
              FqSelectorOpciones(
                opciones: categoriasNodo,
                etiqueta: (String clave) => categoriaNodoLabel(l10n, clave),
                seleccion: _categoria == null ? const <String>{} : <String>{_categoria!},
                onToggle: (String clave) => setState(() {
                  _categoria = clave;
                  _faltaCategoria = false;
                }),
                errorTexto: _faltaCategoria ? l10n.nodosElegiCategoria : null,
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
                      (v == null || v.trim().isEmpty) ? l10n.comunObligatorio : null,
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(
                controller: _descripcion,
                decoration: InputDecoration(
                  labelText: l10n.comunDescripcionOpcional,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              _etiquetaSeccion(l10n.nodosFotoTitulo),
              const SizedBox(height: 8),
              _seccionFoto(l10n),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _enviando ? null : () => _enviar(l10n),
                child: Text(_enviando ? l10n.comunEnviando : l10n.comunEnviar),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _etiquetaSeccion(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: FqColors.muted,
      ),
    );
  }

  Widget _seccionFoto(AppLocalizations l10n) {
    final Uint8List? foto = _foto;
    if (foto == null) {
      return Row(
        children: <Widget>[
          Expanded(
            child: FqButton.secondary(
              label: l10n.nodosFotoCamara,
              icon: Icons.photo_camera_outlined,
              dense: true,
              onPressed: _enviando ? null : () => _elegirFoto(OrigenFoto.camara),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FqButton.secondary(
              label: l10n.nodosFotoGaleria,
              icon: Icons.photo_library_outlined,
              dense: true,
              onPressed: _enviando ? null : () => _elegirFoto(OrigenFoto.galeria),
            ),
          ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(foto, width: 88, height: 88, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: _enviando ? null : () => setState(() => _foto = null),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: Text(l10n.nodosFotoQuitar),
        ),
      ],
    );
  }
}
