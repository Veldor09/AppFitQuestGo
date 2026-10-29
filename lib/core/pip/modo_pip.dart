import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ventana flotante (Picture-in-Picture) de Android mientras se sigue una
/// ruta o un evento. La parte nativa vive en `MainActivity.kt`.
///
/// Las pantallas de seguimiento llaman a [habilitar] al abrirse y a
/// [deshabilitar] al cerrarse. Con eso, al salir de la app el sistema reduce
/// la pantalla a una ventanita; [activo] avisa cuando se entra o se sale de
/// ella para que la pantalla oculte sus controles y deje solo el mapa.
class ModoPip {
  ModoPip._() {
    _canal.setMethodCallHandler(_alRecibir);
  }

  static final ModoPip instancia = ModoPip._();

  static const MethodChannel _canal = MethodChannel('fitquest/pip');

  /// true mientras la app se muestra dentro de la ventana flotante.
  final ValueNotifier<bool> activo = ValueNotifier<bool>(false);

  /// Pantallas de seguimiento abiertas (por si se apilan dos).
  int _pantallas = 0;

  bool? _soportado;

  bool get _esAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Si el telefono permite ventana flotante (Android 8+ y no desactivada).
  Future<bool> soportado() async {
    if (!_esAndroid) return false;
    final bool? cache = _soportado;
    if (cache != null) return cache;
    try {
      _soportado = await _canal.invokeMethod<bool>('soportado') ?? false;
    } catch (_) {
      _soportado = false;
    }
    return _soportado!;
  }

  Future<void> habilitar() async {
    _pantallas++;
    if (_pantallas == 1) await _invocar('habilitar', true);
  }

  Future<void> deshabilitar() async {
    if (_pantallas == 0) return;
    _pantallas--;
    if (_pantallas == 0) await _invocar('habilitar', false);
  }

  /// Entra a la ventana flotante ya (boton dentro de la pantalla).
  Future<bool> entrar() async => await _invocar('entrar') == true;

  Future<Object?> _invocar(String metodo, [Object? argumentos]) async {
    if (!_esAndroid) return null;
    try {
      return await _canal.invokeMethod<Object?>(metodo, argumentos);
    } catch (_) {
      // Sin plataforma nativa (pruebas) o sin soporte: se ignora.
      return null;
    }
  }

  Future<void> _alRecibir(MethodCall llamada) async {
    if (llamada.method == 'cambio') activo.value = llamada.arguments == true;
  }
}

