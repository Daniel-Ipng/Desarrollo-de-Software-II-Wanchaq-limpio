import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reporte.dart';
import '../models/zona.dart';
import '../services/cloudinary_service.dart';
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
  final CloudinaryService _cloudinary;

  ReporteRepository({CloudinaryService? cloudinary})
    : _cloudinary = cloudinary ?? CloudinaryService();

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
        try {
          imagenUrl = await _cloudinary.subir(
            bytes: imagen,
            nombre: 'reporte-${DateTime.now().microsecondsSinceEpoch}.$extension',
            carpeta: 'reportes/$_uid',
          );
        } on CloudinaryException catch (e) {
          return ResultadoReporte.fallido(
            'No se pudo subir la foto: ${e.mensaje}',
            codigoHttp: 502,
          );
        }
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
    } catch (e) {
      final mensaje = e is Exception ? e.toString() : 'Error inesperado';
      return ResultadoReporte.fallido(
        'No se pudo conectar con el servidor. Verifica tu conexión. Detalle: $mensaje',
      );
    }
  }

  String _extensionImagen(String? nombre) {
    final extension = nombre?.split('.').last.toLowerCase();
    if (extension == 'png') return 'png';
    if (extension == 'webp') return 'webp';
    return 'jpg';
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
}
