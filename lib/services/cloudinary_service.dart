import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class CloudinaryException implements Exception {
  final String mensaje;

  const CloudinaryException(this.mensaje);

  @override
  String toString() => 'CloudinaryException: $mensaje';
}

/// Sube imágenes directamente a Cloudinary con un Upload Preset unsigned.
class CloudinaryService {
  static const _cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const _uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  final http.Client _client;

  CloudinaryService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> subir({
    required Uint8List bytes,
    required String nombre,
    required String carpeta,
  }) async {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      throw const CloudinaryException(
        'Falta configurar CLOUDINARY_CLOUD_NAME y CLOUDINARY_UPLOAD_PRESET.',
      );
    }

    final carpetaNormalizada = carpeta.replaceFirst(RegExp(r'^/+'), '');

    final solicitud = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      ),
    )
      ..fields.addAll({
        'upload_preset': _uploadPreset,
        'folder': carpetaNormalizada,
      })
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: nombre),
      );

    final respuesta = await _client
        .send(solicitud)
        .timeout(const Duration(seconds: 30));
    final cuerpo = await respuesta.stream.bytesToString();
    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
      throw const CloudinaryException('Cloudinary rechazó la imagen.');
    }

    final datos = jsonDecode(cuerpo);
    final url = datos is Map<String, dynamic> ? datos['secure_url'] : null;
    if (url is! String || url.isEmpty) {
      throw const CloudinaryException(
        'Cloudinary no devolvió la URL de la imagen.',
      );
    }
    return url;
  }
}
