import 'package:fit_quest_go/core/api/api_client.dart';
import 'package:fit_quest_go/Modulos/clima/data/alerta_clima.dart';

class ClimaApi {
  ClimaApi([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// Avisos de lluvia fuerte, tormenta o calor extremo en la zona de (`lat`,
  /// `lng`). 503 (`ApiException`) si el proveedor del clima no esta disponible.
  Future<RespuestaClima> alertas({
    required double lat,
    required double lng,
  }) async {
    final dynamic data = await _client.get('/clima/alertas?lat=$lat&lng=$lng');
    final Map<String, dynamic> cuerpo = data as Map<String, dynamic>;
    final List<dynamic> crudas = cuerpo['alertas'] as List<dynamic>? ?? <dynamic>[];
    return RespuestaClima(
      alertas: <AlertaClima>[
        for (final dynamic a in crudas)
          ?AlertaClima.desdeJson(a as Map<String, dynamic>),
      ],
      fuente: cuerpo['fuente'] as String? ?? '',
    );
  }
}
