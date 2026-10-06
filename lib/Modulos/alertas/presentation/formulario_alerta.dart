import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/catalogos/tipos_alerta.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/fq_selector_opciones.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta.dart';
import 'package:fit_quest_go/Modulos/alertas/data/alerta_api.dart';
import 'package:fit_quest_go/Modulos/rutas/data/rutas_l10n.dart';

/// Formulario para reportar una alerta (contenido del bottom sheet que abre la
/// pulsacion larga del mapa). El tipo se elige de una lista cerrada, no se
/// escribe: solo con "Otro" se pide el texto. Al publicar cierra la hoja con
/// la alerta creada (`Navigator.pop`).
class FormularioAlerta extends StatefulWidget {
  const FormularioAlerta({
    super.key,
    required this.api,
    required this.lat,
    required this.lng,
  });

  final AlertaApi api;
  final double lat;
  final double lng;

  @override
  State<FormularioAlerta> createState() => _FormularioAlertaState();
}

class _FormularioAlertaState extends State<FormularioAlerta> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _tipoOtro = TextEditingController();
  final TextEditingController _descripcion = TextEditingController();

  String? _tipo;
  String _gravedad = 'media';
  bool _faltaTipo = false;
  bool _enviando = false;

  @override
  void dispose() {
    _tipoOtro.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _publicar(AppLocalizations l10n) async {
    final bool formularioOk = _formKey.currentState?.validate() ?? false;
    if (_tipo == null) {
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
      if (mounted) Navigator.of(context).pop(creada);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.comunNoSePudoEnviar('$e'))),
      );
    }
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
                l10n.homeReportarAlerta,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.lat.toStringAsFixed(5)}, ${widget.lng.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 11, color: FqColors.muted),
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
              FqSelectorOpciones(
                opciones: tiposAlerta,
                etiqueta: (String clave) => tipoAlertaLabel(l10n, clave),
                seleccion: _tipo == null ? const <String>{} : <String>{_tipo!},
                onToggle: (String clave) => setState(() {
                  _tipo = clave;
                  _faltaTipo = false;
                }),
                errorTexto: _faltaTipo ? l10n.alertasElegiUnTipo : null,
              ),
              if (_tipo == claveOtro) ...<Widget>[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tipoOtro,
                  maxLength: 50,
                  decoration: InputDecoration(
                    labelText: l10n.alertasTipoOtroLabel,
                    hintText: l10n.alertasTipoOtroHint,
                  ),
                  validator: (String? v) =>
                      (v == null || v.trim().isEmpty) ? l10n.comunObligatorio : null,
                ),
              ],
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _gravedad,
                decoration: InputDecoration(labelText: l10n.homeGravedad),
                items: <DropdownMenuItem<String>>[
                  for (final String g in const <String>['baja', 'media', 'alta'])
                    DropdownMenuItem<String>(
                      value: g,
                      child: Text(gravedadLabel(l10n, g)),
                    ),
                ],
                onChanged: (String? v) => setState(() => _gravedad = v ?? _gravedad),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descripcion,
                decoration: InputDecoration(
                  labelText: l10n.comunDescripcionOpcional,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _enviando ? null : () => _publicar(l10n),
                child: Text(
                  _enviando ? l10n.comunEnviando : l10n.homePublicarAlerta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
