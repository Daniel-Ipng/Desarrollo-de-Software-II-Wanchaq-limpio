import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mi_app/services/api_service.dart';

void main() {
  test('envía el JWT real configurado como Bearer', () async {
    String? authorization;
    final api = ApiService(
      client: MockClient((request) async {
        authorization = request.headers['Authorization'];
        return http.Response('{}', 200);
      }),
    );
    api.setToken('token-de-prueba');

    await api.get('/auth/perfil');

    expect(authorization, 'Bearer token-de-prueba');
  });

  test('las solicitudes públicas no incluyen Authorization', () async {
    var authorizationPresente = false;
    final api = ApiService(
      client: MockClient((request) async {
        authorizationPresente = request.headers.containsKey('Authorization');
        return http.Response('{}', 200);
      }),
    );

    await api.post('/auth/login', {
      'correo': 'cuenta@example.test',
      'contrasena': 'valor-simulado',
    });

    expect(authorizationPresente, isFalse);
  });

  test('conserva HTTP 401 para que la sesión actual lo gestione', () async {
    final api = ApiService(
      client: MockClient(
        (_) async => http.Response('{"mensaje":"No autorizado"}', 401),
      ),
    );
    api.setToken('token-de-prueba');

    await expectLater(
      api.get('/auth/perfil'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.codigoHttp,
          'codigoHttp',
          401,
        ),
      ),
    );
  });
}
