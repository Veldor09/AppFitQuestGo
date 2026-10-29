import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/moneda/formato_moneda.dart';
import 'package:fit_quest_go/core/notificaciones/notificaciones.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/core/theme/fq_tokens.dart';
import 'package:fit_quest_go/core/widgets/fq_button.dart';
import 'package:fit_quest_go/core/widgets/fq_empty_state.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/auth/application/auth_scope.dart';
import 'package:fit_quest_go/Modulos/patrocinio/application/plan_usuario.dart';
import 'package:fit_quest_go/Modulos/patrocinio/data/plan_api.dart';

/// La suscripcion de quien usa la app: "Plan de patrocinio" para una cuenta de
/// empresa (destacar) y "Mi suscripcion" para un usuario normal (guardar mas
/// rutas sin conexion).
///
/// Muestra en que va el plan o los planes que se pueden pedir. En Costa Rica el
/// pago es por SINPE Movil: la pantalla da el numero de solicitud y los pasos;
/// un administrador activa el plan al recibir el comprobante. Fuera de Costa
/// Rica el pago sera por PayPal, que aun no esta configurado.
class PlanPatrocinioScreen extends StatefulWidget {
  const PlanPatrocinioScreen({
    super.key,
    this.api,
    this.pais,
    this.ahora,
    this.esEmpresa,
    this.nombre,
  });

  /// Inyectable para pruebas.
  final PlanApi? api;

  /// Codigo ISO de dos letras. Por defecto, la region del telefono; si no tiene,
  /// Costa Rica (donde opera FitQuest Go).
  final String? pais;

  /// Reloj inyectable para pruebas.
  final DateTime Function()? ahora;

  /// Por defecto sale de la sesion (rol Empresa).
  final bool? esEmpresa;

  /// Nombre que va en el detalle del pago; por defecto el de la sesion.
  final String? nombre;

  @override
  State<PlanPatrocinioScreen> createState() => _PlanPatrocinioScreenState();
}

class _Datos {
  const _Datos({required this.suscripcion, required this.respuesta});
  final MiSuscripcion? suscripcion;

  /// Los planes que se pueden pedir; null cuando no hace falta (plan vigente o
  /// solicitud en revision).
  final RespuestaPlanes? respuesta;
}

class _PlanPatrocinioScreenState extends State<PlanPatrocinioScreen> {
  late final PlanApi _api = widget.api ?? PlanApi();

  Future<_Datos>? _carga;
  int? _solicitando;

  DateTime get _ahora => (widget.ahora ?? DateTime.now)();

  bool get _esEmpresa =>
      widget.esEmpresa ??
      (AuthScope.maybeOf(context)?.usuario?.esEmpresa ?? false);

  String get _nombre =>
      widget.nombre ?? AuthScope.maybeOf(context)?.usuario?.nombre ?? '';

