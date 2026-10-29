import 'package:flutter/material.dart';

import 'package:fit_quest_go/l10n/gen/app_localizations.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuario.dart';
import 'package:fit_quest_go/Modulos/usuarios/data/usuarios_api.dart';
import 'package:fit_quest_go/Modulos/usuarios/presentation/usuario_detalle_screen.dart';

/// ADM-03: directorio independiente para consultar perfiles de usuarios.
class DirectorioUsuariosScreen extends StatefulWidget {
  const DirectorioUsuariosScreen({super.key, this.api});

  final UsuariosApi? api;

  @override
  State<DirectorioUsuariosScreen> createState() =>
      _DirectorioUsuariosScreenState();
}

class _DirectorioUsuariosScreenState extends State<DirectorioUsuariosScreen> {
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  late final UsuariosApi _api = widget.api ?? UsuariosApi();

  static const Color _fondo = Color(0xFFF5F7FA);
  static const Color _texto = Color(0xFF18243A);
  static const Color _borde = Color(0xFFE2E8F0);
  static const Color _verde = Color(0xFFA9F32D);

  final TextEditingController _busquedaController = TextEditingController();

  List<Usuario> _usuarios = <Usuario>[];
  Usuario? _seleccionado;
  bool _cargando = true;
  String? _error;
  String _busqueda = '';
  int? _rol;
  bool? _activo;
  bool _ascendente = true;
  int _pagina = 1;

  static const int _porPagina = 10;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final usuarios = await _api.list();
      if (!mounted) return;

