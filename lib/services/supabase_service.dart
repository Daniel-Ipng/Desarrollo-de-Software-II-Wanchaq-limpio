import 'package:supabase_flutter/supabase_flutter.dart';

/// Punto de acceso central al cliente de Supabase.
///
/// Usar [SupabaseService.client] para acceder a Auth, DB y Storage.
class SupabaseService {
  SupabaseService._();

  /// Retorna el cliente Supabase ya inicializado por [Supabase.initialize].
  static SupabaseClient get client => Supabase.instance.client;
}
