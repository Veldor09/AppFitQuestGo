import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/core/moneda/formato_moneda.dart';
import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/suscripciones_admin_api.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_list_scaffold.dart';
import 'package:fit_quest_go/Modulos/patrocinio/data/plan_api.dart';

/// Gestion de suscripciones (admin): las solicitudes de plan de empresas y
/// usuarios. En Costa Rica la persona paga por SINPE Movil con su numero de
/// solicitud en el detalle; el administrador lo busca aqui, comprueba el pago y
/// activa el plan (o lo rechaza con un motivo, o suspende uno activo).
class GestionSuscripcionesScreen extends StatefulWidget {
  const GestionSuscripcionesScreen({super.key, this.api});

  /// Inyectable para pruebas.
  final SuscripcionesAdminApi? api;

  @override
  State<GestionSuscripcionesScreen> createState() =>
      _GestionSuscripcionesScreenState();
}

class _GestionSuscripcionesScreenState
    extends State<GestionSuscripcionesScreen> {
  late final SuscripcionesAdminApi _api = widget.api ?? SuscripcionesAdminApi();
  final TextEditingController _busqueda = TextEditingController();
  Timer? _espera;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  /// Pestaña -> estado que pide al servidor (null = todas).
  static const List<String?> _estados = <String?>[
    EstadoSuscripcion.solicitada,
    EstadoSuscripcion.activa,
    EstadoSuscripcion.rechazada,
    EstadoSuscripcion.suspendida,
    null,
  ];

  int _tab = 0;
  List<SuscripcionAdmin> _items = <SuscripcionAdmin>[];
  bool _cargando = true;
  String? _error;
  bool _actuando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final List<SuscripcionAdmin> datos = await _api.listar(
        estado: _estados[_tab],
        q: _busqueda.text,
      );
      if (!mounted) return;
      setState(() {
        _items = datos;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _l10n.admSusErrorCarga(_mensaje(e));
        _cargando = false;
      });
    }
  }

  String _mensaje(Object e) => e is ApiException ? e.message : '$e';

  void _alBuscar(String _) {
    // Espera a que termine de escribir antes de pedir al servidor.
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), _cargar);
  }

  String _estadoTexto(String estado) => switch (estado) {
    EstadoSuscripcion.solicitada => _l10n.admSusEstadoSolicitada,
    EstadoSuscripcion.activa => _l10n.admSusEstadoActiva,
    EstadoSuscripcion.vencida => _l10n.admSusEstadoVencida,
    EstadoSuscripcion.suspendida => _l10n.admSusEstadoSuspendida,
    EstadoSuscripcion.rechazada => _l10n.admSusEstadoRechazada,
    _ => estado,
  };

  Color _estadoColor(String estado) => switch (estado) {
    EstadoSuscripcion.activa => FqColors.trail,
    EstadoSuscripcion.solicitada => FqColors.amber,
    EstadoSuscripcion.rechazada ||
    EstadoSuscripcion.suspendida => FqColors.risk,
    _ => FqColors.muted,
  };

  String _monto(SuscripcionAdmin s) {
    if (s.monto == null) return '—';
    return formatearImporte(
      s.monto!,
      s.moneda,
      locale: Localizations.localeOf(context).toString(),
    );
  }

  String _cuenta(SuscripcionAdmin s) => s.planAudiencia == AudienciaPlan.empresa
      ? _l10n.rolEmpresa
      : _l10n.rolUsuario;

  String _fecha(DateTime? f) => f == null
      ? '—'
      : DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(f);

  Future<void> _ejecutar(Future<void> Function() accion, String exito) async {
    if (_actuando) return;
    setState(() => _actuando = true);
    final ScaffoldMessengerState mensajes = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = _l10n;
    try {
      await accion();
      mensajes.showSnackBar(SnackBar(content: Text(exito)));
    } catch (e) {
      mensajes.showSnackBar(
        SnackBar(content: Text(l10n.admSusErrorAccion(_mensaje(e)))),
      );
    } finally {
      if (mounted) {
        setState(() => _actuando = false);
        await _cargar();
      }
    }
  }

  Future<void> _aprobar(SuscripcionAdmin s) async {
    final AppLocalizations l10n = _l10n;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.comunAprobar),
        content: Text(
          l10n.admSusConfirmarAprobar(
            _monto(s),
            s.numeroSolicitud ?? l10n.admSusSinNumero,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.comunCancelar),
          ),
          FilledButton(
            key: const ValueKey<String>('confirmar-aprobar'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.comunAprobar),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _ejecutar(() => _api.aprobar(s.id), l10n.admSusAprobada);
  }

  Future<void> _rechazar(SuscripcionAdmin s) async {
    final AppLocalizations l10n = _l10n;
    final String? motivo = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => _DialogoMotivo(l10n: l10n),
    );
    if (motivo == null || !mounted) return;
    await _ejecutar(() => _api.rechazar(s.id, motivo), l10n.admSusRechazada);
  }

  Future<void> _suspender(SuscripcionAdmin s) async {
    final AppLocalizations l10n = _l10n;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.admSusSuspender),
        content: Text(l10n.admSusConfirmarSuspender(s.usuarioNombre)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.comunCancelar),
          ),
          FilledButton(
            key: const ValueKey<String>('confirmar-suspender'),
            style: FilledButton.styleFrom(backgroundColor: FqColors.risk),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.admSusSuspender),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _ejecutar(() => _api.suspender(s.id), l10n.admSusSuspendida);
  }

  Future<void> _detalle(SuscripcionAdmin s) async {
    final AppLocalizations l10n = _l10n;
    final String? accion = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        key: const ValueKey<String>('detalle-suscripcion'),
        title: Text(
          l10n.admSusDetalleTitulo(s.numeroSolicitud ?? l10n.admSusSinNumero),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Dato(l10n.admSusCampoUsuario, s.usuarioNombre),
              _Dato(l10n.comunCorreo, s.usuarioEmail),
              _Dato(l10n.admSusCampoCuenta, _cuenta(s)),
              _Dato(l10n.admSusCampoPlan, s.planNombre),
              _Dato(l10n.admSusCampoMonto, _monto(s)),
              _Dato(l10n.admSusCampoPais, s.pais),
              _Dato(l10n.perfilEstado, _estadoTexto(s.estado)),
              _Dato(l10n.admSusCampoSolicitada, _fecha(s.creadoEn)),
              if (s.iniciaEn != null && s.venceEn != null)
                _Dato(
                  l10n.admSusCampoVigencia,
                  l10n.admSusVigencia(_fecha(s.iniciaEn), _fecha(s.venceEn)),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.comunCerrar),
          ),
          if (s.estado == EstadoSuscripcion.solicitada) ...<Widget>[
            TextButton(
              key: const ValueKey<String>('accion-rechazar'),
              style: TextButton.styleFrom(foregroundColor: FqColors.risk),
              onPressed: () => Navigator.of(ctx).pop('rechazar'),
              child: Text(l10n.comunRechazar),
            ),
            FilledButton(
              key: const ValueKey<String>('accion-aprobar'),
              onPressed: () => Navigator.of(ctx).pop('aprobar'),
              child: Text(l10n.comunAprobar),
            ),
          ],
          if (s.estado == EstadoSuscripcion.activa)
            TextButton(
              key: const ValueKey<String>('accion-suspender'),
              style: TextButton.styleFrom(foregroundColor: FqColors.risk),
              onPressed: () => Navigator.of(ctx).pop('suspender'),
              child: Text(l10n.admSusSuspender),
            ),
        ],
      ),
    );
    if (!mounted) return;
    switch (accion) {
      case 'aprobar':
        await _aprobar(s);
      case 'rechazar':
        await _rechazar(s);
      case 'suspender':
        await _suspender(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = _l10n;
    return AdminListScaffold(
      searchHint: l10n.admSusBuscar,
      searchController: _busqueda,
      onSearch: _alBuscar,
      tabs: <String>[
        l10n.admTabPendientes,
        l10n.admTabActivas,
        l10n.admTabRechazadas,
        l10n.admTabSuspendidas,
        l10n.notificacionesFiltroTodas,
      ],
      tabIndex: _tab,
      onTab: (int i) {
        setState(() => _tab = i);
        _cargar();
      },
      child: AdminDataTable(
        loading: _cargando,
        error: _error,
        onRetry: _cargar,
        emptyTitle: l10n.admSusVacioTitulo,
        emptyMessage: l10n.admSusVacioMensaje,
        rows: <AdminRow>[
          for (final SuscripcionAdmin s in _items)
            AdminRow(
              icon: s.planAudiencia == AudienciaPlan.empresa
                  ? Icons.storefront_outlined
                  : Icons.person_outline,
              title: l10n.admSusFilaTitulo(
                s.numeroSolicitud ?? l10n.admSusSinNumero,
                s.usuarioNombre,
              ),
              subtitle: l10n.admSusFilaSubtitulo(
                s.planNombre,
                _monto(s),
                _cuenta(s),
              ),
              trailing: Chip(
                label: Text(
                  _estadoTexto(s.estado),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _estadoColor(s.estado),
                  ),
                ),
              ),
              onTap: _actuando ? null : () => _detalle(s),
            ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.titulo, this.valor);

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            titulo,
            style: const TextStyle(fontSize: 11, color: FqColors.muted),
          ),
          Text(
            valor,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Pide el motivo del rechazo (10 a 500 caracteres: es lo que valida el servidor).
class _DialogoMotivo extends StatefulWidget {
  const _DialogoMotivo({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  final TextEditingController _controlador = TextEditingController();
  bool _intento = false;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  bool get _valido {
    final int n = _controlador.text.trim().length;
    return n >= 10 && n <= 500;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.admSusRechazarTitulo),
      content: TextField(
        key: const ValueKey<String>('campo-motivo'),
        controller: _controlador,
        maxLines: 4,
        maxLength: 500,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: widget.l10n.admSusMotivo,
          errorText: _intento && !_valido
              ? widget.l10n.admSusMotivoError
              : null,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.l10n.comunCancelar),
        ),
        FilledButton(
          key: const ValueKey<String>('confirmar-rechazar'),
          style: FilledButton.styleFrom(backgroundColor: FqColors.risk),
          onPressed: () {
            if (!_valido) {
              setState(() => _intento = true);
              return;
            }
            Navigator.of(context).pop(_controlador.text.trim());
          },
          child: Text(widget.l10n.comunRechazar),
        ),
      ],
    );
  }
}