      setState(() {
        _usuarios = usuarios;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = _l10n.admDirErrorCarga('$error');
        _cargando = false;
      });
    }
  }

  List<Usuario> get _filtrados {
    final texto = _busqueda.toLowerCase().trim();

    final resultado = _usuarios.where((usuario) {
      final coincideBusqueda =
          usuario.nombreUser.toLowerCase().contains(texto) ||
          usuario.emailUser.toLowerCase().contains(texto);

      final coincideRol = _rol == null || usuario.idrol == _rol;
      final coincideEstado = _activo == null || usuario.activo == _activo;

      return coincideBusqueda && coincideRol && coincideEstado;
    }).toList();

    resultado.sort((a, b) {
      final comparacion = a.nombreUser.toLowerCase().compareTo(
        b.nombreUser.toLowerCase(),
      );
      if (comparacion != 0) {
        return _ascendente ? comparacion : -comparacion;
      }
      return a.id.compareTo(b.id);
    });

    return resultado;
  }

  void _actualizarFiltros(VoidCallback cambio) {
    setState(() {
      cambio();
      _pagina = 1;
    });
  }

  BoxDecoration _decoracion() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _borde),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.035),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _encabezado() {
    return Row(
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F7E8),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.manage_accounts_outlined,
            color: Color(0xFF277A35),
            size: 29,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _l10n.admDirTitulo,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _texto,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _l10n.admDirSubtitulo,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        IconButton.outlined(
          tooltip: _l10n.admDirActualizar,
          onPressed: _cargando ? null : _cargar,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _filtros() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _decoracion(),
      child: Wrap(
        spacing: 12,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 300,
            child: TextField(
              controller: _busquedaController,
              onChanged: (valor) => _actualizarFiltros(() {
                _busqueda = valor;
              }),
              decoration: InputDecoration(
                labelText: _l10n.admDirBuscar,
                hintText: _l10n.admDirBuscarHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<int?>(
              initialValue: _rol,
              decoration: InputDecoration(
                labelText: _l10n.perfilRol,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: <DropdownMenuItem<int?>>[
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(_l10n.usuariosFiltroTodos),
                ),
                DropdownMenuItem<int?>(value: 1, child: Text(_l10n.rolUsuario)),
                DropdownMenuItem<int?>(value: 2, child: Text(_l10n.rolEmpresa)),
                DropdownMenuItem<int?>(value: 3, child: Text(_l10n.rolAdmin)),
              ],
              onChanged: (valor) => _actualizarFiltros(() {
                _rol = valor;
              }),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<bool?>(
              initialValue: _activo,
              decoration: InputDecoration(
                labelText: _l10n.perfilEstado,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: <DropdownMenuItem<bool?>>[
                DropdownMenuItem<bool?>(
                  value: null,
                  child: Text(_l10n.usuariosFiltroTodos),
                ),
                DropdownMenuItem<bool?>(
                  value: true,
                  child: Text(_l10n.admDirActivados),
                ),
                DropdownMenuItem<bool?>(
                  value: false,
                  child: Text(_l10n.admDirDesactivados),
                ),
              ],
              onChanged: (valor) => _actualizarFiltros(() {
                _activo = valor;
              }),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _actualizarFiltros(() {
              _ascendente = !_ascendente;
            }),
            icon: const Icon(Icons.sort_by_alpha),
            label: Text(
              _ascendente ? _l10n.admDirNombreAZ : _l10n.admDirNombreZA,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              _busquedaController.clear();
              _actualizarFiltros(() {
                _busqueda = '';
                _rol = null;
                _activo = null;
                _ascendente = true;
              });
            },
            icon: const Icon(Icons.close),
            label: Text(_l10n.admLimpiarFiltros),
          ),
        ],
      ),
    );
  }

  Widget _tabla() {
    final usuarios = _filtrados;
    final totalPaginas = usuarios.isEmpty
        ? 1
        : (usuarios.length / _porPagina).ceil();
    final pagina = _pagina.clamp(1, totalPaginas);
    final inicio = (pagina - 1) * _porPagina;
    final visibles = usuarios.skip(inicio).take(_porPagina).toList();

    return Container(
      width: double.infinity,
      decoration: _decoracion(),
      child: Column(
        children: <Widget>[
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          else if (usuarios.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Text(_l10n.admDirSinResultados),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final ancho = constraints.maxWidth < 850
                    ? 850.0
                    : constraints.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: ancho,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF8FAFC),
                      ),
                      dataRowMinHeight: 65,
                      dataRowMaxHeight: 76,
                      columns: <DataColumn>[
                        DataColumn(label: Text(_l10n.rolUsuario)),
                        DataColumn(label: Text(_l10n.admDirColCorreo)),
                        DataColumn(label: Text(_l10n.perfilRol)),
                        DataColumn(label: Text(_l10n.perfilEstado)),
                        DataColumn(label: Text(_l10n.admDetalle)),
                      ],
                      rows: visibles.map((usuario) {
                        return DataRow(
                          cells: <DataCell>[
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  CircleAvatar(
                                    backgroundColor: _verde,
                                    child: Text(
                                      usuario.iniciales,
                                      style: const TextStyle(
                                        color: _texto,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(usuario.nombreUser),
                                ],
                              ),
                            ),
                            DataCell(Text(usuario.emailUser)),
                            DataCell(Text(usuario.etiquetaRol)),
                            DataCell(
                              Text(
                                usuario.estado,
                                style: TextStyle(
                                  color: usuario.activo
                                      ? const Color(0xFF277A35)
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                            DataCell(
                              OutlinedButton.icon(
                                onPressed: () => setState(() {
                                  _seleccionado = usuario;
                                }),
                                icon: const Icon(
                                  Icons.visibility_outlined,
                                  size: 17,
                                ),
                                label: Text(_l10n.admDirVerDetalle),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Wrap(
              spacing: 14,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(_l10n.admDirTotal(usuarios.length)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton.outlined(
                      tooltip: _l10n.admPaginaAnterior,
                      onPressed: pagina > 1
                          ? () => setState(() {
                              _pagina = pagina - 1;
                            })
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(_l10n.admPaginaDe(pagina, totalPaginas)),
                    ),
                    IconButton.outlined(
                      tooltip: _l10n.admPaginaSiguiente,
                      onPressed: pagina < totalPaginas
                          ? () => setState(() {
                              _pagina = pagina + 1;
                            })
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_seleccionado != null) {
      return UsuarioDetalleScreen(
        key: ValueKey<int>(_seleccionado!.id),
        usuario: _seleccionado!,
        api: _api,
        onVolver: () => setState(() {
          _seleccionado = null;
        }),
      );
    }

    return ColoredBox(
      color: _fondo,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _encabezado(),
                const SizedBox(height: 24),
                _filtros(),
                const SizedBox(height: 24),
                _tabla(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
