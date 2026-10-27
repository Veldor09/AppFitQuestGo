import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/moneda/formato_moneda.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/patrocinio/data/plan_api.dart';

/// "Plan de patrocinio" de una cuenta de empresa: en que va su plan, o los
/// planes que puede pedir. El equipo aprueba o rechaza cada solicitud desde el
/// panel de admin y la persona recibe el aviso en la campana (y en el celular).
class PlanPatrocinioScreen extends StatefulWidget {
  const PlanPatrocinioScreen({super.key, this.api, this.pais, this.ahora});

  /// Inyectable para pruebas.
  final PlanApi? api;

  /// Codigo ISO de dos letras. Por defecto, el pais del idioma del telefono; si
  /// no tiene, Costa Rica (donde opera FitQuest Go).
  final String? pais;

  /// Reloj inyectable para pruebas.
  final DateTime Function()? ahora;

  @override
  State<PlanPatrocinioScreen> createState() => _PlanPatrocinioScreenState();
}

class _Datos {
  const _Datos({required this.suscripcion, required this.planes});
  final MiSuscripcion? suscripcion;
  final List<PlanPatrocinio> planes;
}

class _PlanPatrocinioScreenState extends State<PlanPatrocinioScreen> {
  late final PlanApi _api = widget.api ?? PlanApi();

  Future<_Datos>? _carga;
  int? _solicitando;

  DateTime get _ahora => (widget.ahora ?? DateTime.now)();

  String get _pais {
    final String? dado = widget.pais?.trim().toUpperCase();
    if (dado != null && dado.length == 2) return dado;
    final String? delTelefono = Localizations.maybeLocaleOf(
      context,
    )?.countryCode;
    return (delTelefono != null && delTelefono.length == 2)
        ? delTelefono.toUpperCase()
        : 'CR';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _carga ??= _cargar();
  }

  Future<_Datos> _cargar() async {
    final MiSuscripcion? suscripcion = await _api.miSuscripcion();
    // Con un plan vigente o una solicitud en revision no hace falta la lista.
    final bool puedePedir =
        suscripcion == null ||
        (!suscripcion.vigente &&
            suscripcion.estado != EstadoSuscripcion.solicitada);
    final List<PlanPatrocinio> planes = puedePedir
        ? await _api.planes(_pais)
        : <PlanPatrocinio>[];
    return _Datos(suscripcion: suscripcion, planes: planes);
  }

  void _recargar() {
    setState(() {
      _carga = _cargar();
    });
  }

