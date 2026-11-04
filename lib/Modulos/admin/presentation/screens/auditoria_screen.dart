import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_toolbar.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_detail_dialog.dart';
import 'package:fit_quest_go/Modulos/admin/presentation/widgets/admin_data_table.dart';
import 'package:fit_quest_go/Modulos/usuarios/presentation/widgets/paginacion_bar.dart';

import 'package:fit_quest_go/Modulos/admin/data/auditoria_api.dart';
import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/l10n/gen/app_localizations.dart';

class AuditoriaScreen extends StatefulWidget {
  const AuditoriaScreen({super.key, this.api});

  /// Permite utilizar una API simulada durante las pruebas.
  /// En produccion se utiliza AuditoriaApi normalmente.
  final AuditoriaApi? api;

  @override
  State<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends State<AuditoriaScreen> {
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  late final AuditoriaApi _api = widget.api ?? AuditoriaApi();

  final TextEditingController _administradorController =
      TextEditingController();
  final TextEditingController _accionController = TextEditingController();
  final TextEditingController _entidadController = TextEditingController();
  final GlobalKey _filtrosKey = GlobalKey();

  int _limite = 5;
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

  Future<void> _cargarRegistros({bool silencioso = false}) async {
    if (_consultando) return;

    final administradorTexto = _filtroAdministrador.trim();
    final administradorId = administradorTexto.isEmpty
        ? null
        : int.tryParse(administradorTexto);

    if (administradorTexto.isNotEmpty &&
        (administradorId == null || administradorId < 1)) {
      if (!mounted) return;

      setState(() {
        _error = _l10n.admAudIdInvalido;
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

      final datos = respuesta['registros'] as List<dynamic>? ?? [];

      if (!mounted) return;

      setState(() {
        _registros = datos
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

        _total = (respuesta['total'] as num?)?.toInt() ?? 0;

        _totalPaginas = (respuesta['totalPaginas'] as num?)?.toInt() ?? 0;

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
        _error = _l10n.admAudErrorConsulta('$e');
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

    _filtroAdministrador = _administradorController.text.trim();
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
    if (_consultando || pagina < 1 || pagina > _totalPaginas) {
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

    String dos(int numero) => numero.toString().padLeft(2, '0');

    return '${dos(local.day)}/${dos(local.month)}/${local.year} '
        '${dos(local.hour)}:${dos(local.minute)}';
  }

  String _hora(DateTime fecha) {
    String dos(int numero) => numero.toString().padLeft(2, '0');

    return '${dos(fecha.hour)}:'
        '${dos(fecha.minute)}:'
        '${dos(fecha.second)}';
  }

  String _accionLegible(String accion) {
    final nombres = {
      'USUARIO_CREADO': _l10n.admAudAccUsuarioCreado,
      'USUARIO_ACTUALIZADO': _l10n.admAudAccUsuarioActualizado,
      'ESTADO_USUARIO_CAMBIADO': _l10n.admAudAccEstado,
    };

    return nombres[accion] ?? accion.replaceAll('_', ' ');
  }

  String _campoLegible(String campo) {
    final nombres = {
      'nombreUser': _l10n.admAudCampoNombre,
      'emailUser': _l10n.admDirColCorreo,
      'telefono': _l10n.admTelefono,
      'idrol': _l10n.perfilRol,
      'estado': _l10n.perfilEstado,
    };

    return nombres[campo] ?? campo;
  }

  String _valor(dynamic valor) {
    if (valor == null) return _l10n.admAudSinValor;
    if (valor is bool) return valor ? _l10n.admSi : _l10n.admNo;

    if (valor is Map || valor is List) {
      return const JsonEncoder.withIndent('  ').convert(valor);
    }

    final texto = valor.toString();
    return texto.isEmpty ? _l10n.admAudVacio : texto;
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
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
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
          Flexible(
            child: Text(
              texto,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _l10n.admAudTitulo,
                    style: TextStyle(
                      color: _texto,
                      fontSize: compacto ? 22 : 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _l10n.admAudSubtitulo,
                    style: const TextStyle(
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FAF0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD6EDD6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sync, color: _verdeOscuro, size: 21),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _l10n.admAudAuto,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _verdeOscuro,
                        fontSize: 12,
                      ),
                    ),
                    if (_ultimaActualizacion != null)
                      Text(
                        _l10n.admAudUltimaConsulta(
                          _hora(_ultimaActualizacion!),
                        ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titulo, const SizedBox(height: 18), estado],
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: const BorderSide(color: _borde),
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarFiltros() async {
    final boton = _filtrosKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (boton == null || overlay == null) return;
    final posicion = RelativeRect.fromRect(
      Rect.fromPoints(
        boton.localToGlobal(Offset.zero, ancestor: overlay),
        boton.localToGlobal(
          boton.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    await showMenu<void>(
      context: context,
      position: posicion,
      items: <PopupMenuEntry<void>>[
        PopupMenuItem<void>(
          enabled: false,
          child: SizedBox(
            width: 265,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _l10n.admBuscar,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _texto,
                  ),
                ),
                const SizedBox(height: 12),
                _campoFiltro(
                  _l10n.admAudIdAdmin,
                  _administradorController,
                  icono: Icons.person_outline,
                  teclado: TextInputType.number,
                  ejemplo: _l10n.admAudEjemploId,
                ),
                const SizedBox(height: 8),
                _campoFiltro(
                  _l10n.admAccion,
                  _accionController,
                  icono: Icons.list_alt_outlined,
                  ejemplo: 'USUARIO_ACTUALIZADO',
                ),
                const SizedBox(height: 8),
                _campoFiltro(
                  _l10n.admEntidad,
                  _entidadController,
                  icono: Icons.inventory_2_outlined,
                  ejemplo: 'USUARIO',
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _limpiarFiltros();
                      },
                      child: Text(_l10n.planificarLimpiar),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _aplicarFiltros();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _verde,
                        foregroundColor: _texto,
                      ),
                      child: Text(_l10n.admBuscar),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _filtros() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      AdminToolbar(
        searchHint: _l10n.admBuscar,
        showSearch: false,
        filtersKey: _filtrosKey,
        onFilters: _mostrarFiltros,
        onRefresh: _consultando ? null : () => _cargarRegistros(),
      ),
      if (_filtroAdministrador.isNotEmpty ||
          _filtroAccion.isNotEmpty ||
          _filtroEntidad.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            children: <Widget>[
              if (_filtroAdministrador.isNotEmpty)
                InputChip(
                  label: Text('${_l10n.admAudIdAdmin}: $_filtroAdministrador'),
                  onDeleted: () {
                    _administradorController.clear();
                    _aplicarFiltros();
                  },
                ),
              if (_filtroAccion.isNotEmpty)
                InputChip(
                  label: Text('${_l10n.admAccion}: $_filtroAccion'),
                  onDeleted: () {
                    _accionController.clear();
                    _aplicarFiltros();
                  },
                ),
              if (_filtroEntidad.isNotEmpty)
                InputChip(
                  label: Text('${_l10n.admEntidad}: $_filtroEntidad'),
                  onDeleted: () {
                    _entidadController.clear();
                    _aplicarFiltros();
                  },
                ),
            ],
          ),
        ),
    ],
  );

  Widget _tabla() {
    if (_registros.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            children: [
              const Icon(
                Icons.manage_search,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 12),
              Text(_l10n.admAudSinRegistros),
            ],
          ),
        ),
      );
    }

    return AdminDataTable(
      paginar: false,
      columns: <AdminTableColumn>[
        AdminTableColumn(_l10n.admAccion, width: 210),
        AdminTableColumn(_l10n.admAudAdministrador, width: 160),
        AdminTableColumn(_l10n.admEntidad, width: 135),
        AdminTableColumn(_l10n.admAudIdAfectado, width: 110),
        AdminTableColumn(_l10n.admFecha, width: 170),
      ],
      rows: <AdminRow>[
        for (final registro in _registros)
          AdminRow(
            icon: Icons.receipt_long_outlined,
            title: _accionLegible(registro['accion']?.toString() ?? '—'),
            values: <String>[
              registro['administradorId']?.toString() ?? '—',
              registro['entidad']?.toString() ?? '—',
              registro['entidadId']?.toString() ?? '—',
              _fecha(registro['creadoEn']),
            ],
            subtitle: <String>[
              _l10n.admAudAdministrador,
              registro['administradorId']?.toString() ?? '—',
              registro['entidad']?.toString() ?? '—',
              _fecha(registro['creadoEn']),
            ].join(' · '),
            onTap: () => _mostrarDetalle(registro),
          ),
      ],
    );
  }

  Widget _paginacion() {
    return PaginacionBar(
      total: _total,
      pagina: _pagina - 1,
      filasPorPagina: _limite,
      opciones: const <int>[5, 10, 15, 20],
      onFilasPorPagina: (n) {
        setState(() {
          _limite = n;
          _pagina = 1;
        });
        _cargarRegistros();
      },
      onPagina: (p) => _cambiarPagina(p + 1),
    );
  }

  Widget _contenidoPrincipal() {
    return Container(
      width: double.infinity,
      decoration: _tarjetaDecoracion(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_cargando) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          _tabla(),
          const Divider(height: 1),
          _paginacion(),
        ],
      ),
    );
  }

  Widget _datoDetalle(String etiqueta, String valor, {IconData? icono}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
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

  Widget _seccionTitulo(String titulo, IconData icono) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icono, color: const Color(0xFF1764C0), size: 19),
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

  Widget _cambiosDetalle(Map<String, dynamic> cambios) {
    if (cambios.isEmpty) return Text(_l10n.admAudSinCambios);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final entrada in cambios.entries)
          Builder(
            builder: (context) {
              final valores = _mapa(entrada.value);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: _borde),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _campoLegible(entrada.key),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _texto,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(_l10n.admAudValorAnterior),
                    const SizedBox(height: 4),
                    _etiqueta(
                      _valor(valores?['anterior']),
                      fondo: const Color(0xFFFFEEEE),
                      color: const Color(0xFFB42318),
                    ),
                    const SizedBox(height: 10),
                    Text(_l10n.admAudValorNuevo),
                    const SizedBox(height: 4),
                    _etiqueta(
                      _valor(valores?['nuevo']),
                      fondo: const Color(0xFFEAF8EA),
                      color: const Color(0xFF167337),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _detalleContenido(Map<String, dynamic> registro) {
    final detalle = _mapa(registro['detalle']);
    final cambios = _mapa(detalle?['cambios']);
    final datos = _mapa(detalle?['datosRegistrados']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _seccionTitulo(_l10n.admAudInfoGeneral, Icons.info_outline),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borde),
          ),
          child: Column(
            children: [
              _datoDetalle(
                _l10n.admAudAdministrador,
                '${registro['administradorId'] ?? '—'}',
                icono: Icons.person_outline,
              ),
              _datoDetalle(
                _l10n.admAccion,
                _accionLegible('${registro['accion'] ?? '—'}'),
                icono: Icons.edit_outlined,
              ),
              _datoDetalle(
                _l10n.admEntidad,
                '${registro['entidad'] ?? '—'}',
                icono: Icons.inventory_2_outlined,
              ),
              _datoDetalle(
                _l10n.admAudIdAfectado,
                '${registro['entidadId'] ?? '—'}',
                icono: Icons.tag,
              ),
              _datoDetalle(
                _l10n.admFecha,
                _fecha(registro['creadoEn']),
                icono: Icons.calendar_today_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        _seccionTitulo(
          cambios != null ? _l10n.admAudCambios : _l10n.admAudDetalleRegistro,
          Icons.compare_arrows,
        ),
        const SizedBox(height: 14),
        if (cambios != null)
          _cambiosDetalle(cambios)
        else if (datos != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: datos.entries
                .map((e) => _datoDetalle(_campoLegible(e.key), _valor(e.value)))
                .toList(),
          )
        else if (detalle == null)
          Text(_l10n.admAudSinDetalles)
        else
          SelectableText(const JsonEncoder.withIndent('  ').convert(detalle)),
        if (detalle?['contrasenaModificada'] == true) ...[
          const SizedBox(height: 16),
          Text(
            _l10n.admAudContrasena,
            style: const TextStyle(color: _verdeOscuro),
          ),
        ],
        if (cambios != null) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _l10n.admAudSoloCambios,
              style: const TextStyle(color: Color(0xFF1764C0), fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  void _mostrarDetalle(Map<String, dynamic> registro) {
    mostrarDetalleAdmin(
      context,
      titulo: 'Auditoría #${registro['id'] ?? '—'}',
      icono: Icons.receipt_long_outlined,
      estado: _accionLegible(registro['accion']?.toString() ?? '—'),
      campos: const <String, String>{},
      extra: _detalleContenido(registro),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _fondo,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
