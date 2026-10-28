import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reporte.dart';
import '../models/zona.dart';
import '../models/modulos_ciudadanos.dart';
import '../services/supabase_service.dart';

/// Resultado de una operación sobre reportes.
class ResultadoReporte {
  final bool exito;
  final String? error;
  final Reporte? reporte;
  final int? codigoHttp;

  const ResultadoReporte.exitoso(this.reporte)
    : exito = true,
      error = null,
      codigoHttp = null;

  const ResultadoReporte.fallido(this.error, {this.codigoHttp})
    : exito = false,
      reporte = null;
}

/// Repositorio de reportes usando Supabase PostgreSQL directamente.
class ReporteRepository {
  SupabaseClient get _db => SupabaseService.client;

  String get _uid {
    final user = _db.auth.currentUser;
    if (user == null) {
      throw const AuthException('La sesión no está activa');
    }
    return user.id;
  }

  // ─── Zonas ───────────────────────────────────────────────────────────────────

  Future<List<Zona>> listarZonasActivas() async {
    final datos = await _db
        .from('zonas')
        .select('id, nombre, descripcion')
        .eq('activo', true)
        .order('nombre');

    return (datos as List)
        .whereType<Map<String, dynamic>>()
        .map(Zona.fromJson)
        .toList();
  }

  // ─── Crear ───────────────────────────────────────────────────────────────────

