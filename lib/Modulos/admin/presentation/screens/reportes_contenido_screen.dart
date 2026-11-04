import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/widgets/foto_remota.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/reporte_contenido_api.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_list_scaffold.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_detail_dialog.dart';
import 'package:fit_quest_go/Modulos/eventos/data/evento_api.dart';
import 'package:fit_quest_go/Modulos/nodos/data/nodo_api.dart';
import 'package:fit_quest_go/Modulos/reportes/presentation/hoja_reportar.dart';

class ReportesContenidoScreen extends StatefulWidget {
  const ReportesContenidoScreen({
    super.key,
    this.api,
    this.nodoApi,
    this.eventoApi,
  });

  final ReporteContenidoApi? api;
  final NodoApi? nodoApi;
  final EventoApi? eventoApi;

  @override
  State<ReportesContenidoScreen> createState() =>
      _ReportesContenidoScreenState();
}

class _ReportesContenidoScreenState extends State<ReportesContenidoScreen> {
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  late final ReporteContenidoApi _api = widget.api ?? ReporteContenidoApi();
  final TextEditingController _busquedaController = TextEditingController();

  static const Color _fondo = Color(0xFFEAEADF);
  static const Color _verde = Color(0xFFB4F52B);
  static const Color _texto = Color(0xFF26302D);

  static const List<String> _estados = ['pendiente', 'resuelta', 'archivada'];

