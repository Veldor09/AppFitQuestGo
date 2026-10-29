import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Servicio singleton que monitorea el estado de la conexión a internet
/// y notifica a las pantallas cuando la conexión se restablece.
class ConexionServicio {
  ConexionServicio._();

  static final ConexionServicio instancia = ConexionServicio._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscripcion;

  /// Notificador que emite un incremento cada vez que el dispositivo
  /// recupera conexión a internet (WiFi, Móvil o Ethernet).
  final ValueNotifier<int> reconectado = ValueNotifier<int>(0);

  bool _tieneConexion = true;
  bool _inicializado = false;

  bool get tieneConexion => _tieneConexion;

  /// Inicia la escucha de eventos de red. Es seguro llamarlo múltiples veces.
  void inicializar() {
    if (_inicializado) return;
    _inicializado = true;

    _connectivity.checkConnectivity().then(_actualizarEstado).catchError((_) {});

    try {
      _subscripcion = _connectivity.onConnectivityChanged.listen(
        _actualizarEstado,
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _actualizarEstado(List<ConnectivityResult> resultados) {
    final bool nuevaConexion = resultados.any(
      (ConnectivityResult r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );

    if (!_tieneConexion && nuevaConexion) {
      reconectado.value++;
    }
    _tieneConexion = nuevaConexion;
  }

  /// Limpia los recursos (usado principalmente en pruebas).
  @visibleForTesting
  void dispose() {
    _subscripcion?.cancel();
    _subscripcion = null;
    _inicializado = false;
  }
}

