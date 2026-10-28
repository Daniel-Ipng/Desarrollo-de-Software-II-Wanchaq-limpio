import 'dart:convert';

import 'package:http/http.dart' as http;

/// Excepción personalizada para errores de la API.
class ApiException implements Exception {
  final String mensaje;
  final int? codigoHttp;

  const ApiException(this.mensaje, {this.codigoHttp});

  @override
  String toString() => 'ApiException: $mensaje (HTTP $codigoHttp)';
}

/// Cliente HTTP centralizado para la comunicación con el backend de EcoRutas.
///
/// Las solicitudes protegidas envían el JWT configurado como Bearer.
class ApiService {
  static const String _baseUrl = 'http://localhost:3000/api';

  final http.Client _client;
  String? _token;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  void setToken(String token) => _token = token;

  void clearToken() => _token = null;

  bool get autenticado => _token != null;

  Map<String, String> get _cabeceras => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> cuerpo,
  ) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final respuesta = await _client
        .post(uri, headers: _cabeceras, body: jsonEncode(cuerpo))
        .timeout(const Duration(seconds: 15));
    return _procesarRespuesta(respuesta) as Map<String, dynamic>;
  }

  Future<dynamic> get(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final respuesta = await _client
        .get(uri, headers: _cabeceras)
        .timeout(const Duration(seconds: 15));
    return _procesarRespuesta(respuesta);
  }

  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> cuerpo,
  ) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final respuesta = await _client
        .put(uri, headers: _cabeceras, body: jsonEncode(cuerpo))
        .timeout(const Duration(seconds: 15));
    return _procesarRespuesta(respuesta) as Map<String, dynamic>;
  }

  dynamic _procesarRespuesta(http.Response respuesta) {
    final cuerpo = utf8.decode(respuesta.bodyBytes);
    final dynamic datos = jsonDecode(cuerpo);

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return datos;
    }

    final mensaje = (datos is Map && datos['mensaje'] is String)
        ? datos['mensaje'] as String
        : 'Error inesperado del servidor';

    throw ApiException(mensaje, codigoHttp: respuesta.statusCode);
  }
}
