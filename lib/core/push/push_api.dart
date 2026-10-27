import 'package:fit_quest_go/core/api/api_client.dart';

/// Le dice al servidor que este telefono acepta (o ya no acepta) avisos fuera
/// de la app.
class PushApi {
  PushApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// [plataforma] es `android` o `ios`; [idioma], `es`, `en` o `pt`: en el
  /// idioma de la app es como se escribe el aviso.
  Future<void> registrar({
    required String token,
    required String plataforma,
    required String idioma,
  }) async {
    await _client.post('/notificaciones/push/dispositivo', <String, Object?>{
      'token': token,
      'plataforma': plataforma,
      'idioma': idioma,
    });
  }

  Future<void> quitar(String token) async {
    await _client.post(
      '/notificaciones/push/dispositivo/baja',
      <String, Object?>{'token': token},
    );
  }
}