  String get _pais {
    final String? dado = widget.pais?.trim().toUpperCase();
    if (dado != null && dado.length == 2) return dado;
    // La region del telefono, no el idioma de la app: la app resuelve "en-US" a
    // "en" (sin pais) y todos caerian en Costa Rica.
    final String? delTelefono =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
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
    // Aprovecha para que las descargas offline sepan si hay plan de usuario.
    if (!_esEmpresa) unawaited(PlanUsuario.instancia.recordar(suscripcion));
    // Con un plan vigente o una solicitud en revision no hace falta la lista.
    final bool puedePedir =
        suscripcion == null ||
        (!suscripcion.vigente &&
            suscripcion.estado != EstadoSuscripcion.solicitada);
    return _Datos(
      suscripcion: suscripcion,
      respuesta: puedePedir ? await _api.planes(_pais) : null,
    );
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
      notificarError(switch ((e.statusCode, e.message)) {
        (409, _) => l10n.planYaTiene,
        (400, 'PAGO_NO_DISPONIBLE') => l10n.planPagoNoDisponible,
        (403, 'PLAN_NO_APLICA') => l10n.planNoAplica,
        _ => l10n.planErrorSolicitar,
      });
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

  Future<void> _copiarDetalle(String numeroSolicitud) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String nombre = _nombre.trim();
    await Clipboard.setData(
      ClipboardData(
        text: nombre.isEmpty ? numeroSolicitud : '$numeroSolicitud $nombre',
      ),
    );
    if (mounted) notificarExito(l10n.planDetalleCopiado);
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
          _esEmpresa ? l10n.planTitulo : l10n.planTituloUsuario,
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
        _esEmpresa
            ? l10n.planIntro
            : l10n.planIntroUsuario(
                kLimiteRutasOfflineSuscrito,
                kLimiteRutasOfflineGratis,
              ),
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
          ayuda: _esEmpresa
              ? l10n.planActivoAyuda
              : l10n.planActivoAyudaUsuario(kLimiteRutasOfflineSuscrito),
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
      if (s.metodoPago == MetodoPago.sinpe &&
          s.numeroSolicitud != null &&
          s.monto != null) {
        hijos.add(const SizedBox(height: FqGap.lg));
        hijos.add(
          _InstruccionesSinpe(
            numeroSolicitud: s.numeroSolicitud!,
            numeroSinpe: s.sinpeNumero ?? '',
            monto: formatearImporte(
              s.monto!,
              s.moneda ?? 'CRC',
              locale: locale,
            ),
            alCopiar: () => _copiarDetalle(s.numeroSolicitud!),
          ),
        );
      }
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
      final RespuestaPlanes respuesta =
          datos.respuesta ?? const RespuestaPlanes(planes: <PlanPatrocinio>[]);
      if (!respuesta.pagoDisponible) {
        hijos.add(
          _Estado(
            key: const ValueKey<String>('plan-paypal'),
            icono: Icons.public_rounded,
            color: FqColors.river,
            fondo: FqColors.infoNoteBg,
            titulo: l10n.planPaypalProximamente,
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
      if (respuesta.planes.isEmpty) {
        hijos.add(
          FqEmptyState(
            icon: Icons.campaign_outlined,
            title: l10n.planSinPlanes,
            dense: true,
          ),
        );
      }
      for (final PlanPatrocinio plan in respuesta.planes) {
        hijos.add(
          _TarjetaPlan(
            plan: plan,
            precio: formatearImporte(plan.importe, plan.moneda, locale: locale),
            enviando: _solicitando == plan.id,
            deshabilitado: _solicitando != null,
            noDisponible: !respuesta.pagoDisponible,
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

/// Los pasos del pago por SINPE Movil, con el numero de solicitud bien visible.
class _InstruccionesSinpe extends StatelessWidget {
  const _InstruccionesSinpe({
    required this.numeroSolicitud,
    required this.numeroSinpe,
    required this.monto,
    required this.alCopiar,
  });

  final String numeroSolicitud;
  final String numeroSinpe;
  final String monto;
  final VoidCallback alCopiar;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      key: const ValueKey<String>('instrucciones-sinpe'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FqColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.planPagoTitulo,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.planNumeroSolicitud,
            style: const TextStyle(fontSize: 11, color: FqColors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            numeroSolicitud,
            key: const ValueKey<String>('numero-solicitud'),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              color: FqColors.trail,
            ),
          ),
          const SizedBox(height: 12),
          _Paso(
            numero: 1,
            texto: l10n.planPagoPaso1(_conGuion(numeroSinpe), monto),
          ),
          _Paso(numero: 2, texto: l10n.planPagoPaso2(numeroSolicitud)),
          _Paso(numero: 3, texto: l10n.planPagoPaso3(_conGuion(numeroSinpe))),
          const SizedBox(height: 6),
          FqButton.secondary(
            key: const ValueKey<String>('copiar-detalle'),
            label: l10n.planCopiarDetalle,
            icon: Icons.copy_rounded,
            onPressed: alCopiar,
          ),
        ],
      ),
    );
  }

  /// 83722969 -> 8372-2969 (como se dicta un numero de telefono).
  static String _conGuion(String n) =>
      n.length == 8 ? '${n.substring(0, 4)}-${n.substring(4)}' : n;
}

class _Paso extends StatelessWidget {
  const _Paso({required this.numero, required this.texto});

  final int numero;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: FqColors.volt,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$numero',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: FqColors.primaryInk,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 12.5))),
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
    required this.noDisponible,
    required this.alSolicitar,
  });

  final PlanPatrocinio plan;
  final String precio;
  final bool enviando;
  final bool deshabilitado;

  /// El pago de esta region aun no esta listo: se ve el plan pero no se pide.
  final bool noDisponible;
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
            label: noDisponible
                ? l10n.planProntoDisponible
                : l10n.planSolicitar,
            loading: enviando,
            onPressed: (deshabilitado || noDisponible) ? null : alSolicitar,
          ),
        ],
      ),
    );
  }
}
