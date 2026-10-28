import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/usuario.dart';
import '../models/zona.dart';
import '../services/supabase_service.dart';

/// Resultado de una operación de autenticación.
class ResultadoAuth {
  final bool exito;
  final String? error;
  final Usuario? usuario;

  const ResultadoAuth.exitoso(this.usuario) : exito = true, error = null;

  const ResultadoAuth.fallido(this.error) : exito = false, usuario = null;
}

/// Repositorio de autenticación y perfil usando Supabase Auth + tabla `perfiles`.
///
/// Al registrar, se crea el usuario en Supabase Auth y se inserta un perfil
/// complementario en la tabla `perfiles`. Al iniciar sesión, se lee ese perfil.
class UsuarioRepository {
  SupabaseClient get _db => SupabaseService.client;

  // ─── Registro ───────────────────────────────────────────────────────────────

  /// Registra un nuevo ciudadano con Supabase Auth y crea su perfil.
  Future<ResultadoAuth> registrar({
    required String nombres,
    required String apellidos,
    required String dni,
    required String correo,
    String? telefono,
    required String contrasena,
    required int zonaId,
    required String direccion,
    double? latitudDomicilio,
    double? longitudDomicilio,
  }) async {
    try {
      // 1. Crear cuenta en Supabase Auth
      final authResponse = await _db.auth.signUp(
        email: correo.trim(),
        password: contrasena,
        data: {'nombres': nombres.trim(), 'apellidos': apellidos.trim()},
      );

      final authUser = authResponse.user;
      if (authUser == null) {
        return const ResultadoAuth.fallido(
          'No se pudo crear la cuenta. Intenta nuevamente.',
        );
      }

      // 2. Insertar perfil complementario en tabla `perfiles`
      final Map<String, dynamic> perfilData = {
        'id': authUser.id,
        'nombres': nombres.trim(),
        'apellidos': apellidos.trim(),
        'dni': dni.trim(),
        'correo': correo.trim(),
        'zona_id': zonaId,
        'direccion': direccion.trim(),
        'rol': 'ciudadano',
        if (telefono != null && telefono.trim().isNotEmpty)
          'telefono': telefono.trim(),
        'latitud_domicilio': latitudDomicilio,
        'longitud_domicilio': longitudDomicilio,
      };

      await _db.from('perfiles').insert(perfilData);

      // 3. Leer perfil completo (incluye zona_nombre via join)
      final usuario = await _obtenerPerfilPorId(authUser.id);
      if (usuario == null) {
        return const ResultadoAuth.fallido(
          'Cuenta creada, pero no se pudo cargar el perfil.',
        );
      }

      return ResultadoAuth.exitoso(usuario);
    } on AuthException catch (e) {
      return ResultadoAuth.fallido(_traducirErrorAuth(e.message));
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return const ResultadoAuth.fallido(
          'Ya existe una cuenta con ese DNI o correo.',
        );
      }
      return ResultadoAuth.fallido('Error al guardar el perfil: ${e.message}');
    } catch (_) {
      return const ResultadoAuth.fallido(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }
  }

  // ─── Inicio de sesión ────────────────────────────────────────────────────────

