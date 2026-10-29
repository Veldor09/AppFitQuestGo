import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'package:fit_quest_go/core/almacen_tokens.dart';

/// Servicio encargado de la autenticación biométrica (huella digital o reconocimiento facial).
/// Utiliza el hardware seguro del dispositivo (Keystore en Android / Secure Enclave en iOS)
/// para validar la identidad de forma local sin enviar datos biométricos por la red.
class BiometriaServicio {
  BiometriaServicio({LocalAuthentication? auth, AlmacenTokens? tokens})
      : _auth = auth ?? LocalAuthentication(),
        _tokens = tokens ?? AlmacenTokens();

  static final BiometriaServicio instancia = BiometriaServicio();

  final LocalAuthentication _auth;
  final AlmacenTokens _tokens;

  /// Verifica si el hardware del dispositivo soporta biometría (huella o rostro)
  /// y si el usuario tiene al menos una biometría registrada en su teléfono.
  Future<bool> get dispositivoSoportado async {
    try {
      final bool puedeRevisar = await _auth.canCheckBiometrics;
      final bool esSoportado = await _auth.isDeviceSupported();
      return puedeRevisar || esSoportado;
    } catch (e) {
      debugPrint('Error comprobando soporte biométrico: $e');
      return false;
    }
  }

  /// Verifica los tipos de biometría disponibles en el dispositivo (huella, rostro, etc.).
  Future<List<BiometricType>> obtenerBiometriasDisponibles() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const <BiometricType>[];
    }
  }

  /// Indica si el usuario tiene credenciales activas guardadas para ingresar con huella.
  Future<bool> estaHabilitada() async {
    return await _tokens.tieneCredencialBiometrica();
  }

  /// Solicita al sistema operativo la lectura de la huella digital o rostro.
  /// Retorna `true` si la autenticación fue exitosa, o `false` si fue cancelada o fallida.
  Future<bool> autenticar({
    String motivo = 'Coloca tu huella para acceder a FitQuest Go',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permite PIN del teléfono como respaldo si falla
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      debugPrint('Error durante la autenticación biométrica: $e');
      return false;
    }
  }
}
