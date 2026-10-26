
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:fit_quest_go/Modulos/admin/data/auditoria_api.dart';
import 'package:fit_quest_go/core/api/api_client.dart';

class AuditoriaScreen extends StatefulWidget {
  const AuditoriaScreen({super.key, this.api});

  /// Permite utilizar una API simulada durante las pruebas.
  /// En produccion se utiliza AuditoriaApi normalmente.
  final AuditoriaApi? api;

  @override
  State<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends State<AuditoriaScreen> {
  late final AuditoriaApi _api = widget.api ?? AuditoriaApi();

  final TextEditingController _administradorController =
      TextEditingController();
  final TextEditingController _accionController =
      TextEditingController();
  final TextEditingController _entidadController =
      TextEditingController();

  static const int _limite = 20;
  static const Duration _intervalo = Duration(seconds: 5);

  static const Color _verde = Color(0xFFA9F32D);
  static const Color _verdeOscuro = Color(0xFF277A35);
  static const Color _fondo = Color(0xFFF5F7FA);
  static const Color _texto = Color(0xFF18243A);
  static const Color _borde = Color(0xFFE2E8F0);

  Timer? _temporizador;

  List<Map<String, dynamic>> _registros = [];

  bool _cargando = false;
  bool _consultando = false;
  String? _error;

  int _pagina = 1;
  int _total = 0;
  int _totalPaginas = 0;

  DateTime? _ultimaActualizacion;

  String _filtroAdministrador = '';
  String _filtroAccion = '';
  String _filtroEntidad = '';

  @override
  void initState() {
    super.initState();

    _cargarRegistros();

    _temporizador = Timer.periodic(_intervalo, (_) {
      if (mounted && !_consultando) {
        _cargarRegistros(silencioso: true);
      }
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _administradorController.dispose();
    _accionController.dispose();
    _entidadController.dispose();
    super.dispose();
  }

  Future<void> _cargarRegistros({
    bool silencioso = false,
  }) async {
    if (_consultando) return;

    final administradorTexto = _filtroAdministrador.trim();
    final administradorId = administradorTexto.isEmpty
        ? null
        : int.tryParse(administradorTexto);

    if (administradorTexto.isNotEmpty &&
        (administradorId == null || administradorId < 1)) {
      if (!mounted) return;

      setState(() {
        _error = 'Ingrese un ID de administrador válido.';
      });
      return;
    }

    _consultando = true;

    if (!silencioso && mounted) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      final respuesta = await _api.consultar(
        administradorId: administradorId,
        accion: _filtroAccion,
        entidad: _filtroEntidad,
        pagina: _pagina,
        limite: _limite,
      );

      final datos =
          respuesta['registros'] as List<dynamic>? ?? [];

      if (!mounted) return;

      setState(() {
        _registros = datos
            .map(
              (item) =>
                  Map<String, dynamic>.from(item as Map),
            )
            .toList();

        _total =
            (respuesta['total'] as num?)?.toInt() ?? 0;

        _totalPaginas =
            (respuesta['totalPaginas'] as num?)?.toInt() ?? 0;

        _ultimaActualizacion = DateTime.now();
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'No se pudieron consultar los registros: $e';
      });
    } finally {
      _consultando = false;

      if (mounted && !silencioso) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  void _aplicarFiltros() {
    if (_consultando) return;

    _filtroAdministrador =
        _administradorController.text.trim();
    _filtroAccion = _accionController.text.trim();
    _filtroEntidad = _entidadController.text.trim();
    _pagina = 1;

    _cargarRegistros();
  }

  void _limpiarFiltros() {
    if (_consultando) return;

    _administradorController.clear();
    _accionController.clear();
    _entidadController.clear();

    _filtroAdministrador = '';
    _filtroAccion = '';
    _filtroEntidad = '';
    _pagina = 1;

    _cargarRegistros();
  }

  void _cambiarPagina(int pagina) {
    if (_consultando ||
        pagina < 1 ||
        pagina > _totalPaginas) {
      return;
    }

    _pagina = pagina;
    _cargarRegistros();
  }

  String _fecha(dynamic valor) {
    if (valor == null) return '—';

    final fecha = DateTime.tryParse(valor.toString());
    if (fecha == null) return valor.toString();

    final local = fecha.toLocal();

    String dos(int numero) =>
        numero.toString().padLeft(2, '0');

    return '${dos(local.day)}/${dos(local.month)}/${local.year} '
        '${dos(local.hour)}:${dos(local.minute)}';
  }

  String _hora(DateTime fecha) {
    String dos(int numero) =>
        numero.toString().padLeft(2, '0');

    return '${dos(fecha.hour)}:'
        '${dos(fecha.minute)}:'
        '${dos(fecha.second)}';
  }

  String _accionLegible(String accion) {
    const nombres = {
      'USUARIO_CREADO': 'Usuario creado',
      'USUARIO_ACTUALIZADO': 'Usuario actualizado',
      'ESTADO_USUARIO_CAMBIADO': 'Estado modificado',
    };

    return nombres[accion] ??
        accion.replaceAll('_', ' ');
  }

  String _campoLegible(String campo) {
    const nombres = {
      'nombreUser': 'Nombre del usuario',
      'emailUser': 'Correo electrónico',
      'telefono': 'Teléfono',
      'idrol': 'Rol',
      'estado': 'Estado',
    };

    return nombres[campo] ?? campo;
  }

  String _valor(dynamic valor) {
    if (valor == null) return 'Sin valor';
    if (valor is bool) return valor ? 'Sí' : 'No';

    if (valor is Map || valor is List) {
      return const JsonEncoder.withIndent('  ')
          .convert(valor);
    }

    final texto = valor.toString();
    return texto.isEmpty ? '(Vacío)' : texto;
  }

  Map<String, dynamic>? _mapa(dynamic valor) {
    if (valor is Map) {
      return Map<String, dynamic>.from(valor);
    }

    if (valor is String && valor.isNotEmpty) {
      try {
        final convertido = jsonDecode(valor);

        if (convertido is Map) {
          return Map<String, dynamic>.from(convertido);
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  BoxDecoration _tarjetaDecoracion() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _borde),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.035),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _etiqueta(
    String texto, {
    Color fondo = const Color(0xFFEAF3FF),
    Color color = const Color(0xFF1764C0),
    IconData? icono,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 15, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _encabezado() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compacto = constraints.maxWidth < 800;

        final titulo = Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7E8),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: _verdeOscuro,
                size: 29,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auditoría administrativa',
                    style: TextStyle(
                      color: _texto,
                      fontSize: compacto ? 22 : 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Historial de acciones realizadas por administradores.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final estado = Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FAF0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFD6EDD6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sync,
                color: _verdeOscuro,
                size: 21,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Actualización automática cada 5 segundos',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _verdeOscuro,
                        fontSize: 12,
                      ),
                    ),
                    if (_ultimaActualizacion != null)
                      Text(
                        'Última consulta: ${_hora(_ultimaActualizacion!)}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (compacto) {
          return Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              titulo,
              const SizedBox(height: 18),
              estado,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: titulo),
            const SizedBox(width: 16),
            estado,
          ],
        );
      },
    );
  }

  Widget _campoFiltro(
    String etiqueta,
    TextEditingController controller, {
    IconData icono = Icons.search,
    TextInputType? teclado,
    String? ejemplo,
  }) {
    return SizedBox(
      width: 225,
      child: TextField(
        controller: controller,
        keyboardType: teclado,
        onSubmitted: (_) => _aplicarFiltros(),
        decoration: InputDecoration(
          labelText: etiqueta,
          hintText: ejemplo,
          prefixIcon: Icon(icono, size: 19),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide:
                const BorderSide(color: _borde),
          ),
        ),
      ),
    );
  }

