import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mi_app/main.dart';
import 'package:mi_app/repositories/reporte_repository.dart';
import 'package:mi_app/repositories/usuario_repository.dart';
import 'package:mi_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> abrirConRol(WidgetTester tester, String rol) async {
    SharedPreferences.setMockInitialValues({'jwt_token': 'jwt-test-session'});
    String? authorizationAdmin;
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/perfil') {
        return http.Response(
          jsonEncode({
            'id': 4,
            'nombres': rol == 'admin' ? 'Admin' : 'Ana',
            'apellidos': 'Wanchaq',
            'dni': '12345678',
            'correo': 'persona@example.test',
            'telefono': null,
            'rol': rol,
          }),
          200,
        );
      }
      if (request.url.path == '/api/admin/dashboard') {
        authorizationAdmin = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'usuario': {'id': 4, 'correo': 'persona@example.test', 'rol': rol},
          }),
          200,
        );
      }
      if (request.url.path == '/api/reportes') {
        return http.Response('[]', 200);
      }
      return http.Response('{}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: PantallaRaiz(
          usuarioRepo: UsuarioRepository(ApiService(client: client)),
          reporteRepo: ReporteRepository(ApiService(client: client)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (rol == 'admin') {
      expect(find.text('Panel administrativo'), findsOneWidget);
      expect(authorizationAdmin, 'Bearer jwt-test-session');
    } else {
      expect(find.text('¡Hola, Ana!'), findsOneWidget);
      expect(find.text('Reportes'), findsOneWidget);
      expect(find.text('Panel administrativo'), findsNothing);
    }
  }

  testWidgets('rol admin del perfil dirige al panel administrativo', (
    tester,
  ) async {
    await abrirConRol(tester, 'admin');
  });

  testWidgets('rol ciudadano conserva la navegación existente', (tester) async {
    await abrirConRol(tester, 'ciudadano');
  });
}