  Future<void> _solicitar(PlanPatrocinio plan) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String locale = Localizations.localeOf(context).toString();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.planConfirmarTitulo),
        content: Text(
          l10n.planConfirmarMensaje(
            plan.nombre,
            formatearImporte(plan.importe, plan.moneda, locale: locale),
            plan.duracionDias,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.comunCancelar),
          ),
          FilledButton(
            key: const ValueKey<String>('confirmar-plan'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.planSolicitar),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _solicitando = plan.id);
    try {
      await _api.solicitar(planId: plan.id, pais: _pais);
      if (!mounted) return;
      notificarExito(l10n.planSolicitudEnviada);
    } on ApiException catch (e) {
      notificarError(
        e.statusCode == 409 ? l10n.planYaTiene : l10n.planErrorSolicitar,
      );
    } catch (_) {
      notificarError(l10n.planErrorSolicitar);
    } finally {
      if (mounted) {
        setState(() => _solicitando = null);
        // Haya salido bien o ya existiera una, lo que se ve debe ser lo real.
        _recargar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: FqColors.paper,
      appBar: AppBar(
        backgroundColor: FqColors.night,
        foregroundColor: FqColors.white,
        title: Text(
          l10n.planTitulo,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<_Datos>(
        future: _carga,
        builder: (BuildContext context, AsyncSnapshot<_Datos> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return FqEmptyState(
              icon: Icons.cloud_off_outlined,
              title: l10n.planErrorCarga,
              action: TextButton(
                onPressed: _recargar,
                child: Text(l10n.comunReintentar),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _recargar(),
            child: _contenido(snap.data!, l10n),
          );
        },
      ),
    );
  }

  Widget _contenido(_Datos datos, AppLocalizations l10n) {
    final MiSuscripcion? s = datos.suscripcion;
    final String locale = Localizations.localeOf(context).toString();
    final List<Widget> hijos = <Widget>[
      Text(
        l10n.planIntro,
        style: const TextStyle(fontSize: 12, color: FqColors.muted),
      ),
      const SizedBox(height: FqGap.lg),
    ];

    if (s != null && s.vigente) {
      final int dias = s.diasRestantes(_ahora) ?? 0;
      hijos.add(
        _Estado(
          key: const ValueKey<String>('plan-activo'),
          icono: Icons.verified_rounded,
          color: FqColors.trail,
          fondo: FqColors.evidenceBg,
          titulo: l10n.planActivoTitulo,
          detalle: s.venceEn == null
              ? s.planNombre
              : l10n.planActivoDetalle(
                  s.planNombre,
                  DateFormat.yMMMMd(locale).format(s.venceEn!),
                ),
          extra: l10n.planDiasRestantes(dias),
          ayuda: l10n.planActivoAyuda,
        ),
      );
    } else if (s != null && s.estado == EstadoSuscripcion.solicitada) {
      hijos.add(
        _Estado(
          key: const ValueKey<String>('plan-pendiente'),
          icono: Icons.hourglass_top_rounded,
          color: FqColors.amber,
          fondo: const Color(0xFFFEF3C7),
          titulo: l10n.planPendienteTitulo,
          detalle: l10n.planPendienteDetalle(s.planNombre),
        ),
      );
    } else {
      final String? aviso = switch (s?.estado) {
        EstadoSuscripcion.rechazada => l10n.planRechazadaAviso,
        EstadoSuscripcion.suspendida => l10n.planSuspendidoAviso,
        // Activa con la fecha pasada, o marcada vencida.
        EstadoSuscripcion.activa ||
        EstadoSuscripcion.vencida => l10n.planVencidoAviso,
        _ => null,
      };
      if (aviso != null) {
        hijos.add(
          _Estado(
            key: const ValueKey<String>('plan-aviso'),
            icono: Icons.info_outline_rounded,
            color: FqColors.risk,
            fondo: const Color(0xFFFEECE9),
            titulo: aviso,
          ),
        );
        hijos.add(const SizedBox(height: FqGap.lg));
      }
      hijos.add(
        Text(
          l10n.planDisponibles,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      );
      hijos.add(const SizedBox(height: FqGap.md));
      if (datos.planes.isEmpty) {
        hijos.add(
          FqEmptyState(
            icon: Icons.campaign_outlined,
            title: l10n.planSinPlanes,
            dense: true,
          ),
        );
      }
      for (final PlanPatrocinio plan in datos.planes) {
        hijos.add(
          _TarjetaPlan(
            plan: plan,
            precio: formatearImporte(plan.importe, plan.moneda, locale: locale),
            enviando: _solicitando == plan.id,
            deshabilitado: _solicitando != null,
            alSolicitar: () => _solicitar(plan),
          ),
        );
        hijos.add(const SizedBox(height: FqGap.md));
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(FqGap.xl),
      children: hijos,
    );
  }
}

class _Estado extends StatelessWidget {
  const _Estado({
    super.key,
    required this.icono,
    required this.color,
    required this.fondo,
    required this.titulo,
    this.detalle,
    this.extra,
    this.ayuda,
  });

  final IconData icono;
  final Color color;
  final Color fondo;
  final String titulo;
  final String? detalle;
  final String? extra;
  final String? ayuda;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icono, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: FqColors.ink,
                  ),
                ),
                if (detalle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(detalle!, style: const TextStyle(fontSize: 12)),
                ],
                if (extra != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    extra!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
                if (ayuda != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    ayuda!,
                    style: const TextStyle(fontSize: 11, color: FqColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaPlan extends StatelessWidget {
  const _TarjetaPlan({
    required this.plan,
    required this.precio,
    required this.enviando,
    required this.deshabilitado,
    required this.alSolicitar,
  });

  final PlanPatrocinio plan;
  final String precio;
  final bool enviando;
  final bool deshabilitado;
  final VoidCallback alSolicitar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FqColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.star_rounded, color: FqColors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                precio,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: FqColors.trail,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.planDuracion(plan.duracionDias),
            style: const TextStyle(fontSize: 11, color: FqColors.muted),
          ),
          const SizedBox(height: 12),
          FqButton.primary(
            key: ValueKey<String>('solicitar-plan-${plan.id}'),
            label: l10n.planSolicitar,
            loading: enviando,
            onPressed: deshabilitado ? null : alSolicitar,
          ),
        ],
      ),
    );
  }
}
