/// Tipos de incidencia disponibles para un reporte.
enum TipoIncidencia {
  residuosAcumulados('Residuos acumulados'),
  contenedorLleno('Contenedor lleno'),
  faltaRecoleccion('Falta de recolección'),
  puntoIlegal('Punto de disposición ilegal'),
  otro('Otro');

  final String etiqueta;
  const TipoIncidencia(this.etiqueta);
}

/// Estados posibles de un reporte de residuos.
enum EstadoReporte {
  pendiente('Pendiente'),
  enProceso('En proceso'),
  resuelto('Resuelto');

  final String etiqueta;
  const EstadoReporte(this.etiqueta);

  /// Crea un [EstadoReporte] a partir del valor de texto devuelto por la API.
  static EstadoReporte fromString(String valor) {
    return EstadoReporte.values.firstWhere(
      (e) => e.name == valor || e.etiqueta == valor,
      orElse: () => EstadoReporte.pendiente,
    );
  }
}

/// Modelo que representa un reporte de residuos sólidos.
class Reporte {
  final int id;
  final String ciudadanoId; // UUID de Supabase Auth
  final TipoIncidencia tipo;
  final String descripcion;
  final String zona;
  final double? latitud;
  final double? longitud;
  final String? imagenUrl;
  final EstadoReporte estado;
  final DateTime creadoEn;

  const Reporte({
    required this.id,
    required this.ciudadanoId,
    required this.tipo,
    required this.descripcion,
    required this.zona,
    this.latitud,
    this.longitud,
    this.imagenUrl,
    required this.estado,
    required this.creadoEn,
  });

  /// Crea un [Reporte] a partir del JSON devuelto por Supabase.
  factory Reporte.fromSupabaseJson(Map<String, dynamic> json) {
    return Reporte(
      id: (json['id'] as num).toInt(),
      ciudadanoId: json['ciudadano_id'] as String,
      tipo: TipoIncidencia.values.firstWhere(
        (t) => t.name == json['tipo'],
        orElse: () => TipoIncidencia.otro,
      ),
      descripcion: json['descripcion'] as String,
      zona: json['zona'] as String,
      latitud: (json['latitud'] as num?)?.toDouble(),
      longitud: (json['longitud'] as num?)?.toDouble(),
      imagenUrl: json['imagen_url'] as String?,
      estado: EstadoReporte.fromString(json['estado'] as String? ?? 'pendiente'),
      creadoEn: DateTime.parse(json['creado_en'] as String),
    );
  }

  /// Mantiene compatibilidad con código que use fromJson (legacy).
  factory Reporte.fromJson(Map<String, dynamic> json) =>
      Reporte.fromSupabaseJson(json);

  /// Serializa el reporte a un mapa JSON.
  Map<String, dynamic> toJson() => {
    'id': id,
    'ciudadano_id': ciudadanoId,
    'tipo': tipo.name,
    'descripcion': descripcion,
    'zona': zona,
    'latitud': latitud,
    'longitud': longitud,
    'imagen_url': imagenUrl,
    'estado': estado.name,
    'creado_en': creadoEn.toIso8601String(),
  };
}
