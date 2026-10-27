import 'package:flutter/material.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/admin/data/reporte_contenido_api.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_list_scaffold.dart';

class ReportesContenidoScreen extends StatefulWidget {
  const ReportesContenidoScreen({super.key});

  @override
  State<ReportesContenidoScreen> createState() =>
      _ReportesContenidoScreenState();
}

class _ReportesContenidoScreenState extends State<ReportesContenidoScreen> {
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  final ReporteContenidoApi _api = ReporteContenidoApi();
  final TextEditingController _busquedaController = TextEditingController();

  static const Color _fondo = Color(0xFFEAEADF);
  static const Color _verde = Color(0xFFB4F52B);
  static const Color _texto = Color(0xFF26302D);
  static const Color _secundario = Color(0xFF68716B);
  static const Color _borde = Color(0xFFCACDC1);

  // Estilo exclusivo del botón Cerrar.
  static const Color _rojoFondo = Color(0xFFFCE4E4);
  static const Color _rojoTexto = Color(0xFFB42332);

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
      default:
        return tipo;
    }
  }

  ShapeBorder get _formaDialogo =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(30));

  Widget _etiqueta(String texto) {
    return Text(
      texto,
      style: const TextStyle(
        color: _secundario,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _valor(String texto) {
    return Text(
      texto,
      style: const TextStyle(color: _texto, fontSize: 15, height: 1.45),
    );
  }

  Widget _campoDetalle({required String etiqueta, required String valor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_etiqueta(etiqueta), const SizedBox(height: 5), _valor(valor)],
    );
  }

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

  // Botón rojo únicamente para cerrar el detalle.
  Widget _botonCerrar({required VoidCallback onPressed}) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _rojoFondo,
        foregroundColor: _rojoTexto,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        shape: const StadiumBorder(),
      ),
      child: Text(
        _l10n.comunCerrar,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _cambiarEstado(int id, String estado) async {
    if (_actualizando) return;


    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _fondo,
        surfaceTintColor: Colors.transparent,
        shape: _formaDialogo,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(26, 26, 26, 8),
        contentPadding: const EdgeInsets.fromLTRB(26, 8, 26, 12),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Text(
          _l10n.admRepConfirmarTitulo,
          style: const TextStyle(
            color: _texto,
            fontSize: 23,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Text(
            estado == 'resuelta'
                ? _l10n.admRepConfirmarResolver(id)
                : _l10n.admRepConfirmarArchivar(id),
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
      await _api.cambiarEstado(id, estado);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _l10n.admRepActualizado(id, _nombreEstado(estado).toLowerCase()),
          ),
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

  Future<void> _mostrarDetalle(Map<String, dynamic> reporte) async {
    final int id = reporte['id'] as int;
    final String estado = reporte['estado']?.toString() ?? '';
    final String tipo = reporte['tipoContenido']?.toString() ?? '';
    final String motivo = reporte['motivo']?.toString() ?? 'Sin motivo';
    final String descripcion =
        reporte['descripcion']?.toString() ?? _l10n.admRepSinDescripcion;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _fondo,
        surfaceTintColor: Colors.transparent,
        shape: _formaDialogo,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(26, 26, 26, 6),
        contentPadding: const EdgeInsets.fromLTRB(26, 12, 26, 18),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Text(
          _l10n.admRepTitulo(id),
          style: const TextStyle(
            color: _texto,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _l10n.admRepInfo,
                  style: const TextStyle(
                    color: _secundario,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 32,
                  runSpacing: 18,
                  children: [
                    _campoDetalle(
                      etiqueta: _l10n.admRepTipoContenido,
                      valor: _nombreTipo(tipo),
                    ),
                    _campoDetalle(
                      etiqueta: _l10n.admRepIdContenido,
                      valor: '${reporte['contenidoId']}',
                    ),
                    _campoDetalle(
                      etiqueta: _l10n.perfilEstado,
                      valor: _nombreEstado(estado),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Divider(color: _borde),
                const SizedBox(height: 18),
                _campoDetalle(etiqueta: _l10n.admMotivo, valor: motivo),
                const SizedBox(height: 18),
                _campoDetalle(etiqueta: _l10n.admDescripcion, valor: descripcion),
              ],
            ),
          ),
        ),
        actions: [
          _botonCerrar(onPressed: () => Navigator.pop(dialogContext)),
          if (estado != 'resuelta')
            _botonSecundario(
              texto: _l10n.admResolver,
              onPressed: () {
                Navigator.pop(dialogContext);
                _cambiarEstado(id, 'resuelta');
              },
            ),
          if (estado != 'archivada')
            _botonPrincipal(
              texto: _l10n.admArchivar,
              onPressed: () {
                Navigator.pop(dialogContext);
                _cambiarEstado(id, 'archivada');
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filas = _reportesFiltrados.map((reporte) {
      final tipo = reporte['tipoContenido']?.toString() ?? 'contenido';
      final motivo = reporte['motivo']?.toString() ?? _l10n.admRepSinMotivo;
      final estado = reporte['estado']?.toString() ?? '';

      return AdminRow(
        icon: Icons.flag_outlined,
        title: '${_nombreTipo(tipo)} #${reporte['contenidoId']} - $motivo',
        subtitle: _l10n.admRepTitulo(reporte['id'] as int),
        trailing: Chip(label: Text(_nombreEstado(estado))),
        onTap: () => _mostrarDetalle(reporte),
      );
    }).toList();

    return AdminListScaffold(
      searchHint: _l10n.admRepBuscar,
      searchController: _busquedaController,
      onSearch: (texto) => setState(() => _busqueda = texto),
      tabs: [_l10n.admTabPendientes, _l10n.admTabResueltas, _l10n.admTabArchivadas],
      tabIndex: _tab,
      onTab: (indice) => setState(() => _tab = indice),
      child: AdminDataTable(
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
