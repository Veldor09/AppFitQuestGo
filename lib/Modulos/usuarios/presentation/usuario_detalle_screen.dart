import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/theme/fq_colors.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
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
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  late final UsuariosApi _api = widget.api ?? UsuariosApi();

  late Future<_DetalleDatos> _futuro;
  int _pestanaSeleccionada = 0;

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
    List<Map<String, dynamic>> insignias = [];
    Object? errorInsignias;

    try {
      insignias = await _api.obtenerInsignias(widget.usuario.id);
    } catch (error) {
      errorInsignias = error;
    }

    return _DetalleDatos(
      historial: resultados[0],
      aportes: resultados[1],
      reportes: resultados[2],
      insignias: insignias,
      errorInsignias: errorInsignias,
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
                return _estadoError(_l10n.admUsrNoInfo);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _resumen(datos),
                  const SizedBox(height: 20),
                  _pestanas(),
                  const SizedBox(height: 20),
                  switch (_pestanaSeleccionada) {
                    0 => _historial(datos.historial),
                    1 => _aportes(datos.aportes),
                    2 => _reportes(datos.reportes),
                    _ => datos.errorInsignias != null
                        ? _estadoError(datos.errorInsignias)
                        : _insignias(datos.insignias),
                  },
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _pestanas() {
    final etiquetas = <String>[
      _l10n.admUsrTabHistorial,
      _l10n.admUsrTabAportes,
      _l10n.admUsrTabReportes,
      _l10n.admUsrTabInsignias,
    ];
    const iconos = <IconData>[
      Icons.history,
      Icons.add_location_alt_outlined,
      Icons.report_problem_outlined,
      Icons.emoji_events_outlined,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(etiquetas.length, (indice) {
        final seleccionado = _pestanaSeleccionada == indice;

        return ChoiceChip(
          label: Text(etiquetas[indice]),
          avatar: Icon(iconos[indice], size: 18),
          selected: seleccionado,
          showCheckmark: false,
          onSelected: (_) {
            setState(() => _pestanaSeleccionada = indice);
          },
        );
      }),
    );
  }

  Widget _insignias(List<Map<String, dynamic>> insignias) {
    if (insignias.isEmpty) {
      return _panel(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_l10n.admUsrSinInsignias),
        ),
      );
    }

    final ordenadas = [...insignias]
      ..sort((a, b) {
        final estadoA = a['desbloqueada'] == true ? 0 : 1;
        final estadoB = b['desbloqueada'] == true ? 0 : 1;
        return estadoA.compareTo(estadoB);
      });

    final obtenidas =
        insignias.where((item) => item['desbloqueada'] == true).length;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _l10n.admUsrInsigniasObtenidas(obtenidas, insignias.length),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ...ordenadas.map((insignia) {
            final desbloqueada = insignia['desbloqueada'] == true;
            final progreso = insignia['progreso'];
            final meta = insignia['meta'];
            final fecha = insignia['fechaObtenida'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (insignia['emoji'] ?? '??').toString(),
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (insignia['nombre'] ?? 'Insignia').toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (insignia['descripcion'] ?? '').toString(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              desbloqueada
                                  ? _l10n.admUsrDesbloqueada
                                  : _l10n.admUsrPendiente,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: desbloqueada
                                    ? Colors.green.shade700
                                    : FqColors.muted,
                              ),
                            ),
                            if (desbloqueada && fecha != null) ...[
                              const SizedBox(height: 4),
                              Text(_l10n.admUsrObtenida(_fecha(fecha))),
                            ],
                            if (!desbloqueada &&
                                progreso is num &&
                                meta is num &&
                                meta > 0) ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: (progreso / meta)
                                    .clamp(0.0, 1.0)
                                    .toDouble(),
                              ),
                              const SizedBox(height: 4),
                              Text(_l10n.admUsrProgreso('$progreso', '$meta')),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
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
              label: Text(_l10n.admUsrVolver),
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
                      _l10n.admUsrRolEstado(
                        usuario.etiquetaRol,
                        usuario.estado,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: FqColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _l10n.admUsrActualizar,
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
          _l10n.admUsrIndInteracciones,
          historial['totalInteracciones'],
          Icons.history,
        ),
        _indicador(
          _l10n.admUsrIndRutas,
          aportes['totalRutas'],
          Icons.route,
        ),
        _indicador(
          _l10n.admUsrIndNodos,
          aportes['totalNodos'],
          Icons.place_outlined,
        ),
        _indicador(
          _l10n.admUsrIndReportes,
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
      titulo: _l10n.admUsrHistorialTitulo,
      icono: Icons.history,
      resumen: Wrap(
        spacing: 14,
        runSpacing: 8,
        children: [
          _datoResumen(_l10n.admUsrFavoritos, resumen['totalFavoritos']),
          _datoResumen(_l10n.admUsrVotosNodos, resumen['totalVotosNodos']),
          _datoResumen(
            _l10n.admUsrVotosAlertas,
            resumen['totalVotosAlertas'],
          ),
        ],
      ),
      elementos: actividades,
      vacio: _l10n.admUsrHistorialVacio,
      construir: (elemento) => _fila(
        titulo: _texto(elemento['accion'], _l10n.admUsrActividad),
        subtitulo: _l10n.admUsrTipoReferencia(
          _texto(elemento['tipo']),
          _texto(elemento['referenciaId']),
        ),
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
            _l10n.admUsrAportesTitulo,
            Icons.add_location_alt_outlined,
          ),
          const SizedBox(height: 16),
          Text(
            _l10n.admUsrRutasCreadas(rutas.length),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: FqColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (rutas.isEmpty)
            _mensajeVacio(_l10n.admUsrSinRutas)
          else
            ...rutas.map(
              (ruta) => _fila(
                titulo: _texto(ruta['nombre'], _l10n.admUsrRutaSinNombre),
                subtitulo: _l10n.admUsrRutaDetalle(
                  _texto(ruta['estado']),
                  _texto(ruta['distanciaKm'], '—'),
                ),
                detalle: _fecha(ruta['creadoEn']),
                icono: Icons.route,
              ),
            ),
          const SizedBox(height: 20),
          Text(
            _l10n.admUsrNodosCreados(nodos.length),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: FqColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (nodos.isEmpty)
            _mensajeVacio(_l10n.admUsrSinNodos)
          else
            ...nodos.map(
              (nodo) => _fila(
                titulo: _texto(nodo['nombre'], _l10n.admUsrNodoSinNombre),
                subtitulo: _l10n.admUsrNodoDetalle(
                  _texto(nodo['categoria']),
                  _texto(nodo['estado']),
                ),
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
      titulo: _l10n.admUsrReportesTitulo,
      icono: Icons.report_problem_outlined,
      resumen: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _l10n.admUsrReportesNota,
            style: const TextStyle(fontSize: 12, color: FqColors.muted),
          ),
          const SizedBox(height: 10),
          _desglose(_l10n.admUsrPorEstado, _mapa(resumen['porEstado'])),
          const SizedBox(height: 6),
          _desglose(_l10n.admUsrPorGravedad, _mapa(resumen['porGravedad'])),
        ],
      ),
      elementos: reportes,
      vacio: _l10n.admUsrReportesVacio,
      construir: (reporte) => _fila(
        titulo: _texto(reporte['tipo'], _l10n.admUsrIncidente),
        subtitulo: _l10n.admUsrIncidenteDetalle(
          _texto(reporte['descripcion'], _l10n.admRepSinDescripcion),
          _texto(reporte['gravedad']),
          _texto(reporte['estado']),
          _texto(reporte['confirmacionesNo'], '0'),
        ),
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
        _l10n.admUsrSinDatos(titulo),
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
          Text(
            _l10n.admUsrErrorDetalle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${error ?? _l10n.admUsrErrorDesconocido}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _actualizar,
            icon: const Icon(Icons.refresh),
            label: Text(_l10n.comunReintentar),
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
    required this.insignias,
    required this.errorInsignias,
  });

  final Map<String, dynamic> historial;
  final Map<String, dynamic> aportes;
  final Map<String, dynamic> reportes;
  final List<Map<String, dynamic>> insignias;
  final Object? errorInsignias;
}