  /// Crea un nuevo reporte de residuos para el ciudadano autenticado.
  Future<ResultadoReporte> crear({
    required TipoIncidencia tipo,
    required String descripcion,
    required String zona,
    double? latitud,
    double? longitud,
    Uint8List? imagen,
    String? nombreImagen,
  }) async {
    try {
      String? imagenUrl;
      if (imagen != null) {
        final extension = _extensionImagen(nombreImagen);
        final ruta =
            '$_uid/${DateTime.now().microsecondsSinceEpoch}.$extension';
        await _db.storage
            .from('reportes')
            .uploadBinary(
              ruta,
              imagen,
              fileOptions: FileOptions(
                contentType: _tipoContenido(extension),
                upsert: false,
              ),
            );
        imagenUrl = _db.storage.from('reportes').getPublicUrl(ruta);
      }

      final Map<String, dynamic> datos = {
        'ciudadano_id': _uid,
        'tipo': tipo.name,
        'descripcion': descripcion.trim(),
        'zona': zona.trim(),
        'latitud': ?latitud,
        'longitud': ?longitud,
        'imagen_url': ?imagenUrl,
        'estado': 'pendiente',
      };

      final inserted = await _db
          .from('reportes')
          .insert(datos)
          .select()
          .single();

      final reporte = Reporte.fromSupabaseJson(inserted);
      return ResultadoReporte.exitoso(reporte);
    } on AuthException {
      return const ResultadoReporte.fallido(
        'Tu sesión expiró. Inicia sesión nuevamente.',
        codigoHttp: 401,
      );
    } on PostgrestException catch (e) {
      return ResultadoReporte.fallido(
        'Error al crear el reporte: ${e.message}',
      );
    } catch (_) {
      return const ResultadoReporte.fallido(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }

  }

  String _extensionImagen(String? nombre) {
    final extension = nombre?.split('.').last.toLowerCase();
    if (extension == 'png') return 'png';
    if (extension == 'webp') return 'webp';
    return 'jpg';
  }

  String _tipoContenido(String extension) {
    if (extension == 'png') return 'image/png';
    if (extension == 'webp') return 'image/webp';
    return 'image/jpeg';
  }

  // ─── Listar ──────────────────────────────────────────────────────────────────

  /// Obtiene los reportes del ciudadano autenticado, ordenados por fecha.
  Future<List<Reporte>> listar() async {
    final datos = await _db
        .from('reportes')
        .select()
        .eq('ciudadano_id', _uid)
        .order('creado_en', ascending: false);

    return (datos as List)
        .whereType<Map<String, dynamic>>()
        .map(Reporte.fromSupabaseJson)
        .toList();
  }

  /// Obtiene todos los reportes visibles para un administrador.
  Future<List<Reporte>> listarTodosParaAdministrador() async {
    final datos = await _db
        .from('reportes')
        .select()
        .order('creado_en', ascending: false);

    return (datos as List)
        .whereType<Map<String, dynamic>>()
        .map(Reporte.fromSupabaseJson)
        .toList();
  }

  /// Actualiza el estado de un reporte desde el panel administrativo.
  Future<Reporte> actualizarEstadoAdministrador({
    required int id,
    required EstadoReporte estado,
  }) async {
    final datos = await _db
        .from('reportes')
        .update({'estado': estado.name})
        .eq('id', id)
        .select()
        .single();

    return Reporte.fromSupabaseJson(datos);
  }

  // ─── Detalle ─────────────────────────────────────────────────────────────────

  /// Obtiene el detalle de un reporte por su [id].
  Future<Reporte> obtener(int id) async {
    final datos = await _db
        .from('reportes')
        .select()
        .eq('id', id)
        .eq('ciudadano_id', _uid)
        .single();

    return Reporte.fromSupabaseJson(datos);
  }

  Future<List<HorarioRecoleccion>> listarHorarios(int zonaId) async {
    final datos = await _db
        .from('horarios_recoleccion')
        .select()
        .eq('zona_id', zonaId)
        .eq('activo', true)
        .order('dia_semana')
        .order('hora_inicio');
    return (datos as List)
        .whereType<Map<String, dynamic>>()
        .map(HorarioRecoleccion.fromJson)
        .toList();
  }

  Future<List<Camion>> listarCamiones() async {
    final datos = await _db
        .from('camiones')
        .select(
          'id, placa, modelo, estado, latitud, longitud, '
          'ultima_ubicacion_en, zona_id',
        )
        .eq('activo', true)
        .order('placa');
    return (datos as List)
        .whereType<Map<String, dynamic>>()
        .map(Camion.fromJson)
        .toList();
  }

  Future<List<Recoleccion>> listarRecoleccionesPropias({
    required int zonaId,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final base = _db
        .from('recolecciones')
        .select()
        .eq('zona_id', zonaId);
    final datos = desde != null && hasta != null
        ? await base
              .gte('recolectado_en', desde.toIso8601String())
              .lte('recolectado_en', hasta.toIso8601String())
              .order('recolectado_en', ascending: false)
        : desde != null
        ? await base
              .gte('recolectado_en', desde.toIso8601String())
              .order('recolectado_en', ascending: false)
        : hasta != null
        ? await base
              .lte('recolectado_en', hasta.toIso8601String())
              .order('recolectado_en', ascending: false)
        : await base.order('recolectado_en', ascending: false);
    return (datos as List)
        .whereType<Map<String, dynamic>>()
        .map(Recoleccion.fromJson)
        .toList();
  }

  Future<List<Notificacion>> listarNotificaciones() async {
    final datos = await _db
        .from('notificaciones')
        .select()
        .order('creado_en', ascending: false);
    return (datos as List)
        .whereType<Map<String, dynamic>>()
        .map(Notificacion.fromJson)
        .toList();
  }

  Future<void> marcarNotificacionLeida(int id) async {
    await _db
        .from('notificaciones')
        .update({'leida': true, 'leida_en': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  Future<void> marcarTodasNotificacionesLeidas() async {
    await _db
        .from('notificaciones')
        .update({'leida': true, 'leida_en': DateTime.now().toIso8601String()})
        .eq('leida', false);
  }

  Future<ResumenEcologico?> obtenerResumenEcologico() async {
    final datos = await _db.rpc('obtener_resumen_ecologico');
    final filas = (datos as List).whereType<Map<String, dynamic>>().toList();
    return filas.isEmpty ? null : ResumenEcologico.fromJson(filas.first);
  }
}