  List<Map<String, dynamic>> _reportes = [];
  bool _cargando = true;
  bool _actualizando = false;
  String? _error;
  String _busqueda = '';
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _cargarReportes();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarReportes() async {
    if (!mounted) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final reportes = await _api.listar();
      if (!mounted) return;

      setState(() {
        _reportes = reportes;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _cargando = false;
      });
    }
  }

  List<Map<String, dynamic>> get _reportesFiltrados {
    return _reportes.where((reporte) {
      final estado = reporte['estado']?.toString() ?? '';

      if (estado != _estados[_tab]) return false;

      final texto = [
        reporte['id'],
        reporte['tipoContenido'],
        reporte['contenidoId'],
        reporte['motivo'],
        reporte['descripcion'],
      ].join(' ').toLowerCase();

      return texto.contains(_busqueda.toLowerCase().trim());
    }).toList();
  }

  String _nombreEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return _l10n.admRepEstadoPendiente;
      case 'resuelta':
        return _l10n.admRepEstadoResuelta;
      case 'archivada':
        return _l10n.admRepEstadoArchivada;
      default:
        return estado;
    }
  }

  String _nombreTipo(String tipo) {
    switch (tipo) {
      case 'ruta':
        return _l10n.admRepTipoRuta;
      case 'nodo':
        return _l10n.admRepTipoNodo;
      case 'alerta':
        return _l10n.admRepTipoAlerta;
      case 'evento':
        return _l10n.admRepTipoEvento;
      default:
        return tipo;
    }
  }

  ShapeBorder get _formaDialogo =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(30));

  Widget _botonPrincipal({
    required String texto,
    required VoidCallback onPressed,
  }) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _verde,
        foregroundColor: _texto,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        shape: const StadiumBorder(),
      ),
      child: Text(texto),
    );
  }

  Widget _botonSecundario({
    required String texto,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: _texto,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      child: Text(texto),
    );
  }

  Future<void> _decidir(int id, String accion) async {
    if (_actualizando) return;

    final String aviso = switch (accion) {
      'desactivar' => _l10n.admRepConfirmarDesactivar,
      'conservar' => _l10n.admRepConfirmarConservar,
      _ => _l10n.admRepConfirmarReactivar,
    };
    final String titulo = switch (accion) {
      'desactivar' => _l10n.admRepDesactivar,
      'conservar' => _l10n.admRepConservar,
      _ => _l10n.admRepReactivar,
    };

    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey<String>('confirmar-reporte'),
        backgroundColor: _fondo,
        surfaceTintColor: Colors.transparent,
        shape: _formaDialogo,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(26, 26, 26, 8),
        contentPadding: const EdgeInsets.fromLTRB(26, 8, 26, 12),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Text(
          titulo,
          style: const TextStyle(
            color: _texto,
            fontSize: 23,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Text(
            aviso,
            style: const TextStyle(color: _texto, fontSize: 15, height: 1.5),
          ),
        ),
        actions: [
          _botonSecundario(
            texto: _l10n.comunCancelar,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          _botonPrincipal(
            texto: _l10n.admConfirmar,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted || _actualizando) return;

    setState(() => _actualizando = true);

    try {
      if (accion == 'reactivar') {
        await _api.reactivar(id);
      } else {
        await _api.resolver(id, accion);
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (accion) {
            'desactivar' => _l10n.admRepDesactivado,
            'conservar' => _l10n.admRepConservado,
            _ => _l10n.admRepReactivado,
          }),
        ),
      );

      await _cargarReportes();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.admRepErrorActualizar('$error'))),
      );
    } finally {
      if (mounted) {
        setState(() => _actualizando = false);
      }
    }
  }

  Widget? _vistaPreviaFoto(String tipo, int contenidoId, String nombre) {
    if (tipo == 'nodo') {
      final NodoApi api = widget.nodoApi ?? NodoApi();
      return FotoRemota(
        llave: const ValueKey<String>('foto-reportada'),
        cargar: () => api.foto(contenidoId),
        altura: 170,
        titulo: nombre,
      );
    }
    if (tipo == 'evento') {
      final EventoApi api = widget.eventoApi ?? EventoApi();
      return FotoRemota(
        llave: const ValueKey<String>('foto-reportada'),
        cargar: () => api.foto(contenidoId),
        altura: 170,
        titulo: nombre,
      );
    }
    return null;
  }

  Future<void> _mostrarDetalle(Map<String, dynamic> reporte) async {
    final int id = reporte['id'] as int;
    final String estado = reporte['estado']?.toString() ?? '';
    final String tipo = reporte['tipoContenido']?.toString() ?? '';
    final String motivo = motivoReporteLabel(
      _l10n,
      reporte['motivo']?.toString() ?? '',
    );
    final String descripcion =
        reporte['descripcion']?.toString() ?? _l10n.admRepSinDescripcion;
    final bool esFoto = reporte['esFoto'] == true;
    final bool desactivo = reporte['resolucion']?.toString() == 'desactivado';
    final int contenidoId = reporte['contenidoId'] as int;
    final Map<String, dynamic>? contenido = reporte['contenido'] is Map
        ? Map<String, dynamic>.from(reporte['contenido'] as Map)
        : null;
    final String nombre = contenido?['nombre']?.toString() ?? '#$contenidoId';
    final Widget? foto = contenido != null && contenido['conFoto'] == true
        ? _vistaPreviaFoto(tipo, contenidoId, nombre)
        : null;

    final String? accion = await mostrarDetalleAdmin(
      context,
      dialogKey: const ValueKey<String>('detalle-reporte'),
      titulo: _l10n.admRepTitulo(id),
      icono: Icons.flag_outlined,
      estado: _nombreEstado(estado),
      campos: <String, String>{
        _l10n.admRepTipoContenido: _nombreTipo(tipo),
        if (esFoto) _l10n.admRepEsFoto: motivo,
        _l10n.admRepContenido: contenido == null
            ? _l10n.admRepContenidoNoExiste
            : nombre,
        if (contenido?['creadoPorNombre'] != null)
          _l10n.admRepDueno: contenido!['creadoPorNombre'].toString(),
        if (contenido != null)
          _l10n.admRepEstadoContenido: contenido['desactivado'] == true
              ? _l10n.admRepContenidoDesactivado
              : _l10n.admRepContenidoActivo,
        _l10n.admMotivo: motivo,
        _l10n.admDescripcion: descripcion,
      },
      extra: foto,
      acciones: <String, String>{
        if (estado == 'pendiente') ...<String, String>{
          'conservar': _l10n.admRepConservar,
          'desactivar': _l10n.admRepDesactivar,
        },
        if (desactivo && contenido != null) 'reactivar': _l10n.admRepReactivar,
      },
    );
    if (accion != null && mounted) await _decidir(id, accion);
  }

  @override
  Widget build(BuildContext context) {
    final filas = _reportesFiltrados.map((reporte) {
      final tipo = reporte['tipoContenido']?.toString() ?? 'contenido';
      final claveMotivo = reporte['motivo']?.toString() ?? '';
      final motivo = claveMotivo.isEmpty
          ? _l10n.admRepSinMotivo
          : motivoReporteLabel(_l10n, claveMotivo);
      final estado = reporte['estado']?.toString() ?? '';
      final contenido = reporte['contenido'];
      final nombre = contenido is Map && contenido['nombre'] != null
          ? '${contenido['nombre']}'
          : '#${reporte['contenidoId']}';

      return AdminRow(
        icon: Icons.flag_outlined,
        title: '${_nombreTipo(tipo)} $nombre - $motivo',
        values: <String>[
          _nombreTipo(tipo),
          nombre,
          motivo,
          _nombreEstado(estado),
        ],
        subtitle: _l10n.admRepTitulo(reporte['id'] as int),
        onTap: () => _mostrarDetalle(reporte),
      );
    }).toList();

    return AdminListScaffold(
      onRefresh: _cargarReportes,
      refreshing: _cargando,
      searchHint: _l10n.admRepBuscar,
      searchController: _busquedaController,
      onSearch: (texto) => setState(() => _busqueda = texto),
      tabs: [
        _l10n.admTabPendientes,
        _l10n.admTabResueltas,
        _l10n.admTabArchivadas,
      ],
      tabIndex: _tab,
      onTab: (indice) => setState(() => _tab = indice),
      child: AdminDataTable(
        columns: const <AdminTableColumn>[
          AdminTableColumn('Reporte', width: 220),
          AdminTableColumn('Tipo', width: 110),
          AdminTableColumn('Contenido', width: 175),
          AdminTableColumn('Motivo', width: 160),
          AdminTableColumn('Estado', width: 110),
        ],
        rows: filas,
        loading: _cargando,
        error: _error,
        onRetry: _cargarReportes,
        emptyTitle: _l10n.admRepSin,
        emptyMessage: _l10n.admRepSinMsg,
      ),
    );
  }
}
