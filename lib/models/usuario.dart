/// Modelo que representa a un ciudadano registrado en EcoRutas Wanchaq.
class Usuario {
  final String id; // UUID de Supabase Auth
  final String nombres;
  final String apellidos;
  final String dni;
  final String correo;
  final String? telefono;
  final String rol;
  final int? zonaId;
  final String? zonaNombre;
  final String? direccion;
  final double? latitudDomicilio;
  final double? longitudDomicilio;

  const Usuario({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.dni,
    required this.correo,
    this.telefono,
    this.rol = 'ciudadano',
    this.zonaId,
    this.zonaNombre,
    this.direccion,
    this.latitudDomicilio,
    this.longitudDomicilio,
  });

  /// Nombre completo del ciudadano.
  String get nombreCompleto =>
      [nombres, apellidos].where((parte) => parte.trim().isNotEmpty).join(' ');

  bool get esAdministrador => rol == 'admin' || rol == 'administrador';

  /// Crea un [Usuario] a partir del JSON devuelto por Supabase
  /// (tabla `perfiles` con join a `zonas`).
  factory Usuario.fromSupabaseJson(Map<String, dynamic> json) {
    final rolRecibido = json['rol'];
    final rolNormalizado = rolRecibido is String
        ? rolRecibido.trim().toLowerCase()
        : 'ciudadano';

    // El join zonas(nombre) devuelve {'zonas': {'nombre': '...'}}
    final zonaMap = json['zonas'];
    final zonaNombre = zonaMap is Map<String, dynamic>
        ? zonaMap['nombre'] as String?
        : null;

    return Usuario(
      id: json['id'] as String,
      nombres: json['nombres'] as String? ?? '',
      apellidos: json['apellidos'] as String? ?? '',
      dni: json['dni'] as String? ?? '',
      correo: json['correo'] as String? ?? '',
      telefono: json['telefono'] as String?,
      zonaId: (json['zona_id'] as num?)?.toInt(),
      zonaNombre: zonaNombre,
      direccion: json['direccion'] as String?,
      latitudDomicilio: (json['latitud_domicilio'] as num?)?.toDouble(),
      longitudDomicilio: (json['longitud_domicilio'] as num?)?.toDouble(),
      rol: rolNormalizado == 'admin' || rolNormalizado == 'administrador'
          ? rolNormalizado
          : 'ciudadano',
    );
  }

  /// Mantiene compatibilidad con código que use fromJson (legacy).
  factory Usuario.fromJson(Map<String, dynamic> json) =>
      Usuario.fromSupabaseJson(json);

  /// Serializa el usuario a un mapa JSON (útil para pruebas).
  Map<String, dynamic> toJson() => {
    'id': id,
    'nombres': nombres,
    'apellidos': apellidos,
    'dni': dni,
    'correo': correo,
    'rol': rol,
    if (telefono != null) 'telefono': telefono,
    if (zonaId != null) 'zona_id': zonaId,
    if (zonaNombre != null) 'zona_nombre': zonaNombre,
    if (direccion != null) 'direccion': direccion,
    'latitud_domicilio': latitudDomicilio,
    'longitud_domicilio': longitudDomicilio,
  };
}
