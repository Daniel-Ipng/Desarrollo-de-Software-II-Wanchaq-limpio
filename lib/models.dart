import 'package:latlong2/latlong.dart';

double? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class Usuario {
  final int id;
  final String rol, nombres, apellidos, correo;
  final String? dni, telefono, zona, direccion, nivelEcologico;
  final double kgReciclados;

  const Usuario({
    required this.id,
    required this.rol,
    required this.nombres,
    required this.apellidos,
    required this.correo,
    this.dni,
    this.telefono,
    this.zona,
    this.direccion,
    this.nivelEcologico,
    this.kgReciclados = 0,
  });

  String get nombreCompleto => '$nombres $apellidos';

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: (j['id'] as num).toInt(),
        rol: j['rol'] as String,
        nombres: (j['nombres'] ?? '') as String,
        apellidos: (j['apellidos'] ?? '') as String,
        correo: (j['correo'] ?? '') as String,
        dni: j['dni'] as String?,
        telefono: j['telefono'] as String?,
        zona: j['zona'] as String?,
        direccion: j['direccion'] as String?,
        nivelEcologico: j['nivelEcologico'] as String?,
        kgReciclados: _num(j['kgReciclados']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'rol': rol,
        'nombres': nombres,
        'apellidos': apellidos,
        'correo': correo,
        'dni': dni,
        'telefono': telefono,
        'zona': zona,
        'direccion': direccion,
        'nivelEcologico': nivelEcologico,
        'kgReciclados': kgReciclados,
      };
}

class Zona {
  final int id;
  final String nombre, estado;
  final String? referencia, horarioRecoleccion, tipoResiduoPrincipal;
  final List<LatLng> poligono;

  const Zona({
    required this.id,
    required this.nombre,
    required this.estado,
    this.referencia,
    this.horarioRecoleccion,
    this.tipoResiduoPrincipal,
    this.poligono = const [],
  });

  factory Zona.fromJson(Map<String, dynamic> j) {
    final puntos = <LatLng>[];
    for (final p in (j['poligono'] as List? ?? const [])) {
      if (p is Map) {
        final lat = _num(p['lat']);
        final lng = _num(p['lng']);
        if (lat != null && lng != null) puntos.add(LatLng(lat, lng));
      }
    }
    return Zona(
      id: (j['id'] as num).toInt(),
      nombre: (j['nombre'] ?? '') as String,
      estado: (j['estado'] ?? 'activa') as String,
      referencia: j['referencia'] as String?,
      horarioRecoleccion: j['horarioRecoleccion'] as String?,
      tipoResiduoPrincipal: j['tipoResiduoPrincipal'] as String?,
      poligono: puntos,
    );
  }
}

class TipoResiduo {
  final int id;
  final String nombre;
  final String? descripcion, color, contenedor;
  final List<String> diasRecomendados;

  const TipoResiduo({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.color,
    this.contenedor,
    this.diasRecomendados = const [],
  });

  factory TipoResiduo.fromJson(Map<String, dynamic> j) => TipoResiduo(
        id: (j['id'] as num).toInt(),
        nombre: (j['nombre'] ?? '') as String,
        descripcion: j['descripcion'] as String?,
        color: j['color'] as String?,
        contenedor: j['contenedor'] as String?,
        diasRecomendados:
            ((j['diasRecomendados'] as List?) ?? const []).map((e) => '$e').toList(),
      );
}

/// Última posición conocida de un camión con ruta en progreso (GET /gps/activos).
class CamionGps {
  final int? camionId, rutaId, zonaId;
  final double lat, lng;
  final double? velocidad;
  final DateTime? fecha;
  final String? placa, zonaNombre;

  const CamionGps({
    this.camionId,
    this.rutaId,
    this.zonaId,
    required this.lat,
    required this.lng,
    this.velocidad,
    this.fecha,
    this.placa,
    this.zonaNombre,
  });

  LatLng get punto => LatLng(lat, lng);

  bool get senalPerdida =>
      fecha == null || DateTime.now().difference(fecha!) > const Duration(minutes: 2);

  factory CamionGps.fromJson(Map<String, dynamic> j) => CamionGps(
        camionId: (j['camionId'] as num?)?.toInt(),
        rutaId: (j['rutaId'] as num?)?.toInt(),
        zonaId: (j['zonaId'] as num?)?.toInt(),
        lat: _num(j['lat']) ?? 0,
        lng: _num(j['lng']) ?? 0,
        velocidad: _num(j['velocidad']),
        fecha: DateTime.tryParse('${j['fecha']}')?.toLocal(),
        placa: j['placa'] as String?,
        zonaNombre: j['zonaNombre'] as String?,
      );
}

class Incidencia {
  final int id;
  final String tipo, descripcion, direccion, estado, prioridad;
  final String? zona, fotoUrl;
  final DateTime? fecha;

  const Incidencia({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.direccion,
    required this.estado,
    required this.prioridad,
    this.zona,
    this.fotoUrl,
    this.fecha,
  });

  factory Incidencia.fromJson(Map<String, dynamic> j) => Incidencia(
        id: (j['id'] as num).toInt(),
        tipo: (j['tipo'] ?? '') as String,
        descripcion: (j['descripcion'] ?? '') as String,
        direccion: (j['direccion'] ?? '') as String,
        estado: (j['estado'] ?? 'pendiente') as String,
        prioridad: (j['prioridad'] ?? 'media') as String,
        zona: j['zona'] as String?,
        fotoUrl: j['fotoUrl'] as String?,
        fecha: DateTime.tryParse('${j['fecha']}')?.toLocal(),
      );
}
