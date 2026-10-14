import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuarios_api.dart';

/// ADM-03: detalle administrativo de un usuario.
///
/// Consulta el historial, los aportes y los reportes reales del backend.
class UsuarioDetalleScreen extends StatefulWidget {
  const UsuarioDetalleScreen({
    super.key,
    required this.usuario,
    this.api,
    this.onVolver,
  });

  final Usuario usuario;
  final UsuariosApi? api;
  final VoidCallback? onVolver;

  @override
  State<UsuarioDetalleScreen> createState() => _UsuarioDetalleScreenState();
}

class _UsuarioDetalleScreenState extends State<UsuarioDetalleScreen> {
  late final UsuariosApi _api = widget.api ?? UsuariosApi();

  late Future<_DetalleDatos> _futuro;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  @override
  void didUpdateWidget(covariant UsuarioDetalleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.usuario.id != widget.usuario.id) {
      _recargar();
    }
  }

  void _recargar() {
    _futuro = _cargar();
  }

  Future<_DetalleDatos> _cargar() async {
    final resultados = await Future.wait<Map<String, dynamic>>([
      _api.obtenerHistorial(widget.usuario.id),
      _api.obtenerAportes(widget.usuario.id),
      _api.obtenerReportes(widget.usuario.id),
    ]);

    return _DetalleDatos(
      historial: resultados[0],
      aportes: resultados[1],
      reportes: resultados[2],
    );
  }

  void _actualizar() {
    setState(_recargar);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _encabezado(),
          const SizedBox(height: 20),
          FutureBuilder<_DetalleDatos>(
            future: _futuro,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return _estadoError(snapshot.error);
              }

              final datos = snapshot.data;

              if (datos == null) {
                return _estadoError('No se pudo obtener la información.');
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _resumen(datos),
                  const SizedBox(height: 20),
                  _historial(datos.historial),
                  const SizedBox(height: 20),
                  _aportes(datos.aportes),
                  const SizedBox(height: 20),
                  _reportes(datos.reportes),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _encabezado() {
    final usuario = widget.usuario;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onVolver != null) ...[
            TextButton.icon(
              onPressed: widget.onVolver,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Volver a usuarios'),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: FqColors.volt,
                child: Text(
                  usuario.iniciales,
                  style: const TextStyle(
                    color: FqColors.night,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usuario.nombreUser,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: FqColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      usuario.emailUser,
                      style: const TextStyle(color: FqColors.muted),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Rol: ${usuario.etiquetaRol}  ·  '
                      'Estado: ${usuario.estado}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: FqColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar información',
                onPressed: _actualizar,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resumen(_DetalleDatos datos) {
    final historial = _mapa(datos.historial['resumen']);
    final aportes = _mapa(datos.aportes['resumen']);
    final reportes = _mapa(datos.reportes['resumen']);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _indicador(
          'Interacciones',
          historial['totalInteracciones'],
          Icons.history,
        ),
        _indicador('Rutas creadas', aportes['totalRutas'], Icons.route),
        _indicador(
          'Nodos creados',
          aportes['totalNodos'],
          Icons.place_outlined,
        ),
        _indicador(
          'Reportes',
          reportes['totalReportes'],
          Icons.report_outlined,
        ),
      ],
    );
  }

  Widget _indicador(String titulo, dynamic valor, IconData icono) {
    return SizedBox(
      width: 190,
      child: _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: FqColors.muted),
            const SizedBox(height: 10),
            Text(
              '${valor ?? 0}',
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: FqColors.ink,
              ),
            ),
            Text(
              titulo,
              style: const TextStyle(fontSize: 12, color: FqColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historial(Map<String, dynamic> datos) {
    final resumen = _mapa(datos['resumen']);
    final actividades = _lista(datos['actividades']);

    return _seccion(
      titulo: 'Historial de actividad',
      icono: Icons.history,
      resumen: Wrap(
        spacing: 14,
        runSpacing: 8,
        children: [
          _datoResumen('Favoritos', resumen['totalFavoritos']),
          _datoResumen('Votos de nodos', resumen['totalVotosNodos']),
          _datoResumen('Votos de alertas', resumen['totalVotosAlertas']),
        ],
      ),
      elementos: actividades,
      vacio: 'Este usuario todavía no registra actividad.',
      construir: (elemento) => _fila(
        titulo: _texto(elemento['accion'], 'Actividad'),
        subtitulo:
            'Tipo: ${_texto(elemento['tipo'])}  ·  '
            'Referencia: ${_texto(elemento['referenciaId'])}',
        detalle: _fecha(elemento['fecha']),
        icono: Icons.bolt_outlined,
      ),
    );
  }

  Widget _aportes(Map<String, dynamic> datos) {
    final rutas = _lista(datos['rutas']);
    final nodos = _lista(datos['nodos']);

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloSeccion(
            'Aportes del usuario',
            Icons.add_location_alt_outlined,
          ),
          const SizedBox(height: 16),
          Text(
            'Rutas creadas (${rutas.length})',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: FqColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (rutas.isEmpty)
            _mensajeVacio('No ha creado rutas.')
          else
            ...rutas.map(
              (ruta) => _fila(
                titulo: _texto(ruta['nombre'], 'Ruta sin nombre'),
                subtitulo:
                    'Estado: ${_texto(ruta['estado'])}  ·  '
                    'Distancia: ${_texto(ruta['distanciaKm'], '—')} km',
                detalle: _fecha(ruta['creadoEn']),
                icono: Icons.route,
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Nodos creados (${nodos.length})',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: FqColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (nodos.isEmpty)
            _mensajeVacio('No ha creado nodos.')
          else
            ...nodos.map(
              (nodo) => _fila(
                titulo: _texto(nodo['nombre'], 'Nodo sin nombre'),
                subtitulo:
                    'Categoría: ${_texto(nodo['categoria'])}  ·  '
                    'Estado: ${_texto(nodo['estado'])}',
                detalle: _fecha(nodo['creadoEn']),
                icono: Icons.place_outlined,
              ),
            ),
        ],
      ),
    );
  }

  Widget _reportes(Map<String, dynamic> datos) {
    final reportes = _lista(datos['reportes']);
    final resumen = _mapa(datos['resumen']);

    return _seccion(
      titulo: 'Reportes de incidentes',
      icono: Icons.report_problem_outlined,
      resumen: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alertas e incidentes registrados por este usuario.',
            style: TextStyle(fontSize: 12, color: FqColors.muted),
          ),
          const SizedBox(height: 10),
          _desglose('Por estado', _mapa(resumen['porEstado'])),
          const SizedBox(height: 6),
          _desglose('Por gravedad', _mapa(resumen['porGravedad'])),
        ],
      ),
      elementos: reportes,
      vacio: 'Este usuario no ha reportado incidentes.',
      construir: (reporte) => _fila(
        titulo: _texto(reporte['tipo'], 'Incidente'),
        subtitulo:
            '${_texto(reporte['descripcion'], 'Sin descripción')}\n'
            'Gravedad: ${_texto(reporte['gravedad'])}  ·  '
            'Estado: ${_texto(reporte['estado'])}  ·  '
            'Confirmaciones: ${_texto(reporte['confirmacionesNo'], '0')}',
        detalle: _fecha(reporte['creadoEn']),
        icono: Icons.warning_amber_outlined,
      ),
    );
  }

  Widget _seccion({
    required String titulo,
    required IconData icono,
    required Widget resumen,
    required List<Map<String, dynamic>> elementos,
    required String vacio,
    required Widget Function(Map<String, dynamic>) construir,
  }) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tituloSeccion(titulo, icono),
          const SizedBox(height: 14),
          resumen,
          const SizedBox(height: 16),
          const Divider(color: FqColors.border),
          const SizedBox(height: 8),
          if (elementos.isEmpty)
            _mensajeVacio(vacio)
          else
            ...elementos.map(construir),
        ],
      ),
    );
  }

  Widget _tituloSeccion(String titulo, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 21, color: FqColors.ink),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: FqColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _datoResumen(String titulo, dynamic valor) {
    return Text(
      '$titulo: ${valor ?? 0}',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: FqColors.ink,
      ),
    );
  }

  Widget _desglose(String titulo, Map<String, dynamic> valores) {
    if (valores.isEmpty) {
      return Text(
        '$titulo: sin datos',
        style: const TextStyle(fontSize: 12, color: FqColors.muted),
      );
    }

    return Text(
      '$titulo: ${valores.entries.map((e) => '${e.key}: ${e.value}').join(' · ')}',
      style: const TextStyle(fontSize: 12, color: FqColors.muted),
    );
  }

  Widget _fila({
    required String titulo,
    required String subtitulo,
    required String detalle,
    required IconData icono,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FqColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: FqColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: FqColors.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: FqColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            detalle,
            style: const TextStyle(fontSize: 11, color: FqColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _mensajeVacio(String mensaje) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(mensaje, style: const TextStyle(color: FqColors.muted)),
      ),
    );
  }

  Widget _estadoError(Object? error) {
    return _panel(
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 35, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Text(
            'No se pudo cargar el detalle del usuario.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('${error ?? 'Error desconocido'}', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _actualizar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FqColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FqColors.border),
      ),
      child: child,
    );
  }

  static Map<String, dynamic> _mapa(dynamic valor) {
    if (valor is Map) {
      return Map<String, dynamic>.from(valor);
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _lista(dynamic valor) {
    if (valor is! List) return <Map<String, dynamic>>[];

    return valor
        .whereType<Map>()
        .map((elemento) => Map<String, dynamic>.from(elemento))
        .toList();
  }

  static String _texto(dynamic valor, [String alternativa = '—']) {
    if (valor == null || valor.toString().trim().isEmpty) {
      return alternativa;
    }
    return valor.toString();
  }

  static String _fecha(dynamic valor) {
    if (valor == null) return '—';

    final fecha = DateTime.tryParse(valor.toString());
    if (fecha == null) return valor.toString();

    final local = fecha.toLocal();

    String dos(int n) => n.toString().padLeft(2, '0');

    return '${dos(local.day)}/${dos(local.month)}/${local.year}';
  }
}

class _DetalleDatos {
  const _DetalleDatos({
    required this.historial,
    required this.aportes,
    required this.reportes,
  });

  final Map<String, dynamic> historial;
  final Map<String, dynamic> aportes;
  final Map<String, dynamic> reportes;
}
