import 'package:flutter/material.dart';

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
  final ReporteContenidoApi _api = ReporteContenidoApi();
  final TextEditingController _busquedaController = TextEditingController();

  List<Map<String, dynamic>> _reportes = [];
  bool _cargando = true;
  String? _error;
  String _busqueda = '';
  int _tab = 0;

  static const List<String> _estados = ['pendiente', 'resuelta', 'archivada'];

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

  Future<void> _cambiarEstado(int id, String estado) async {
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar accion'),
        content: Text('¿Deseas cambiar el reporte #$id a $estado?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    try {
      await _api.cambiarEstado(id, estado);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reporte #$id actualizado a $estado')),
      );

      await _cargarReportes();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $error')));
    }
  }

  Future<void> _mostrarDetalle(Map<String, dynamic> reporte) async {
    final int id = reporte['id'] as int;
    final String estado = reporte['estado']?.toString() ?? '';
    final String motivo = reporte['motivo']?.toString() ?? 'Sin motivo';
    final String descripcion =
        reporte['descripcion']?.toString() ?? 'Sin descripcion';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reporte #$id'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tipo: ${reporte['tipoContenido']}'),
              Text('Contenido ID: ${reporte['contenidoId']}'),
              Text('Estado: $estado'),
              const SizedBox(height: 12),
              Text('Motivo: $motivo'),
              const SizedBox(height: 8),
              Text('Descripcion: $descripcion'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
          if (estado != 'resuelta')
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _cambiarEstado(id, 'resuelta');
              },
              child: const Text('Resolver'),
            ),
          if (estado != 'archivada')
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _cambiarEstado(id, 'archivada');
              },
              child: const Text('Archivar'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filas = _reportesFiltrados.map((reporte) {
      final tipo = reporte['tipoContenido']?.toString() ?? 'contenido';
      final motivo = reporte['motivo']?.toString() ?? 'Sin motivo';
      final estado = reporte['estado']?.toString() ?? '';

      return AdminRow(
        icon: Icons.flag_outlined,
        title: '$tipo #${reporte['contenidoId']} - $motivo',
        subtitle: 'Reporte #${reporte['id']}',
        trailing: Chip(label: Text(estado)),
        onTap: () => _mostrarDetalle(reporte),
      );
    }).toList();

    return AdminListScaffold(
      searchHint: 'Buscar reportes...',
      searchController: _busquedaController,
      onSearch: (texto) => setState(() => _busqueda = texto),
      tabs: const ['Pendientes', 'Resueltas', 'Archivadas'],
      tabIndex: _tab,
      onTab: (indice) => setState(() => _tab = indice),
      child: AdminDataTable(
        rows: filas,
        loading: _cargando,
        error: _error,
        onRetry: _cargarReportes,
        emptyTitle: 'Sin reportes',
        emptyMessage: 'No hay reportes para este estado.',
      ),
    );
  }
}
