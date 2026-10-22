import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Una lista que se pide al servidor y que se puede cambiar sin repintar la
/// pantalla entera.
///
/// Con un `FutureBuilder` cada recarga vuelve a mostrar el circulo de carga y
/// reconstruye toda la lista, aunque solo se haya borrado un elemento. Aqui:
/// - [cargar] con `silencioso: true` pide los datos de nuevo SIN tocar lo que
///   ya se ve y los cambia cuando llegan (si falla, deja lo que habia);
/// - [quitar] saca un elemento al instante, sin pedir nada;
/// - el circulo de carga y el error solo salen mientras no hay datos.
class CargaLista<T> extends ChangeNotifier {
  CargaLista(this._pedir);

  final Future<List<T>> Function() _pedir;

  List<T>? _datos;
  Object? _error;
  bool _cargando = true;
  bool _cerrada = false;

  /// Cada carga lleva un numero: si mientras tanto se quito o se pidio algo
  /// mas nuevo, la respuesta vieja se descarta (no resucita lo que se borro).
  int _version = 0;

  /// Null mientras no han llegado los primeros datos.
  List<T>? get datos => _datos;
  Object? get error => _error;
  bool get cargando => _cargando;

  /// Pide la lista. [silencioso] no muestra el circulo de carga ni borra el
  /// error de la pantalla: sirve para refrescar lo que ya se ve.
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
      // Un refresco silencioso que falla no tira abajo lo que ya se ve.
      if (_datos == null) _error = e;
    }
    _cargando = false;
    _avisar();
  }

  /// Saca de la lista, ya, los elementos que cumplan [donde].
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

  /// Cambia un elemento por su version nueva (el que cumple [donde]).
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
    super.dispose();
  }
}

/// Dibuja una [CargaLista]: el circulo de carga o el error mientras no hay
/// datos y, con datos, [datos]. Solo se reconstruye cuando la lista cambia.
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