  /// Inicia sesión con correo y contraseña usando Supabase Auth.
  Future<ResultadoAuth> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    try {
      final authResponse = await _db.auth.signInWithPassword(
        email: correo.trim(),
        password: contrasena,
      );

      final authUser = authResponse.user;
      if (authUser == null) {
        return const ResultadoAuth.fallido('Correo o contraseña incorrectos.');
      }

      final usuario = await _obtenerPerfilPorId(authUser.id);
      if (usuario == null) {
        return const ResultadoAuth.fallido(
          'No se pudo cargar el perfil del usuario.',
        );
      }

      return ResultadoAuth.exitoso(usuario);
    } on AuthException catch (e) {
      return ResultadoAuth.fallido(_traducirErrorAuth(e.message));
    } catch (_) {
      return const ResultadoAuth.fallido(
        'No se pudo conectar con el servidor. Verifica tu conexión.',
      );
    }
  }

  // ─── Recuperación de contraseña ─────────────────────────────────────────────

  /// Envía un enlace para restablecer la contraseña del usuario.
  Future<ResultadoAuth> recuperarContrasena(String correo) async {
    final correoLimpio = correo.trim();
    if (correoLimpio.isEmpty) {
      return const ResultadoAuth.fallido(
        'Ingresa un correo electrónico válido.',
      );
    }

    try {
      await _db.auth.resetPasswordForEmail(correoLimpio);
      return const ResultadoAuth.exitoso(null);
    } on AuthException catch (e) {
      return ResultadoAuth.fallido(_traducirErrorAuth(e.message));
    } catch (_) {
      return const ResultadoAuth.fallido(
        'No se pudo enviar el enlace de recuperación. Intenta nuevamente.',
      );
    }
  }

  // ─── Perfil ──────────────────────────────────────────────────────────────────

  /// Obtiene el perfil del usuario actualmente autenticado.
  Future<Usuario> obtenerPerfil() async {
    final authUser = _db.auth.currentUser;
    if (authUser == null) {
      throw const AuthException('La sesión no está activa');
    }
    final usuario = await _obtenerPerfilPorId(authUser.id);
    if (usuario == null) {
      throw const AuthException('Perfil no encontrado');
    }
    return usuario;
  }

  /// Lista todas las zonas activas disponibles.
  Future<List<Zona>> listarZonasActivas() async {
    try {
      final datos = await _db
          .from('zonas')
          .select('id, nombre, descripcion')
          .eq('activo', true)
          .order('nombre');

      return (datos as List)
          .whereType<Map<String, dynamic>>()
          .map(Zona.fromJson)
          .toList();
    } on PostgrestException catch (error) {
      throw StateError(
        'Supabase no pudo cargar las zonas (${error.code}): ${error.message}',
      );
    }
  }

  /// Actualiza el perfil del usuario autenticado.
  Future<Usuario> actualizarPerfil({
    required String nombres,
    required String apellidos,
    String? telefono,
    required int zonaId,
    required String direccion,
    double? latitudDomicilio,
    double? longitudDomicilio,
  }) async {
    final authUser = _db.auth.currentUser;
    if (authUser == null) throw const AuthException('La sesión no está activa');

    final Map<String, dynamic> datos = {
      'nombres': nombres.trim(),
      'apellidos': apellidos.trim(),
      'telefono': telefono?.trim().isNotEmpty == true ? telefono!.trim() : null,
      'zona_id': zonaId,
      'direccion': direccion.trim(),
      'latitud_domicilio': latitudDomicilio,
      'longitud_domicilio': longitudDomicilio,
    };

    await _db.from('perfiles').update(datos).eq('id', authUser.id);
    final usuario = await _obtenerPerfilPorId(authUser.id);
    if (usuario == null) {
      throw const PostgrestException(
        message: 'Perfil no encontrado tras actualización',
      );
    }
    return usuario;
  }

  /// Comprueba que el usuario autenticado tiene rol administrador.
  Future<void> verificarAccesoAdministrador() async {
    final usuario = await obtenerPerfil();
    if (!usuario.esAdministrador) {
      throw const AuthException(
        'No tienes permisos para acceder al panel administrativo',
      );
    }
  }

  /// Verifica la contraseña actual y establece una nueva mediante Supabase Auth.
  Future<void> cambiarContrasena({
    required String actual,
    required String nueva,
  }) async {
    final usuario = _db.auth.currentUser;
    if (usuario?.email == null) {
      throw const AuthException('La sesión no está activa');
    }

    await _db.auth.signInWithPassword(
      email: usuario!.email!,
      password: actual,
    );
    await _db.auth.updateUser(UserAttributes(password: nueva));
  }

  // ─── Sesión ──────────────────────────────────────────────────────────────────

  /// Verifica si hay una sesión persistente activa (manejada automáticamente por Supabase).
  Future<bool> restaurarSesion() async {
    // Supabase persiste la sesión automáticamente en SharedPreferences internamente.
    // Solo necesitamos verificar si hay un usuario activo.
    final session = _db.auth.currentSession;
    if (session == null) {
      return false;
    }

    // Si el token expiró, Supabase lo refresca automáticamente.
    if (session.isExpired) {
      try {
        await _db.auth.refreshSession();
        return _db.auth.currentUser != null;
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  /// Cierra la sesión del usuario.
  Future<void> cerrarSesion() async {
    await _db.auth.signOut();
  }

  // ─── Privado ─────────────────────────────────────────────────────────────────

  Future<Usuario?> _obtenerPerfilPorId(String uid) async {
    try {
      final datos = await _db
          .from('perfiles')
          .select('*, zonas(nombre)')
          .eq('id', uid)
          .single();

      return Usuario.fromSupabaseJson(datos);
    } catch (_) {
      return null;
    }
  }

  /// Traduce mensajes de error de Supabase Auth al español.
  String _traducirErrorAuth(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return 'Ya existe una cuenta con ese correo.';
    }
    if (msg.contains('password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (msg.contains('unable to validate email')) {
      return 'El correo electrónico no es válido.';
    }
    if (msg.contains('email address') && msg.contains('invalid')) {
      return 'El correo electrónico no es válido. Usa un correo real, por ejemplo nombre@gmail.com.';
    }
    if (msg.contains('email provider') ||
        msg.contains('sending email') ||
        msg.contains('smtp')) {
      return 'Supabase no pudo enviar el correo de confirmación. Revisa la configuración de Email en Authentication > Providers.';
    }
    if (msg.contains('email rate limit') ||
        msg.contains('rate limit exceeded') ||
        msg.contains('over_email_send_rate_limit')) {
      return 'Supabase alcanzó el límite de correos de registro. Espera unos minutos antes de reintentar o configura un SMTP propio en Authentication > SMTP Settings.';
    }
    if (msg.contains('email signups are disabled') ||
        msg.contains('signups are disabled') ||
        msg.contains('signup is disabled')) {
      return 'El registro por correo está desactivado en Supabase. Activa Email en Authentication > Providers y permite nuevos usuarios en Authentication > Settings.';
    }
    if (msg.contains('password') && msg.contains('weak')) {
      return 'La contraseña es demasiado débil. Usa al menos 6 caracteres.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Debes confirmar tu correo antes de iniciar sesión.';
    }
    return 'No se pudo crear la cuenta: $message';
  }
}
