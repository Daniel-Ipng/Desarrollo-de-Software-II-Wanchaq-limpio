import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mi_app/repositories/usuario_repository.dart';
import 'package:mi_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('login restaura JWT y consulta perfil actual con cabecera Bearer', () async {
    SharedPreferences.setMockInitialValues({});
    String? loginAuthorization;
    String? profileAuthorization;
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/login') {
        loginAuthorization = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'token': 'jwt-local-test',
            'usuario': {
              'id': 5,
              'nombres': 'Admin',
              'apellidos': 'Wanchaq',
              'dni': '12345678',
              'correo': 'admin@example.test',
              'rol': 'admin',
            },
          }),
          200,
        );
      }
      if (request.url.path == '/api/auth/perfil') {
        profileAuthorization = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'id': 5,
            'nombres': 'Admin',
            'apellidos': 'Wanchaq',
            'dni': '12345678',
            'correo': 'admin@example.test',
            'telefono': null,
            'rol': 'admin',
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

    final resultado = await UsuarioRepository(ApiService(client: client))
        .iniciarSesion(
          correo: 'admin@example.test',
          contrasena: 'clave-de-prueba',
        );

    expect(resultado.exito, isTrue);
    expect(resultado.usuario?.esAdministrador, isTrue);
    expect(loginAuthorization, isNull);

    final apiRestaurada = ApiService(client: client);
    final repositorioRestaurado = UsuarioRepository(apiRestaurada);
    expect(await repositorioRestaurado.restaurarSesion(), isTrue);
    final perfil = await repositorioRestaurado.obtenerPerfil();

    expect(perfil.esAdministrador, isTrue);
    expect(profileAuthorization, 'Bearer jwt-local-test');
    await repositorioRestaurado.cerrarSesion();
  });
}
