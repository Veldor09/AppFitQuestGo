import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:fit_quest_go/core/almacen_tokens.dart';
import 'package:fit_quest_go/core/api/api_config.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl, AlmacenTokens? tokens})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? apiBaseUrl,
      _tokens = tokens ?? AlmacenTokens();

  final http.Client _client;
  final String _baseUrl;
  final AlmacenTokens _tokens;

  Future<dynamic> get(String path) => _enviar('GET', path);

  Future<dynamic> post(String path, Object? body) => _enviar('POST', path, body);

  Future<dynamic> put(String path, Object? body) => _enviar('PUT', path, body);

  Future<dynamic> patch(String path, Object? body) =>
      _enviar('PATCH', path, body);

  Future<dynamic> delete(String path) => _enviar('DELETE', path);

  Future<dynamic> _enviar(
    String metodo,
    String path, [
    Object? body,
    bool permitirReintento = true,
  ]) async {
    final http.Response res = await _peticion(metodo, path, body);
    if (res.statusCode != 401 || !permitirReintento) {
      return _procesar(res);
    }
    final bool renovado = await _renovarToken();
    if (!renovado) {
      await _tokens.limpiar();
      return _procesar(res);
    }
    return _enviar(metodo, path, body, false);
  }

  Future<http.Response> _peticion(
    String metodo,
    String path,
    Object? body,
  ) async {
    final Uri uri = Uri.parse('$_baseUrl$path');
    final String? access = await _tokens.leerAccess();
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'X-Cliente-Movil': '1',
      if (access != null) 'Authorization': 'Bearer $access',
    };
    final String? cuerpo = body == null ? null : jsonEncode(body);
    switch (metodo) {
      case 'GET':
        return _client.get(uri, headers: headers);
      case 'POST':
        return _client.post(uri, headers: headers, body: cuerpo);
      case 'PUT':
        return _client.put(uri, headers: headers, body: cuerpo);
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: cuerpo);
      case 'DELETE':
        return _client.delete(uri, headers: headers);
      default:
        throw ArgumentError('Metodo no soportado: $metodo');
    }
  }

  Future<bool> _renovarToken() async {
    final String? refresh = await _tokens.leerRefresh();
    if (refresh == null) return false;
    try {
      final http.Response res = await _client.post(
        Uri.parse('$_baseUrl/auth/renovar'),
        headers: const {
          'Content-Type': 'application/json',
          'X-Cliente-Movil': '1',
        },
        body: jsonEncode({'refreshToken': refresh}),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      await _tokens.guardar(
        access: data['accessToken'] as String,
        refresh: (data['refreshToken'] ?? refresh) as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  dynamic _procesar(http.Response res) {
    final dynamic body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(res.statusCode, _mensajeError(body, res));
  }

  String _mensajeError(dynamic body, http.Response res) {
    if (body is Map && body['message'] != null) {
      final dynamic m = body['message'];
      // El ValidationPipe de Nest devuelve una lista de mensajes.
      if (m is List) return m.map((dynamic e) => e.toString()).join('\n');
      return m.toString();
    }
    return res.reasonPhrase ?? 'Error ${res.statusCode}';
  }

  void close() => _client.close();
}