  Widget _filtros() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _tarjetaDecoracion(),
      child: Wrap(
        spacing: 12,
        runSpacing: 14,
        crossAxisAlignment:
            WrapCrossAlignment.center,
        children: [
          _campoFiltro(
            'ID administrador',
            _administradorController,
            icono: Icons.person_outline,
            teclado: TextInputType.number,
            ejemplo: 'Ej. 1',
          ),
          _campoFiltro(
            'Acción',
            _accionController,
            icono: Icons.list_alt_outlined,
            ejemplo: 'USUARIO_ACTUALIZADO',
          ),
          _campoFiltro(
            'Entidad',
            _entidadController,
            icono: Icons.inventory_2_outlined,
            ejemplo: 'USUARIO',
          ),
          FilledButton.icon(
            onPressed:
                _consultando ? null : _aplicarFiltros,
            style: FilledButton.styleFrom(
              backgroundColor: _verde,
              foregroundColor: _texto,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 23,
                vertical: 19,
              ),
            ),
            icon: const Icon(Icons.search),
            label: const Text('Buscar'),
          ),
          OutlinedButton.icon(
            onPressed:
                _consultando ? null : _limpiarFiltros,
            style: OutlinedButton.styleFrom(
              foregroundColor: _texto,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 19,
              ),
            ),
            icon: const Icon(Icons.close),
            label: const Text('Limpiar'),
          ),
          IconButton.outlined(
            tooltip: 'Actualizar registros',
            onPressed: _consultando
                ? null
                : () => _cargarRegistros(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _celda(
    String texto, {
    bool destacado = false,
  }) {
    return Text(
      texto,
      style: TextStyle(
        color: _texto,
        fontWeight: destacado
            ? FontWeight.w600
            : FontWeight.w400,
        fontSize: 13,
      ),
    );
  }

  Widget _tabla() {
    if (_registros.isEmpty) {
      return const Padding(
        padding:
            EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.manage_search,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
              SizedBox(height: 12),
              Text(
                'No hay registros de auditoría para mostrar.',
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double anchoTabla =
            constraints.maxWidth > 1350
                ? constraints.maxWidth
                : 1350;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: anchoTabla,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(
                const Color(0xFFF8FAFC),
              ),
              dataRowMinHeight: 65,
              dataRowMaxHeight: 76,
              columnSpacing: 18,
              horizontalMargin: 18,
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(
                  label: Text('Administrador'),
                ),
                DataColumn(label: Text('Acción')),
                DataColumn(label: Text('Entidad')),
                DataColumn(
                  label: Text('ID afectado'),
                ),
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Detalle')),
              ],
              rows: _registros.map((registro) {
                final accion =
                    '${registro['accion'] ?? '—'}';

                return DataRow(
                  cells: [
                    DataCell(
                      _celda(
                        '${registro['id'] ?? '—'}',
                        destacado: true,
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                Color(0xFFE6F6E7),
                            child: Icon(
                              Icons.person_outline,
                              color: _verdeOscuro,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 9),
                          _celda(
                            'Administrador ${registro['administradorId'] ?? '—'}',
                            destacado: true,
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      _etiqueta(
                        _accionLegible(accion),
                        icono: Icons.edit_outlined,
                      ),
                    ),
                    DataCell(
                      _etiqueta(
                        '${registro['entidad'] ?? '—'}',
                        fondo:
                            const Color(0xFFF1EBFF),
                        color:
                            const Color(0xFF6941C6),
                      ),
                    ),
                    DataCell(
                      _celda(
                        '${registro['entidadId'] ?? '—'}',
                      ),
                    ),
                    DataCell(
                      _celda(
                        _fecha(registro['creadoEn']),
                      ),
                    ),
                    DataCell(
                      OutlinedButton.icon(
                        onPressed: () =>
                            _mostrarDetalle(registro),
                        icon: const Icon(
                          Icons.visibility_outlined,
                          size: 17,
                        ),
                        label: const Text('Ver'),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _paginacion() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment:
            WrapCrossAlignment.center,
        alignment:
            WrapAlignment.spaceBetween,
        children: [
          Text(
            'Total de registros: $_total',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: _texto,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.outlined(
                tooltip: 'Página anterior',
                onPressed:
                    _pagina > 1 && !_consultando
                        ? () => _cambiarPagina(
                              _pagina - 1,
                            )
                        : null,
                icon: const Icon(
                  Icons.chevron_left,
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                child: Text(
                  'Página $_pagina de ${_totalPaginas == 0 ? 1 : _totalPaginas}',
                ),
              ),
              IconButton.outlined(
                tooltip: 'Página siguiente',
                onPressed:
                    _pagina < _totalPaginas &&
                            !_consultando
                        ? () => _cambiarPagina(
                              _pagina + 1,
                            )
                        : null,
                icon: const Icon(
                  Icons.chevron_right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contenidoPrincipal() {
    return Container(
      width: double.infinity,
      decoration: _tarjetaDecoracion(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          if (_cargando)
            const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          _tabla(),
          const Divider(height: 1),
          _paginacion(),
        ],
      ),
    );
  }

  Widget _datoDetalle(
    String etiqueta,
    String valor, {
    IconData? icono,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icono ?? Icons.info_outline,
            size: 18,
            color: const Color(0xFF64748B),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: Text(
              etiqueta,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              valor,
              style: const TextStyle(
                color: _texto,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionTitulo(
    String titulo,
    IconData icono,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FF),
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: Icon(
            icono,
            color: const Color(0xFF1764C0),
            size: 19,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              color: _texto,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _cambiosDetalle(
    Map<String, dynamic> cambios,
  ) {
    if (cambios.isEmpty) {
      return const Text(
        'No se detectaron cambios en los campos auditables.',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            WidgetStateProperty.all(
          const Color(0xFFEAF8E8),
        ),
        columnSpacing: 18,
        dataRowMinHeight: 55,
        dataRowMaxHeight: 100,
        columns: const [
          DataColumn(
            label: Text('Campo modificado'),
          ),
          DataColumn(
            label: Text('Valor anterior'),
          ),
          DataColumn(
            label: Text('Valor nuevo'),
          ),
        ],
        rows: cambios.entries.map((entrada) {
          final valores = _mapa(entrada.value);

          return DataRow(
            cells: [
              DataCell(
                Text(
                  _campoLegible(entrada.key),
                ),
              ),
              DataCell(
                _etiqueta(
                  _valor(valores?['anterior']),
                  fondo:
                      const Color(0xFFFFEEEE),
                  color:
                      const Color(0xFFB42318),
                ),
              ),
              DataCell(
                _etiqueta(
                  _valor(valores?['nuevo']),
                  fondo:
                      const Color(0xFFEAF8EA),
                  color:
                      const Color(0xFF167337),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _detalleContenido(
    Map<String, dynamic> registro,
  ) {
    final detalle =
        _mapa(registro['detalle']);
    final cambios =
        _mapa(detalle?['cambios']);
    final datos =
        _mapa(detalle?['datosRegistrados']);

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _seccionTitulo(
          'Información general',
          Icons.info_outline,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius:
                BorderRadius.circular(14),
            border:
                Border.all(color: _borde),
          ),
          child: Column(
            children: [
              _datoDetalle(
                'Administrador',
                '${registro['administradorId'] ?? '—'}',
                icono: Icons.person_outline,
              ),
              _datoDetalle(
                'Acción',
                _accionLegible(
                  '${registro['accion'] ?? '—'}',
                ),
                icono: Icons.edit_outlined,
              ),
              _datoDetalle(
                'Entidad',
                '${registro['entidad'] ?? '—'}',
                icono:
                    Icons.inventory_2_outlined,
              ),
              _datoDetalle(
                'ID afectado',
                '${registro['entidadId'] ?? '—'}',
                icono: Icons.tag,
              ),
              _datoDetalle(
                'Fecha',
                _fecha(registro['creadoEn']),
                icono:
                    Icons.calendar_today_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        _seccionTitulo(
          cambios != null
              ? 'Cambios realizados'
              : 'Detalle del registro',
          Icons.compare_arrows,
        ),
        const SizedBox(height: 14),
        if (cambios != null)
          _cambiosDetalle(cambios)
        else if (datos != null)
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: datos.entries
                .map(
                  (e) => _datoDetalle(
                    _campoLegible(e.key),
                    _valor(e.value),
                  ),
                )
                .toList(),
          )
        else if (detalle == null)
          const Text(
            'Este registro no contiene detalles. '
            'Puede haberse generado antes de '
            'habilitar el historial de cambios.',
          )
        else
          SelectableText(
            const JsonEncoder.withIndent('  ')
                .convert(detalle),
          ),
        if (detalle?['contrasenaModificada'] ==
            true) ...[
          const SizedBox(height: 16),
          const Text(
            'La contraseña fue modificada. '
            'Su contenido no se almacena por seguridad.',
            style: TextStyle(
              color: _verdeOscuro,
            ),
          ),
        ],
        if (cambios != null) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  const Color(0xFFEDF6FF),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Text(
              'Solo se muestran los campos que tuvieron cambios. '
              'Los demás permanecen sin modificaciones.',
              style: TextStyle(
                color: Color(0xFF1764C0),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _panelDetalle(
    Map<String, dynamic> registro, {
    required bool movil,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: movil
          ? const BorderRadius.vertical(
              top: Radius.circular(24),
            )
          : const BorderRadius.horizontal(
              left: Radius.circular(24),
            ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: !movil,
        child: Column(
          children: [
            if (movil)
              Container(
                margin:
                    const EdgeInsets.only(
                  top: 12,
                  bottom: 6,
                ),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFCBD5E1),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                24,
                22,
                18,
                18,
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFE8F7E8),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: _verdeOscuro,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Auditoría #${registro['id'] ?? '—'}',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.bold,
                        color: _texto,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () =>
                        Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.all(24),
                child: _detalleContenido(
                  registro,
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.all(16),
              child: Align(
                alignment:
                    Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).pop(),
                  child:
                      const Text('Cerrar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDetalle(
    Map<String, dynamic> registro,
  ) {
    final ancho =
        MediaQuery.sizeOf(context).width;

    if (ancho < 700) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor:
            Colors.transparent,
        useSafeArea: true,
        showDragHandle: false,
        builder: (context) {
          return FractionallySizedBox(
            heightFactor: 0.88,
            child: _panelDetalle(
              registro,
              movil: true,
            ),
          );
        },
      );
      return;
    }

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar detalle',
      barrierColor:
          Colors.black.withValues(
        alpha: 0.42,
      ),
      transitionDuration:
          const Duration(
        milliseconds: 280,
      ),
      pageBuilder: (
        dialogContext,
        animation,
        secondaryAnimation,
      ) {
        return Align(
          alignment:
              Alignment.centerRight,
          child: SizedBox(
            width: ancho < 1050
                ? ancho * 0.70
                : 600,
            height: double.infinity,
            child: _panelDetalle(
              registro,
              movil: false,
            ),
          ),
        );
      },
      transitionBuilder: (
        context,
        animation,
        secondaryAnimation,
        child,
      ) {
        final desplazamiento =
            Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
        );

        return SlideTransition(
          position: desplazamiento,
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _fondo,
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 1500,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _encabezado(),
                const SizedBox(height: 24),
                _filtros(),
                const SizedBox(height: 24),
                _contenidoPrincipal(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
