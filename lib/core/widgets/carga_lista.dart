import 'package:flutter/material.dart';

import 'package:fit_quest_go/core/red/conexion_servicio.dart';

class CargaLista<T> extends ChangeNotifier {
  CargaLista(this._pedir, {bool escucharReconexion = true}) {
    if (escucharReconexion) {
      ConexionServicio.instancia.reconectado.addListener(_alReconectar);
    }
  }

  final Future<List<T>> Function() _pedir;

  List<T>? _datos;
  Object? _error;
  bool _cargando = true;
  bool _cerrada = false;

  int _version = 0;

  List<T>? get datos => _datos;
  Object? get error => _error;
  bool get cargando => _cargando;

  void _alReconectar() {
    if (!_cerrada) {
      cargar(silencioso: _datos != null);
    }
  }

  Future<void> cargar({bool silencioso = false}) async {
    final int version = ++_version;
    if (!silencioso || _datos == null) {
      _cargando = true;
      _error = null;
      _avisar();
    }
    try {
      final List<T> nuevos = await _pedir();
      if (_cerrada || version != _version) return;
      _datos = nuevos;
      _error = null;
    } catch (e) {
      if (_cerrada || version != _version) return;
      if (_datos == null) _error = e;
    }
    _cargando = false;
    _avisar();
  }

  void quitar(bool Function(T elemento) donde) {
    final List<T>? actuales = _datos;
    if (actuales == null) return;
    _version++;
    _cargando = false;
    _datos = <T>[
      for (final T e in actuales)
        if (!donde(e)) e,
    ];
    _avisar();
  }

  void reemplazar(bool Function(T elemento) donde, T nuevo) {
    final List<T>? actuales = _datos;
    if (actuales == null) return;
    _datos = <T>[
      for (final T e in actuales)
        if (donde(e)) nuevo else e,
    ];
    _avisar();
  }

  void _avisar() {
    if (!_cerrada) notifyListeners();
  }

  @override
  void dispose() {
    _cerrada = true;
    ConexionServicio.instancia.reconectado.removeListener(_alReconectar);
    super.dispose();
  }
}

class CargaListaVista<T> extends StatelessWidget {
  const CargaListaVista({
    super.key,
    required this.carga,
    required this.datos,
    required this.error,
  });

  final CargaLista<T> carga;
  final Widget Function(BuildContext context, List<T> datos) datos;
  final Widget Function(BuildContext context, Object error) error;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: carga,
      builder: (BuildContext context, Widget? _) {
        final List<T>? lista = carga.datos;
        if (lista != null) return datos(context, lista);
        final Object? fallo = carga.error;
        if (fallo != null) return error(context, fallo);
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
