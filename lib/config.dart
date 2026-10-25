import 'package:latlong2/latlong.dart';

class Config {
  /// URL de la API. Por defecto usa el backend desplegado en Render (el mismo
  /// que usa el frontend web). Para probar con tu backend local:
  ///   flutter run --dart-define=API_BASE=http://192.168.1.50:4000/api
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://ecorutas-wanchaq-api.onrender.com/api',
  );

  /// Convierte "/uploads/foto.jpg" en una URL absoluta.
  static String archivo(String? ruta) {
    if (ruta == null || ruta.isEmpty) return '';
    if (ruta.startsWith('http')) return ruta;
    return apiBase.replaceFirst(RegExp(r'/api/?$'), '') + ruta;
  }

  static const LatLng centroWanchaq = LatLng(-13.5292, -71.9550);
  static const Duration refrescoGps = Duration(seconds: 10);
  static const Duration senalPerdida = Duration(minutes: 2);

  static const List<String> tiposIncidencia = [
    'Acumulación de residuos',
    'Contenedor dañado',
    'Vehículo obstruye ruta',
    'Residuos peligrosos mezclados',
    'Camión no pasó por la zona',
    'Otro',
  ];
}
