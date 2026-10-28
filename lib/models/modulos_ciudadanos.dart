class HorarioRecoleccion {
  final int id;
  final int zonaId;
  final int diaSemana;
  final String horaInicio;
  final String horaFin;
  final String tipoResiduo;

  const HorarioRecoleccion({
    required this.id,
    required this.zonaId,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    required this.tipoResiduo,
  });

  factory HorarioRecoleccion.fromJson(Map<String, dynamic> json) =>
      HorarioRecoleccion(
        id: (json['id'] as num).toInt(),
        zonaId: (json['zona_id'] as num).toInt(),
        diaSemana: (json['dia_semana'] as num).toInt(),
        horaInicio: (json['hora_inicio'] as String?) ?? '',
        horaFin: (json['hora_fin'] as String?) ?? '',
        tipoResiduo: (json['tipo_residuo'] as String?) ?? 'Mixto',
      );
}

class Camion {
  final int id;
  final String placa;
  final String? modelo;
  final String estado;
  final double? latitud;
  final double? longitud;
  final DateTime? ultimaUbicacion;
  final int? zonaId;

  const Camion({
    required this.id,
    required this.placa,
    this.modelo,
    required this.estado,
    this.latitud,
    this.longitud,
    this.ultimaUbicacion,
    this.zonaId,
  });

  factory Camion.fromJson(Map<String, dynamic> json) => Camion(
    id: (json['id'] as num).toInt(),
    placa: json['placa'] as String,
    modelo: json['modelo'] as String?,
    estado: (json['estado'] as String?) ?? 'operativo',
    latitud: (json['latitud'] as num?)?.toDouble(),
    longitud: (json['longitud'] as num?)?.toDouble(),
    ultimaUbicacion: _date(json['ultima_ubicacion_en']),
    zonaId: (json['zona_id'] as num?)?.toInt(),
  );
}

class Recoleccion {
  final int id;
  final int zonaId;
  final String tipoResiduo;
  final double? cantidadKg;
  final DateTime fecha;
  final String? observaciones;
  final String estado;

  const Recoleccion({
    required this.id,
    required this.zonaId,
    required this.tipoResiduo,
    this.cantidadKg,
    required this.fecha,
    this.observaciones,
    required this.estado,
  });

  factory Recoleccion.fromJson(Map<String, dynamic> json) => Recoleccion(
    id: (json['id'] as num).toInt(),
    zonaId: (json['zona_id'] as num).toInt(),
    tipoResiduo: json['tipo_residuo'] as String,
    cantidadKg: (json['cantidad_kg'] as num?)?.toDouble(),
    fecha: DateTime.parse(json['recolectado_en'] as String),
    observaciones: json['observaciones'] as String?,
    estado: (json['estado'] as String?) ?? 'registrada',
  );
}

class Notificacion {
  final int id;
  final String titulo;
  final String mensaje;
  final String tipo;
  final bool leida;
  final DateTime creadoEn;

  const Notificacion({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    required this.leida,
    required this.creadoEn,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) => Notificacion(
    id: (json['id'] as num).toInt(),
    titulo: json['titulo'] as String,
    mensaje: json['mensaje'] as String,
    tipo: (json['tipo'] as String?) ?? 'general',
    leida: json['leida'] as bool? ?? false,
    creadoEn: DateTime.parse(json['creado_en'] as String),
  );
}

class ResumenEcologico {
  final int puntos;
  final String nivel;
  final int puntosMinimos;
  final int? puntosMaximos;

  const ResumenEcologico({
    required this.puntos,
    required this.nivel,
    required this.puntosMinimos,
    this.puntosMaximos,
  });

  factory ResumenEcologico.fromJson(Map<String, dynamic> json) =>
      ResumenEcologico(
        puntos: (json['puntos'] as num?)?.toInt() ?? 0,
        nivel: (json['nivel'] as String?) ?? 'Eco Semilla',
        puntosMinimos: (json['puntos_minimos_nivel'] as num?)?.toInt() ?? 0,
        puntosMaximos: (json['puntos_maximos_nivel'] as num?)?.toInt(),
      );
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
