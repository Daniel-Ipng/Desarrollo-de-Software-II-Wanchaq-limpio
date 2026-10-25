import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  final String? code;
  final int? status;
  ApiException(this.message, {this.code, this.status});
  @override
  String toString() => message;
}

/// Cliente de la API EcoRutas (equivalente a frontend/public/js/utils/api.js).
class Api {
  static const _kSesion = 'ecocusco_sesion';
  static String? _token;

  /// Usuario en sesión. Cuando pasa a null, la app vuelve sola al login.
  static final ValueNotifier<Usuario?> sesion = ValueNotifier<Usuario?>(null);

  // ---------------------------------------------------------------- sesión
  static Future<void> cargarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSesion);
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _token = m['token'] as String;
      sesion.value = Usuario.fromJson(m['usuario'] as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(_kSesion);
    }
  }

  static Future<void> _guardarSesion(String token, Map<String, dynamic> usuarioJson) async {
    final u = Usuario.fromJson(usuarioJson);
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSesion, jsonEncode({'token': token, 'usuario': u.toJson()}));
    sesion.value = u;
  }

  static Future<void> cerrarSesion() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSesion);
    sesion.value = null;
  }

  // ------------------------------------------------------------ transporte
  static Uri _uri(String ruta) => Uri.parse('${Config.apiBase}$ruta');

  static Map<String, String> _headers({bool auth = true, bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        if (auth && _token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<Map<String, dynamic>> _enviar(
    Future<http.Response> Function() peticion, {
    bool auth = true,
  }) async {
    http.Response r;
    try {
      // 45 s: el plan gratuito de Render tarda en "despertar" la primera vez.
      r = await peticion().timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder. Inténtalo de nuevo.',
          code: 'TIMEOUT');
    } on SocketException {
      throw ApiException(
          'No se pudo conectar con el servidor de EcoRutas Wanchaq. Verifica tu conexión.',
          code: 'SIN_CONEXION');
    } on http.ClientException {
      throw ApiException(
          'No se pudo conectar con el servidor de EcoRutas Wanchaq. Verifica tu conexión.',
          code: 'SIN_CONEXION');
    }

    var cuerpo = <String, dynamic>{};
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is Map<String, dynamic>) cuerpo = d;
    } catch (_) {/* respuesta sin JSON */}

    if (auth && (r.statusCode == 401 || r.statusCode == 403)) {
      await cerrarSesion();
      throw ApiException(
        (cuerpo['message'] as String?) ?? 'Tu sesión expiró. Inicia sesión nuevamente.',
        code: cuerpo['code'] as String?,
        status: r.statusCode,
      );
    }

    if (r.statusCode < 200 || r.statusCode >= 300 || cuerpo['success'] == false) {
      throw ApiException(
        (cuerpo['message'] as String?) ?? 'Ocurrió un error inesperado.',
        code: cuerpo['code'] as String?,
        status: r.statusCode,
      );
    }
    return cuerpo;
  }

  static List<Map<String, dynamic>> _lista(Map<String, dynamic> c) =>
      ((c['data'] as List?) ?? const []).cast<Map<String, dynamic>>();

  // ------------------------------------------------------------------ auth
  static Future<void> login(String identificador, String password) async {
    final c = await _enviar(
      () => http.post(
        _uri('/auth/login'),
        headers: _headers(auth: false, json: true),
        body: jsonEncode({'identificador': identificador.trim(), 'password': password}),
      ),
      auth: false,
    );
    final data = c['data'] as Map<String, dynamic>;
    if (data['requiere2FA'] == true) {
      throw ApiException(
        'Las cuentas de operador y administrador ingresan por el panel web '
        '(requieren verificación en dos pasos).',
        code: 'REQUIERE_2FA',
      );
    }
    await _guardarSesion(data['token'] as String, data['usuario'] as Map<String, dynamic>);
  }

  static Future<void> registrarCiudadano({
    required String correo,
    required String dni,
    required String nombres,
    required String apellidos,
    required String telefono,
    required String password,
    required String zona,
    required String direccion,
  }) async {
    final c = await _enviar(
      () => http.post(
        _uri('/auth/registro-ciudadano'),
        headers: _headers(auth: false, json: true),
        body: jsonEncode({
          'correo': correo.trim(),
          'dni': dni.trim(),
          'nombres': nombres.trim(),
          'apellidos': apellidos.trim(),
          'telefono': telefono.trim(),
          'password': password,
          'zona': zona,
          'direccion': direccion.trim(),
        }),
      ),
      auth: false,
    );
    final data = c['data'] as Map<String, dynamic>;
    await _guardarSesion(data['token'] as String, data['usuario'] as Map<String, dynamic>);
  }

  // -------------------------------------------------------------- catálogos
  static Future<List<Zona>> zonas() async {
    final c = await _enviar(() => http.get(_uri('/zonas'), headers: _headers(auth: false)),
        auth: false);
    return _lista(c).map(Zona.fromJson).toList();
  }

  static Future<List<TipoResiduo>> tiposResiduo() async {
    final c = await _enviar(
        () => http.get(_uri('/tipos-residuo'), headers: _headers(auth: false)),
        auth: false);
    return _lista(c).map(TipoResiduo.fromJson).toList();
  }

  // -------------------------------------------------------------------- GPS
  static Future<List<CamionGps>> gpsActivos() async {
    final c = await _enviar(() => http.get(_uri('/gps/activos'), headers: _headers()));
    return _lista(c).map(CamionGps.fromJson).toList();
  }

  // ------------------------------------------------------------ incidencias
  static Future<List<Incidencia>> misIncidencias() async {
    final c = await _enviar(
        () => http.get(_uri('/incidencias/mis-incidencias'), headers: _headers()));
    return _lista(c).map(Incidencia.fromJson).toList();
  }

  static Future<void> crearIncidencia({
    required String tipo,
    required String descripcion,
    required String zona,
    required String direccion,
    double? lat,
    double? lng,
    File? foto,
  }) async {
    await _enviar(() async {
      final req = http.MultipartRequest('POST', _uri('/incidencias'))
        ..headers.addAll(_headers())
        ..fields.addAll({
          'tipo': tipo,
          'descripcion': descripcion,
          'zona': zona,
          'direccion': direccion,
          'prioridad': 'media',
          if (lat != null && lng != null) ...{'lat': '$lat', 'lng': '$lng'},
        });
      if (foto != null) {
        req.files.add(await http.MultipartFile.fromPath('foto', foto.path));
      }
      return http.Response.fromStream(await req.send());
    });
  }
}
