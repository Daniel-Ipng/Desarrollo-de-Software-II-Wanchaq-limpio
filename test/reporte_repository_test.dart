import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mi_app/models/reporte.dart';
import 'package:mi_app/repositories/reporte_repository.dart';
import 'package:mi_app/services/api_service.dart';

void main() {
  test('envía y recupera coordenadas GPS en el contrato de reportes', () async {
    Map<String, dynamic>? cuerpo;
    final api = ApiService(
      client: MockClient((request) async {
        cuerpo = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
            'id': 10,
            'ciudadano_id': 4,
            'tipo': 'otro',
            'descripcion': 'Residuo en la vía pública.',
            'zona': 'Wanchaq',
            'latitud': -13.53195,
            'longitud': -71.96746,
            'estado': 'pendiente',
            'creado_en': '2026-10-25T18:00:00.000Z',
            }),
          ),
          201,
        );
      }),
    );

    final resultado = await ReporteRepository(api).crear(
      tipo: TipoIncidencia.otro,
      descripcion: 'Residuo en la vía pública.',
      zona: 'Wanchaq',
      latitud: -13.53195,
      longitud: -71.96746,
    );

    expect(resultado.exito, isTrue, reason: resultado.error);
    expect(cuerpo?['latitud'], -13.53195);
    expect(cuerpo?['longitud'], -71.96746);
    expect(resultado.reporte?.latitud, -13.53195);
    expect(resultado.reporte?.longitud, -71.96746);
  });
}
