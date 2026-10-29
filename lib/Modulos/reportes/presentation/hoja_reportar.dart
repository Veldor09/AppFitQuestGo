import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/widgets/ficha_lugar.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/reporte_contenido_api.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';

enum TipoReportable {
  nodo('nodo'),
  evento('evento'),
  ruta('ruta'),
  alerta('alerta');

  const TipoReportable(this.clave);

  final String clave;
}

const String motivoOfensivo = 'ofensivo';
const String motivoFalso = 'falso';
const String motivoSpam = 'spam';
const String motivoFotoInapropiada = 'foto_inapropiada';
const String motivoOtro = 'otro';

String motivoReporteLabel(AppLocalizations l10n, String clave) {
  switch (clave) {
    case motivoOfensivo:
      return l10n.reportarMotivoOfensivo;
    case motivoFalso:
      return l10n.reportarMotivoFalso;
    case motivoSpam:
      return l10n.reportarMotivoSpam;
    case motivoFotoInapropiada:
      return l10n.reportarMotivoFoto;
    case motivoOtro:
      return l10n.reportarMotivoOtro;
    default:
      return clave;
  }
}

bool puedeReportar(BuildContext context, int? creadoPorId) {
  final int? yo = AuthScope.maybeOf(context)?.usuario?.id;
  return yo != null && yo != creadoPorId;
}

Future<bool> mostrarHojaReportar(
  BuildContext context, {
  required TipoReportable tipo,
  required int contenidoId,
  required String nombre,
  bool esFoto = false,
  ReporteContenidoApi? api,
}) async {
  final bool? enviado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: formaFichaLugar,
    builder: (BuildContext _) => HojaReportar(
      tipo: tipo,
      contenidoId: contenidoId,
      nombre: nombre,
      esFoto: esFoto,
      api: api,
    ),
  );
  return enviado == true;
}

class HojaReportar extends StatefulWidget {
  const HojaReportar({
    super.key,
    required this.tipo,
    required this.contenidoId,
    required this.nombre,
    this.esFoto = false,
    this.api,
  });

  final TipoReportable tipo;
  final int contenidoId;
  final String nombre;
  final bool esFoto;

  final ReporteContenidoApi? api;

  @override
  State<HojaReportar> createState() => _HojaReportarState();
}

class _HojaReportarState extends State<HojaReportar> {
  late final ReporteContenidoApi _api = widget.api ?? ReporteContenidoApi();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _descripcion = TextEditingController();

  late String _motivo = widget.esFoto ? motivoFotoInapropiada : motivoOfensivo;
  bool _enviando = false;

  List<String> get _motivos => widget.esFoto
      ? const <String>[motivoFotoInapropiada, motivoOtro]
      : const <String>[motivoOfensivo, motivoFalso, motivoSpam, motivoOtro];

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _enviando = true);
    try {
      await _api.crear(
        tipoContenido: widget.tipo.clave,
        contenidoId: widget.contenidoId,
        motivo: _motivo,
        descripcion: _descripcion.text,
        esFoto: widget.esFoto,
      );
      if (!mounted) return;
      notificarExito(l10n.reportarEnviado);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      notificarError(switch (e.statusCode) {
        409 => l10n.reportarYaReportado,
        403 => l10n.reportarPropio,
        _ => l10n.reportarError,
      });
      if (e.statusCode == 409 || e.statusCode == 403) {
        Navigator.of(context).pop(false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      notificarError(l10n.reportarError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool obligatoria = _motivo == motivoOtro;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CabeceraFicha(
                titulo: widget.esFoto
                    ? l10n.reportarTituloFoto
                    : l10n.reportarTitulo,
                subtitulo: widget.nombre,
                icono: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: FqColors.risk.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.flag_rounded, color: FqColors.risk),
                ),
              ),
              const SizedBox(height: 14),
              RadioGroup<String>(
                groupValue: _motivo,
                onChanged: (String? v) {
                  if (v != null && !_enviando) setState(() => _motivo = v);
                },
                child: Column(
                  children: <Widget>[
                    for (final String m in _motivos)
                      RadioListTile<String>(
                        key: ValueKey<String>('motivo-$m'),
                        value: m,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          motivoReporteLabel(l10n, m),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                key: const ValueKey<String>('reporte-descripcion'),
                controller: _descripcion,
                enabled: !_enviando,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: obligatoria
                      ? l10n.reportarDescripcionObligatoria
                      : l10n.reportarDescripcionLabel,
                ),
                validator: (String? v) => obligatoria &&
                        (v == null || v.trim().isEmpty)
                    ? l10n.reportarDescripcionObligatoria
                    : null,
              ),
              const SizedBox(height: 12),
              FqButton.danger(
                key: const ValueKey<String>('enviar-reporte'),
                label: l10n.reportarEnviar,
                icon: Icons.flag_rounded,
                loading: _enviando,
                onPressed: _enviando ? null : _enviar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
