import 'dart:ui' show Locale;

import 'package:flutter_tts/flutter_tts.dart';

/// Avisos hablados (p. ej. "alerta cerca de ti"). Es una interfaz para poder
/// reemplazar el motor de voz por uno falso en las pruebas.
abstract class AvisoVoz {
  /// Lee `texto` en voz alta con el motor de voz del dispositivo.
  Future<void> decir(String texto, {required Locale idioma});

  /// Corta lo que se este diciendo.
  Future<void> detener();
}

/// Etiqueta de idioma BCP-47 que entiende el motor de voz de Android para el
/// idioma de la app (es / en / pt_BR).
String etiquetaDeVoz(Locale idioma) {
  switch (idioma.languageCode) {
    case 'en':
      return 'en-US';
    case 'pt':
      return 'pt-BR';
    default:
      return 'es-ES';
  }
}

/// [AvisoVoz] sobre `flutter_tts`. Es de mejor esfuerzo: sin motor de voz
/// instalado (emuladores sin Google TTS) o con el volumen en cero no pasa nada
/// y el aviso en pantalla sigue ahi.
class AvisoVozTts implements AvisoVoz {
  AvisoVozTts([FlutterTts? motor]) : _motor = motor ?? FlutterTts();

  final FlutterTts _motor;

  @override
  Future<void> decir(String texto, {required Locale idioma}) async {
    try {
      await _motor.setLanguage(etiquetaDeVoz(idioma));
      await _motor.speak(texto);
    } catch (_) {
      // Sin motor de voz: solo se ve el aviso.
    }
  }

  @override
  Future<void> detener() async {
    try {
      await _motor.stop();
    } catch (_) {}
  }
}
